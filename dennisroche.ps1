[CmdletBinding()]
param()

Push-Location $PSScriptRoot
. .\Repave\Repave.ps1

$iso = ".\ISOs\en-gb_windows_8.1_professional_n_vl_with_update_x64_dvd_4050338.iso"

New-Gen2VHD -Size 25GB | Write-WindowsIsoToVhd -Iso $iso | Invoke-Repave {
}