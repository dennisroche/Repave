<#

    .DESCRIPTION
        A PowerShell module that allows you to easily create a terse re-pave script for a Windows Machine, targeting either a local or remote
        installation (i.e. a Hyper-V/Bare-metal VHDx)

#>
#Requires -Version 3.0

function Init-Repave() {
    Import-Assembly (Resolve-Path ".\Repave\WimInterop.dll")
    Write-Debug "Loaded $_ $($dll | Where -Property IsPublic | Format-Table -AutoSize -Property Name,BaseType | Out-String)"
}

Get-ChildItem $PSScriptRoot -Recurse -Include *.ps1 | %{ . $_.FullName }

Export-ModuleMember -Function Init, Import-*, New-Gen2VHD, Write-WindowsIsoToVhd, Add-ToPath, Retry