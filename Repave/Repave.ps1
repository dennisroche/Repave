[CmdletBinding()]
param()

Get-ChildItem $PSScriptRoot -Recurse -Include *.ps1 -Exclude 'Repave.ps1' | %{ 
    Write-Verbose "Dot-sourcing the script file '$($_.FullName)'"
    . $_.FullName 
}

Restore-NuGetPackages "$PSScriptRoot\packages.config"
Import-Assembly "Microsoft.Win32Ex" | Out-Null
Import-Assembly "Microsoft.Wim" | Out-Null