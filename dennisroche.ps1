#Repave
#Requires –Version 4
#Requires -RunAsAdministrator
[CmdletBinding()]
param()

Push-Location $PSScriptRoot
Import-Module .\Repave\Repave.psd1 -Verbose -Force

$iso = ".\ISOs\en-gb_windows_8.1_professional_n_vl_with_update_x64_dvd_4050338.iso"
New-Gen2Vhd -Size 25GB | Write-WindowsIsoToVhd -Iso $iso | Invoke-Repave -InstallScript {
    Write-Host "It is repaving time"
}