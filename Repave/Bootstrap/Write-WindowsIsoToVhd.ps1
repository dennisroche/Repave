function Write-WindowsIsoToVhd {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [ValidatePattern("\.iso$")]
        [string]$IsoPath,

        [Parameter(Position=1, Mandatory)]
        [ValidateScript({ Test-Path $_ })]
        [ValidatePattern("\.vhd(x)?$")]
        [string]$VhdPath
    )

    try {
        # Mount ISO and select the install.wim file
        $openIso = Mount-DiskImage -ImagePath (Resolve-Path $IsoPath) -StorageType ISO -PassThru | Get-Volume
        $wimPath = "$($openIso.DriveLetter):\sources\install.wim"
        
        if (!(Test-Path $WimPath)) {
            Throw "The specified ISO does not appear to be valid Windows installation media."
        }

        # Mount VHD to apply Windows image
        Mount-DiskImage -ImagePath (Resolve-Path $VhdPath) -Access ReadWrite | Out-Null
        $drive = Get-VhdDriveLetter (Resolve-Path $VhdPath) "Windows System"

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

            $vhdFinalName = " $(Get-Date -f MM-dd-yyyy_HH_mm_ss)_$($buildLabEx)_$($skuFamily)_$($editionId)_$($openImage.ImageDefaultLanguage)"
        }

        $VhdPath = Rename-Item -Path (Resolve-Path $VhdPath).Path -NewName $vhdFinalName -Force

    } finally {
        Dismount-DiskImage -ImagePath (Resolve-Path $IsoPath)
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
        [string]$DriveLetter

    )

    $WimMessageCallback = {
        param ( 
            [Microsoft.Wim.WimMessageType]$messageType,
            [PSObject]$message,
            [PSObject]$userData
        )

        if ($messageType -eq [Microsoft.Wim.WimMessageType]::Progress) {
            $progressMessage = [Microsoft.Wim.WimMessageProgress]$message;
            Write-Progress -Activity "Applying Image" -PercentComplete $progressMessage.PercentComplete -SecondsRemaining $progressMessage.EstimatedTimeRemaining
        } 
        elif ($messageType -eq [Microsoft.Wim.WimMessageType]::Warning) {
            $warningMessage = [Microsoft.Wim.WimMessageWarning]$message;
            Write-Warning "$($warningMessage.Path) - $($warningMessage.Win32ErrorCode)"
        }
        elif ($messageType -eq [Microsoft.Wim.WimMessageType]::Error) {
            $errorMessage = [Microsoft.Wim.WimMessageError]$message;
            Write-Warning "$($errorMessage.Path) - $($errorMessage.Win32ErrorCode)"
        }

        return [Microsoft.Wim.WimMessageResult]::Success
    }

    $wimFileHandle = $null
    $wimImageHandle = $null

    try {
        # Get a native handle on *.wim container
        $wimFileHandle = [Microsoft.Wim.WimgApi]::CreateFile($WimPath, [Microsoft.Wim.WimFileAccess]::Read, 
            [Microsoft.Wim.WimCreationDisposition]::OpenExisting, [Microsoft.Wim.WimCreateFileOptions]::None, 
            [Microsoft.Wim.WimCompressionType]::None)

        # Always set a temporary path
        [Microsoft.Wim.WimgApi]::SetTemporaryPath($wimFileHandle, $env:temp)

        $imageCount = [Microsoft.Wim.WimgApi]::GetImageCount($wimFileHandle)
        $wimImageHandle = [Microsoft.Wim.WimgApi]::LoadImage($wimFileHandle, 1)
  
        [Microsoft.Wim.WimgApi]::RegisterMessageCallback($wimFileHandle, $WimMessageCallback)
        [Microsoft.Wim.WimgApi]::ApplyImage($wimImageHandle, $DriveLetter, [Microsoft.Wim.WimApplyImageOptions]::None);
    } catch {
        Throw "Failed to create apply Wim Image. $($_.Exception.Message)"
    } finally {
    
        if ($wimImageHandle -ne $null) {
            $wimImageHandle.Close()
            $wimImageHandle = $null
        }
    
        if ($wimFileHandle -ne $null) {
            [Microsoft.Wim.WimgApi]::UnregisterMessageCallback($wimFileHandle, $WimMessageCallback)
            $wimFileHandle.Close()
            $wimFileHandle = $null
        }
    }
}

