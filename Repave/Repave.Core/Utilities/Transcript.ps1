function Start-Transcript() {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidatePattern("\.log$")]
        [string]$filename
    )

    if ($Host.Name -ne "Windows PowerShell ISE Host") {
        Start-Transcript -path "$filename" -append
    }
}

function End-Transcript() {
    if ($Host.Name -ne "Windows PowerShell ISE Host") {
        Stop-Transcript
    }
}