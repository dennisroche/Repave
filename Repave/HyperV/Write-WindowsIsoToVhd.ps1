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

        # Rename VHD with details of installed version
        $vhdFinalName = ""
        Using-VHDRegistry "SOFTWARE", $drive {
            $currentVersion = Get-ItemProperty "VHD:\Microsoft\Windows NT\CurrentVersion"

            $buildLabEx = $currentVersion.BuildLabEx
            $installType = $currentVersion.InstallationType
            $editionId = $currentVersion.EditionID

            # Is this ServerCore?
            if ($installType -ilike "CORE") {
                $editionId += "Core"
            }

            # What type of SKU are we?
            if ($installType -ilike "SERVER") {
                $skuFamily = "Server"
            } elseif ($installType -ilike "CLIENT") {
                $skuFamily = "Client"
            } else {
                $skuFamily = "Unknown"
            }
        }

        $vhdFinalName = " $(Get-Date -f MM-dd-yyyy_HH_mm_ss)_$($buildLabEx)_$($skuFamily)_$($editionId)_$($openImage.ImageDefaultLanguage)"
        $VhdPath = Rename-Item -Path (Resolve-Path $VhdPath).Path -NewName $vhdFinalName -Force

        # Configure Windows to allow Remote Powershell
        Using-VHDRegistry "SOFTWARE" $volume { 
            $path = "VHD:\Microsoft\Windows\CurrentVersion\Policies\system"
            Set-ItemProperty $path -Name LocalAccountTokenFilterPolicy -Value 0
        }

        Using-VHDRegistry "SYSTEM" $volume { 
            $current = Get-(Get-ItemProperty "VHD:\Select" -Name Current).Current
            $path = "VHD:\ControlSet00$current\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
        }

        return $VhdPath

    } finally {
        Dismount-DiskImage -ImagePath (Resolve-Path $Iso) -ErrorAction SilentlyContinue | Out-Null
        Dismount-DiskImage -ImagePath (Resolve-Path $VhdPath) -ErrorAction SilentlyContinue | Out-Null
    }
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

    $ProgressPreference = 'Continue'

    $wimMessageCallback = {
        param (
            [Microsoft.Wim.WimMessageType]$messageType,
            [PSObject]$message,
            [PSObject]$userData
        )

        $imageName = $userData

        if ($messageType -eq 'Process') {
            Write-Verbose "[$imageName] Writing file '$($message.Path)'"
        } elif ($messageType -eq 'Progress') {
            Write-Progress -Activity "Applying $imageName" -PercentComplete $message.PercentComplete -SecondsRemaining $message.EstimatedTimeRemaining
        } elif ($messageType -eq 'Warning') {
            Write-Warning "[$imageName] $($message.Path) - $($message.Win32ErrorCode)"
        } elif ($messageType -eq 'Error') {
            Write-Error "[$imageName] $($message.Path) - $($message.Win32ErrorCode)"
        }

        return [Microsoft.Wim.WimMessageResult]::Success
    }

    $wimFileHandle = $null
    $wimImageHandle = $null
    $wimCallbackId = -1

    try {
        # Get a native handle on *.wim container
        Write-Verbose "[Microsoft.Wim] Loading '$WimPath'"
        $wimFileHandle = [Microsoft.Wim.WimgApi]::CreateFile($WimPath, [Microsoft.Wim.WimFileAccess]::Read, 
            [Microsoft.Wim.WimCreationDisposition]::OpenExisting, [Microsoft.Wim.WimCreateFileOptions]::None, 
            [Microsoft.Wim.WimCompressionType]::None)

        # Always set a temporary path
        [Microsoft.Wim.WimgApi]::SetTemporaryPath($wimFileHandle, $env:temp)

        $wimImageHandle = [Microsoft.Wim.WimgApi]::LoadImage($wimFileHandle, 1)
        [xml]$wimInformation = ([Microsoft.Wim.WimgApi]::GetImageInformation($wimFileHandle).CreateNavigator().InnerXml)
        $wimImageName = $wimInformation.WIM.IMAGE.NAME

        Write-Verbose "Applying Windows Image '$wimImageName'"

        # Register callback to get progress information as applying an image can take several minutes
        #$wimCallbackId = [Microsoft.Wim.WimgApi]::RegisterMessageCallback($wimFileHandle, $wimMessageCallback, $wimImageName)
        [Microsoft.Wim.WimgApi]::ApplyImage($wimImageHandle, $Drive, [Microsoft.Wim.WimApplyImageOptions]::Verify)

    } catch {
        Throw "Failed to apply WIM Image. $($_.Exception.Message)"
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

