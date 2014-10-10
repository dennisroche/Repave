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

        Write-WimImage -WimPath $wimPath -TargetPath $drive

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