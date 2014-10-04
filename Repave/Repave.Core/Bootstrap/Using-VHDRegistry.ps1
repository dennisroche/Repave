#Requires -Version 3.0

function Using-VHDRegistry {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory)]
        [string]$Key,

        [Parameter(Position=1, Mandatory)]
        [ValidateScript({Test-Path "$_\"})]
        [ValidatePattern("^[A-Z]?:$")]
        [string]$DriveLetter,

        [Parameter(Position=2, Mandatory)]
        [ScriptBlock]$Script
    )

    try {
        reg load HKLM\VHD_$Key "$DriveLetter\Windows\System32\config\$Key" | Out-Null
        New-PSDrive -Name "VHD" -PSProvider Registry -Root HKLM\VHD_$Key
        &$Script
    } finally {
        Remove-PSDrive -Name "VHD"
        # Force collect to release the handles to the loaded hive, otherwise reg unload will fail
        [GC]::Collect($true) | reg unload HKLM\VHD_$Key 2>&1 | Out-Null
    }
}