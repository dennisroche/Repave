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
        $VhdPath = ".\temp_$guid.vhdx"
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
        Mount-DiskImage -ImagePath (Resolve-Path $VhdPath) -Access ReadWrite
        $diskNumber = (Get-DiskImage (Resolve-Path $VhdPath) | Get-Disk).Number
        $disk = Get-Disk -Number $diskNumber

        Write-Verbose "VHD Layout $(Get-Partition -Disk $disk | Out-String)"

        # Initialise GUID Partition Table (GPT)
        Write-Verbose "Initialise GUID Partition Table (GPT)"
        Initialize-Disk -Number $diskNumber -PartitionStyle GPT | Out-Null

        # GPT disks that are used to boot the Windows operating system, the Extensible Firmware Interface (EFI) 
        # system partition must be the first partition on the disk, followed by the Microsoft Reserved partition.
        Write-Verbose "Create Extensible Firmware Interface (EFI) partition"
        New-EfiPartition -DiskNumber $diskNumber -Size 260MB | Out-Null

        # Create OS partition
        Write-Verbose "Create OS partition"
        New-Partition -DiskNumber $diskNumber -UseMaximumSize -AssignDriveLetter | 
          Format-Volume -FileSystem NTFS -NewFileSystemLabel "Windows" -confirm:$false | Out-Null

        $drive = $(Get-Partition -Disk $disk).AccessPaths[3]
        Write-Verbose "$drive has been assigned to the Boot Volume"

        Write-Verbose "VHD Layout $(Get-Partition -Disk $disk | Out-String)"

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
        [Parameter(Position=0, Mandatory)]
        [UInt32]$DiskNumber,

        [ValidateRange(100MB, 300MB)]
        [UInt64]$Size=100MB
    )

    # Create EFI partition and a basic data partition (BDP)
    $disk = Get-Disk -Number $DiskNumber
    $partitionSystem = New-Partition -DiskNumber $DiskNumber -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93bc}' -Size $Size
    $partitionSystemNumber = $partitionSystem.PartitionNumber

@"
select disk $DiskNumber
select partition $partitionSystemNumber
format quick fs=fat32 label=System
exit
"@ | diskpart | %{ Write-Verbose "[DiskPart] $_" }

    $partitionSystem | Add-PartitionAccessPath -AssignDriveLetter
    $driveSystem = $(Get-Partition -Disk $disk).AccessPaths[1]
    Write-Verbose "$driveSystem has been assigned to the System Volume"
}