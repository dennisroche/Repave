function Get-VhdDriveLetter
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateScript({ Test-Path $_ })]
        [ValidatePattern("\.vhd(x)?$")]
        [string]$VhdPath,

        [string]$VolumeName
    )

    # Windows 8.0/8.1 needs to use ROOT\virtualization\v2
    $diskImage = Get-WmiObject -Namespace ROOT\virtualization\v2 -Query ("SELECT * FROM Msvm_MountedStorageImage WHERE Name ='$($VhdPath.Replace("\", "\\"))'")

    $disk = Get-WmiObject -Query ("SELECT * FROM Win32_DiskDrive WHERE Model LIKE '%Virtual Disk%'")
    
    $partitions = $disk.GetRelated("Win32_DiskPartition")
    $logicalDisks = $partitions | %{ $_.GetRelated("Win32_logicalDisk") }
    $driveLetter = ($logicalDisks | Where {$_.VolumeName -eq $volumeName}).DeviceID

    return $driveLetter
}