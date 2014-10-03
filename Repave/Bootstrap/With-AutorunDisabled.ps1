#Requires -Version 3.0

function With-AutorunDisabled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ScriptBlock]$script
    )

    $path ='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    $originalValue = 145 # Default
    try {
        $originalValue = (Get-ItemProperty $path -Name NoDriveTypeAutorun).NoDriveTypeAutoRun
        Set-ItemProperty $path -Name NoDriveTypeAutorun -Value 255
        &$script
    } finally {
        Set-ItemProperty $path -Name NoDriveTypeAutorun -Value $originalValue
    }
}

