function Using-VHDRegistry {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory)]
        [string]$Key,

        [Parameter(Position=1, Mandatory)]
        [ValidateScript({Test-Path "$_"})]
        [string]$Drive,

        [Parameter(Position=2, Mandatory)]
        [ScriptBlock]$RegistryScript
    )

    try {
        $hiveLocation = "$($Drive)Windows\System32\config\$Key"

        & reg load HKLM\VHD_$Key (Resolve-Path $hiveLocation) | Out-Null

        New-PSDrive -Name "VHD" -PSProvider Registry -Root "HKLM\VHD_$Key" | Out-Null
        Write-Verbose "Mounted VHD Registry '$hiveLocation' as VHD:\"

        try {
            &$RegistryScript
        } catch {
            Write-Error "Error executing registry script $($_.Exception)"
        }

    } finally {
        Remove-PSDrive -Name "VHD" -ErrorAction SilentlyContinue | Out-Null
        # Force collect to release the handles to the loaded hive, otherwise reg unload *will* fail
        [GC]::Collect($true) | & reg unload HKLM\VHD_$Key 2>&1 | Out-Null
    }
}