function Start-Transcript {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory)]
        [ValidatePattern("\.log$")]
        [string]$filename
    )

    if ($Host.Name -ne "Windows PowerShell ISE Host") {
        Start-Transcript -path "$filename" -append
    }
}

function Stop-Transcript {
    if ($Host.Name -ne "Windows PowerShell ISE Host") {
        Stop-Transcript
    }
}