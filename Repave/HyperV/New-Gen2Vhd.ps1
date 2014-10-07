function New-Gen2Vhd {
    [CmdletBinding()]
    param (
        [ValidateScript({ -not (Test-Path $_) })]
        [ValidatePattern("\.vhd(x)?$")]
        [string]$VhdPath,

        [ValidateRange(25GB, 64TB)]
        [UInt64]$Size=25GB,

        [ValidateSet(2MB, 256MB)]
        [UInt32]$BlockSize=2MB,

        [ValidateSet(512, 4096)]
        [Uint32]$LogicalSectorSize=4096,

        [ValidateSet(512, 4096)]
        [Uint32]$PhysicalSectorSize=4096
    )

    if ($VhdPath -eq '') {
        $guid = [Guid]::NewGuid()
        $VhdPath = ".\$guid.vhdx"
    }

    try {

        # Create VHD container
        $vhdOptions = @{
            Path = $VhdPath
            SizeBytes = $Size
            Dynamic = $true
            BlockSizeBytes = $BlockSize
            LogicalSectorSizeBytes = $LogicalSectorSize
            PhysicalSectorSizeBytes = $PhysicalSectorSize
        }

        Write-Verbose "Creating Hyper-V Virtual Disk (VHD) $($vhdOptions | Format-Table | Out-String)"
        New-VHD @vhdOptions | Out-Null

        # Mount VHD
        Write-Verbose "Mounting VHD '$VhdPath'"
        $disk = Mount-DiskImage -ImagePath (Resolve-Path $VhdPath) -Access ReadWrite
        $diskNumber = (Get-DiskImage (Resolve-Path $VhdPath) | Get-Disk).Number

        # Initialise GUID Partition Table (GPT)
        Write-Verbose "Initialise GUID Partition Table (GPT)"
        Initialize-Disk -Number $diskNumber -PartitionStyle GPT | Out-Null

        # GPT disks that are used to boot the Windows operating system, the Extensible Firmware Interface (EFI) 
        # system partition must be the first partition on the disk, followed by the Microsoft Reserved partition.
        Write-Verbose "Create Extensible Firmware Interface (EFI) partition"
        New-EfiPartition -DiskNumber $diskNumber -Size 100MB | Out-Null

        # Initial Size of MSR is 32 MB on disks smaller than 16 GB and 128 MB on other disks. 
        # The MSR partition is not visible within Microsoft Windows Disk Management snap-in, however 
        # is listed with Microsoft Diskpart commandline utility.
        Write-Verbose "Create Microsoft Reserved Partition (MSR) partition"
        if ($Size -lt 16GB) {
            New-MsrPartition -Disknumber $diskNumber -Size 32MB
        } else {
            New-MsrPartition -Disknumber $diskNumber -Size 128MB
        }

        # Create OS partition
        Write-Verbose "Create OS partition"
        New-Partition -DiskNumber $diskNumber -UseMaximumSize -AssignDriveLetter | 
          Format-Volume -FileSystem NTFS -NewFileSystemLabel "System" -confirm:$false | Out-Null

    } catch {
        Throw "Failed to create $VhdPath. $($_.Exception.Message)"
    } finally {
        if ($VhdPath -ne '') {
            Dismount-DiskImage -ImagePath (Resolve-Path $VhdPath) -ErrorAction SilentlyContinue | Out-Null
        }
    }

    return $VhdPath
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

    New-Partition -DiskNumber $diskNumber -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}' -Size $Size | Out-Null
}
