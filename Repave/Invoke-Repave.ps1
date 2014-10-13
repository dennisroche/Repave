function Invoke-Repave {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullorEmpty()]
        [ValidateScript({ Test-Path $_ })]
        [ValidatePattern("\.vhd(x)?$")]
        [string]$VhdPath,

        [Parameter(Mandatory)]
        [ScriptBlock]$InstallScript
    )

    try {

        Mount-DiskImage -ImagePath (Resolve-Path $VhdPath) -Access ReadWrite | Out-Null
        $diskNumber = (Get-DiskImage (Resolve-Path $VhdPath) | Get-Disk).Number
        $disk = Get-Disk -Number $diskNumber
        $drive =  $(Get-Partition -Disk $disk).AccessPaths[2]

        &$InstallScript $drive

    } finally {
        Dismount-DiskImage -ImagePath (Resolve-Path $VhdPath) -ErrorAction SilentlyContinue | Out-Null
    }

    New-VM -Name "Repave_$(Get-Date -f MM-dd-yyyy_HH_mm_ss)" -Generation 2 -MemoryStartupBytes 1024MB -VHDPath $VhdPath

}