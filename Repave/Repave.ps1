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

        Restore-NuGetPackages -PackageConfig ".\packages.config" {
            Import-Assembly "Microsoft.Win32Ex" | Out-Null
            Import-Assembly "Microsoft.Wim" | Out-Null
        }

    Pop-Location

}