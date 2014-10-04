function Invoke-Repave {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory)]
        [ValidateNotNullorEmpty()]
        [ValidateScript({ Test-Path $_ })]
        [ValidatePattern("\.(a)?vhd(x)?$")]
        [string]$Vhdpath,

        [Parameter(Position=1, Mandatory)]
        [ScriptBlock]$InstallScript
    )

    try {

        Start-Transcript "$PSSessionApplicationName-repave.log"
        
        # Mount VHD to apply Windows image
        Mount-DiskImage -ImagePath (Resolve-Path $VhdPath) -Access ReadWrite | Out-Null
        $drive = Get-VhdDriveLetter (Resolve-Path $VhdPath) "Windows System"

        &$InstallScript

    } finally {
        Sleep -Seconds 5
        Dismount-DiskImage -ImagePath (Resolve-Path $VhdPath) -ErrorAction SilentlyContinue | Out-Null
        Stop-Transcript
    }
}