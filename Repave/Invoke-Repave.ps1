function Invoke-Repave {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ScriptBlock]$InstallScript,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullorEmpty()]
        [ValidateScript({ Test-Path $_ })]
        [ValidatePattern("\.(a)?vhd(x)?$")]
        [string]$VhdPath
    )

    try {

        Start-Transcript "$PSSessionApplicationName-repave.log"

        # Mount VHD to begin Repave
        Mount-DiskImage -ImagePath (Resolve-Path $VhdPath) -Access ReadWrite | Out-Null
        $drive = Get-VhdDriveLetter (Resolve-Path $VhdPath) "Windows System"

        &$InstallScript

    } finally {
        Sleep -Seconds 5
        Dismount-DiskImage -ImagePath (Resolve-Path $VhdPath) -ErrorAction SilentlyContinue | Out-Null
        Stop-Transcript
    }
}