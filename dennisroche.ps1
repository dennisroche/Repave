#Requires -Version 3.0
#Requires -RunAsAdministrator

Push-Location $PSScriptRoot

. .\Repave\Repave.ps1
Init-Repave

$iso = ".\ISOs\en-gb_windows_8.1_professional_n_vl_with_update_x64_dvd_4050338.iso"
$vhdPath = New-Gen2VHD -size 25GB
Write-WindowsIsoToVhd $iso $vhdPath

Invoke-Repave $vhdPath {

}