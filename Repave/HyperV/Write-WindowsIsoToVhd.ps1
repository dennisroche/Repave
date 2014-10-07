function Write-WindowsIsoToVhd {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [ValidatePattern("\.iso$")]
        [string]$Iso,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({ Test-Path $_ })]
        [ValidatePattern("\.vhd(x)?$")]
        [string]$VhdPath
    )

    $vhdFinalName = ""

    try {
        # Mount ISO and select the install.wim file
        $openIso = Mount-DiskImage -ImagePath (Resolve-Path $Iso) -StorageType ISO -PassThru | Get-Volume
        $wimPath = "$($openIso.DriveLetter):\sources\install.wim"
        if (!(Test-Path $wimPath)) {
            Throw "The specified ISO does not appear to be valid Windows installation media."
        }

        Write-Verbose "Mounted Microsoft Windows ISO at $($openIso.DriveLetter):\"

        # Mount VHD to apply Windows image
        Mount-DiskImage -ImagePath (Resolve-Path $VhdPath) -Access ReadWrite | Out-Null
        $drive = Get-VhdDriveLetter (Resolve-Path $VhdPath)
        if ($drive -eq '') {
            Throw "Cannot find mount point $VhdPath"
        }

        Write-WimImageToDrive $wimPath $drive

        # Configure Windows to allow Remote Powershell, required for Repave
        Using-VHDRegistry "SOFTWARE" $drive { 
            $path = "VHD:\Microsoft\Windows\CurrentVersion\Policies\system"
            Set-ItemProperty $path -Name LocalAccountTokenFilterPolicy -Value 0
        }

        Using-VHDRegistry "SYSTEM" $drive { 
            $current = Get-(Get-ItemProperty "VHD:\Select" -Name Current).Current
            $path = "VHD:\ControlSet00$current\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
        }
        
        # Get details of installed version
        $imageDetails = Get-WindowsImageDetails $drive
        Write-Verbose "Installed Image Details $($imageDetails | Format-Table | Out-String)"
        $vhdFinalName = "$(Get-Date -f MM-dd-yyyy_HH_mm_ss)_$($imageDetails.BuildLabEx)_$($imageDetails.SkuFamily)_$($imageDetails.EditionId).vhdx"

    } finally {
        Dismount-DiskImage -ImagePath (Resolve-Path $Iso) -ErrorAction SilentlyContinue | Out-Null
        Dismount-DiskImage -ImagePath (Resolve-Path $VhdPath) -ErrorAction SilentlyContinue | Out-Null
    }

    # Rename VHD with details of installed version
    if ($vhdFinalName -ne '') {
        Write-Verbose "Renaming VHD to '$vhdFinalName'"
        $VhdPath = Rename-Item -Path (Resolve-Path $VhdPath).Path -NewName $vhdFinalName -Force
    }

    return $VhdPath
}

