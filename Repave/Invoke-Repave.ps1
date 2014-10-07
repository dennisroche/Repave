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

    &$InstallScript

}