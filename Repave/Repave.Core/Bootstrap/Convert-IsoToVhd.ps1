#Requires -version 4.0
#Requires -modules Hyper-V,Storage
#Requires -RunAsAdministrator

function Convert-IsoToVhd {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [ValidatePattern("\.iso$")]
        [string]$isoPath,

        [ValidateRange(25GB, 64TB)]
        [UInt64]$size=25GB
    )

    # Create a new Generation2 VHD, i.e. with UEFI support
    $guid = [Guid]::NewGuid()
    $vhdPath = ".\$guid.vhdx"
    New-Gen2VHD $vhdPath -size $size

    try {
        # Mount ISO and select the install.wim file
        $openIso = Mount-DiskImage -ImagePath (Resolve-Path $isoPath) -StorageType ISO -PassThru | Get-Volume
        $wimPath = "$($openIso.DriveLetter):\sources\install.wim"
 
        $instalationMedia = New-Object -TypeName WimInterop.WimFile -ArgumentList $wimPath
        if (($instalationMedia -eq $null) -or ($instalationMedia.Images -eq 0)) {
            Throw "The specified ISO does not appear to be valid Windows installation media."
        }

        # Load first edition
        $edition   = $instalationMedia.Images[0].ImageFlags
        $image = $instalationMedia[$edition]

        # Mount VHD to apply Windows image
        $openVhd = Mount-DiskImage -ImagePath (Resolve-Path $vhdPath) -PassThru | Get-Volume
        $drive = (Get-DiskImage (Resolve-Path $vhdPath) | Get-Disk).DriveLetter

        $image.Apply($drive)

        # Todo, show progress as applying the image can take several minutes.
        #Write-Progress

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
        $vhdPath = Rename-Item -Path (Resolve-Path $vhdPath).Path -NewName $vhdFinalName -Force

    } finally {
        Dismount-DiskImage -ImagePath (Resolve-Path $isoPath)
    }

    return $vhdPath
}



function New-MsrPartition {
    param (
        [Parameter(Position=0, Mandatory=$true)]
        [UInt32]$DiskNumber,

        [ValidateSet(32MB, 128MB)]
        [UInt64]$Size=32GB
    )

    $partition = New-Partition -DiskNumber $diskNumber -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}' -Size $size
    $partitionNumber = $partition.PartitionNumber
}
