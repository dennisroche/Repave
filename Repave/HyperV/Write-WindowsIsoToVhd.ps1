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
        $diskNumber = (Get-DiskImage (Resolve-Path $VhdPath) | Get-Disk).Number
        $disk = Get-Disk -Number $diskNumber

        Add-PartitionAccessPath -DiskNumber $diskNumber -PartitionNumber 2 -AssignDriveLetter
        $driveSystem = $(Get-Partition -Disk $disk).AccessPaths[1]
        $drive =  $(Get-Partition -Disk $disk).AccessPaths[2]

        Write-Verbose "VHD Layout $(Get-Partition -Disk $disk | Out-String)"

        # Apply Windows Image to VHD
        Write-WimImage -WimPath $wimPath -TargetPath $drive

        # Copy critical boot files to the system partition to create a new system BCD store
        # "Self-Sustainable", i.e. contains a boot loader and does not depend on external files.
        $driveSystemVolumeLetter = $driveSystem.TrimEnd('\')
        $bcdBootParams = @(
            "$($drive)Windows"
            "/s $($driveSystemVolumeLetter)"
            "/f UEFI"
            "/v"
        )

        Write-Verbose "Create a new system BCD store"
        Start-Process bcdboot -ArgumentList $bcdBootParams -NoNewWindow | Out-Null

        # Get details of installed version
        $imageDetails = Get-WindowsImageDetails $drive
        Write-Verbose "Installed Image Details $($imageDetails | Format-Table | Out-String)"
        $vhdFinalName = "Repave_$(Get-Date -f MM-dd-yyyy_HH_mm_ss)_$($imageDetails.BuildLabEx)_$($imageDetails.SkuFamily)_$($imageDetails.EditionId).vhdx"

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
        [ValidateScript({Test-Path "$_"})]
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