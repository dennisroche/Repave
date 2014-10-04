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

        Import-Nuget -PackageConfig ".\packages.config" -RestorePackages {
            Import-Assembly ".\packages\Microsoft.Win32Ex.1.0.5137.22482\lib\net20\Microsoft.Win32Ex.dll" | Out-Null
            Import-Assembly ".\packages\Microsoft.Wim.1.0.5231.24127\lib\net35-Client\Microsoft.Wim.dll" | Out-Null
        }

        Write-Verbose "Repave Commands $(Get-Command -Module Repave* | Sort-Object ModuleName | Format-Table -AutoSize -Property ModuleName,Name,CommandType | Out-String)"
        
    Pop-Location

}