function Write-WimImageToDrive {
    
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [ValidatePattern("\.wim$")]
        [string]$WimPath,

        [Parameter(Position=1, Mandatory)]
        [ValidateScript({Test-Path "$_\"})]
        [ValidatePattern("^[A-Z]?:$")]
        [string]$Drive

    )

    $wimMessageCallback = [Microsoft.Wim.WimMessageCallback]{
        param (
            [Microsoft.Wim.WimMessageType]$messageType,
            [PSObject]$message,
            [PSObject]$userData
        )

        $imageName = $userData

        if ($messageType -eq [Microsoft.Wim.WimMessageType]::Progress) {
            $progressMessage = ($message -as [Microsoft.Wim.WimMessageProgress])
            Write-Progress -Activity "Applying Windows Image - $wimImageName" -Status "Writing" -PercentComplete $progressMessage.PercentComplete
        }
        elseif ($messageType -eq [Microsoft.Wim.WimMessageType]::FileInfo) {
            $fileInfoMessage = ($message -as [Microsoft.Wim.WimMessageFileInfo])
            Write-Verbose "[$imageName] $($fileInfoMessage.Path)"
        }
        elseif ($messageType -eq [Microsoft.Wim.WimMessageType]::Warning) {
            $warningMessage = ($message -as [Microsoft.Wim.WimMessageWarning])
            Write-Warning "[$imageName] $($warningMessage.Path) - $($warningMessage.Win32ErrorCode)"
        }
        elseif ($messageType -eq [Microsoft.Wim.WimMessageType]::Error) {
            $errorMessage = ($message -as [Microsoft.Wim.WimMessageError])
            Write-Warning "[$imageName] $($errorMessage.Path) - $($errorMessage.Win32ErrorCode)"
        }

        return [Microsoft.Wim.WimMessageResult]::Success
    }

    $wimFileHandle = $null
    $wimImageHandle = $null
    $wimCallbackId = -1

    try {
        # Get a native handle on *.wim container
        $wimFileHandle = [Microsoft.Wim.WimgApi]::CreateFile($WimPath, [Microsoft.Wim.WimFileAccess]::Read, 
            [Microsoft.Wim.WimCreationDisposition]::OpenExisting, [Microsoft.Wim.WimCreateFileOptions]::None, 
            [Microsoft.Wim.WimCompressionType]::None)

        # Always set a temporary path
        [Microsoft.Wim.WimgApi]::SetTemporaryPath($wimFileHandle, $env:temp)

        $wimImageHandle = [Microsoft.Wim.WimgApi]::LoadImage($wimFileHandle, 1)
        [xml]$wimInformation = ([Microsoft.Wim.WimgApi]::GetImageInformation($wimFileHandle).CreateNavigator().InnerXml)
        $wimImageName = $wimInformation.WIM.IMAGE.NAME

        Write-Verbose "Applying Windows Image '$wimImageName'"
        Write-Progress -Activity "Applying Windows Image - $wimImageName" -Status "Starting" -PercentComplete 0

        # Register callback to get progress information as applying an image can take several minutes
        $wimCallbackId = [Microsoft.Wim.WimgApi]::RegisterMessageCallback($wimFileHandle, $wimMessageCallback, $wimImageName)
        [Microsoft.Wim.WimgApi]::ApplyImage($wimImageHandle, $Drive, [Microsoft.Wim.WimApplyImageOptions]::Verify)

        Write-Progress -Completed -Activity "Applying Windows Image - $wimImageName" -Status "Completed" 
        Write-Verbose "Finished applying Windows Image '$wimImageName'"

    } catch {
        Throw "Failed to apply WIM Image. $($_.Exception)"
    } finally {
        if ($wimCallbackId -ge 0) {
           [Microsoft.Wim.WimgApi]::UnregisterMessageCallback($wimFileHandle, $wimMessageCallback)
        }

        if ($wimImageHandle -ne $null) {
            $wimImageHandle.Close()
            $wimImageHandle = $null
        }

        if ($wimFileHandle -ne $null) {
            $wimFileHandle.Close()
            $wimFileHandle = $null
        }
    }

}

function Get-WindowsImageDetails {
    [CmdletBinding()]
    param (
        [Parameter(Position=1, Mandatory)]
        [ValidateScript({Test-Path "$_\"})]
        [ValidatePattern("^[A-Z]?:$")]
        [string]$Drive
    )

    Using-VHDRegistry "SOFTWARE" $Drive {
        $currentVersion = Get-ItemProperty "VHD:\Microsoft\Windows NT\CurrentVersion"

        $buildLabEx = $currentVersion.BuildLabEx
        $installType = $currentVersion.InstallationType
        $editionId = $currentVersion.EditionID

        # Is this ServerCore?
        if ($installType -ilike "CORE") {
            $editionId += "Core"
        }

        # What type of SKU are we?
        $skuFamily = "Unknown"
        if ($installType -ilike "SERVER") {
            $skuFamily = "Server"
        }
        elseif ($installType -ilike "CLIENT") {
            $skuFamily = "Client"
        }

        $result = @{
            CurrentVersion = $currentVersion
            BuildLabEx = $buildLabEx
            InstallType = $installType
            EditionId = $editionId
            SkuFamily = $skuFamily
        }

        return $result
    }

}