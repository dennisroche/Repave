[CmdletBinding()]
param()

# Error handling
$ErrorActionPreference = "Stop"
trap
{
    Pop-Location
    $Host.UI.WriteErrorLine($_)
    Exit 1
}

# Include Repave scripts
Get-ChildItem $PSScriptRoot -Recurse -Include *.ps1 -Exclude 'Repave.ps1' | %{ 
    Write-Verbose "Dot-sourcing the script file '$($_.FullName)'"
    . $_.FullName 
}

# Restore packages
Restore-NuGetPackages "$PSScriptRoot\packages.config"

# Import Windows Image DLLs
Import-Assembly "Microsoft.Win32Ex" | Out-Null
Import-Assembly "Microsoft.Wim" | Out-Null
Import-Assembly "Microsoft.Wim.Powershell" -AsModule | Out-Null