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

function New-Gen2VHD {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [ValidateScript({ -not (Test-Path $_) })]
        [ValidatePattern("\.(a)?vhd(x)?$")]
        [string]$vhdPath,

        [ValidateRange(25GB, 64TB)]
        [UInt64]$size=25GB,

        [UInt32]$blockSizeBytes=2MB,

        [ValidateSet(512, 4096)]
        [Uint32]$logicalSectorSizeBytes=4096,

        [ValidateSet(512, 4096)]
        [Uint32]$physicalSectorSizeBytes=4096
    )

    try {
        # New-VHD requires the Hyper-V extensions
        New-VHD -Path $vhdPath -SizeBytes $size -Dynamic -BlockSizeBytes $blockSizeBytes -LogicalSectorSizeBytes $logicalSectorSizeBytes -PhysicalSectorSizeBytes $physicalSectorSizeBytes

        $disk = Mount-DiskImage -ImagePath (Resolve-Path $vhdPath) -Access ReadWrite
        $diskNumber = (Get-DiskImage (Resolve-Path $vhdPath) | Get-Disk).Number

        # Initialize GPT partition
        Initialize-Disk -Number $diskNumber -PartitionStyle GPT
        
        # GPT disks that are used to boot the Windows operating system, the Extensible Firmware Interface (EFI) 
        # system partition must be the first partition on the disk, followed by the Microsoft Reserved partition.
        New-EfiPartition -DiskNumber $diskNumber -Size 100MB

        # Initial size of MSR is 32 MB on disks smaller than 16 GB and 128 MB on other disks. 
        # The MSR partition is not visible within Microsoft Windows Disk Management snap-in, however is listed with Microsoft Diskpart commandline utility.
        if ($size -lt 16GB) {
            New-MsrPartition -Disknumber $diskNumber -Size 32MB
        } else {
            New-MsrPartition -Disknumber $diskNumber -Size 128MB
        }
        
        # Create OS partition
        New-Partition -DiskNumber $diskNumber -UseMaximumSize -AssignDriveLetter | 
          Format-Volume -FileSystem NTFS -NewFileSystemLabel "Windows System" -confirm:$false

        return $vhdPath
    } catch {
        Throw "Failed to create $vhdPath. $($_.Exception.Message)"
    } finally {
        Dismount-DiskImage -ImagePath (Resolve-Path $vhdPath)
    }

}

function New-EfiPartition {
    param (
        [Parameter(Position=0, Mandatory=$true)]
        [UInt32]$DiskNumber,

        [ValidateRange(100MB, 300MB)]
        [UInt64]$Size=100GB
    )

    $partition = New-Partition -DiskNumber $DiskNumber -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93bc}' -Size $Size
    $partitionNumber = $partition.PartitionNumber

@"
select disk $diskNumber
select partition $partitionNumber
format quick fs=fat32 label=System
exit
"@ | diskpart | Out-Null

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
