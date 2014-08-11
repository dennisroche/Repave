#Requires -Version 3.0
#Requires -RunAsAdministra

function Init-Repave() {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'
    trap {
        $Host.UI.WriteErrorLine($_)
        Pop-Location
        Exit 1
    }

    # Import Repave
    Push-Location $PSScriptRoot
        
        Get-ChildItem -Path . -Include "Repave*" -Directory | %{ 
            $module = Import-Module $_ -PassThru -Force
        }

        $assembly = Import-Assembly ".\Repave\WimInterop.dll"

        Write-Verbose "Repave Commands $(Get-Command -Module Repave* | Sort-Object ModuleName | Format-Table -AutoSize -Property ModuleName,Name,CommandType | Out-String)"
        
    Pop-Location

}