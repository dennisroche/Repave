@{
    ModuleVersion = '0.1'
    GUID = '7A094676-A8A9-4A09-BD6E-B27986BB3ADE'
    Author = 'Dennis Roche'
    Description = 'A PowerShell module that allows you to easily create a new Hyper-V Virtual Hard Disk with Microsoft Windows, configurable with a terse script'
    PowerShellVersion = '4.0'
    CLRVersion = '4.0'
    DotNetFrameworkVersion = '4.5'
    RequiredModules = @('Hyper-V', 'Storage')
    ScriptsToProcess = @('Repave.ps1')
    FunctionsToExport = 'Invoke-Repave', 'New-Gen2Vhd', 'Write-WindowsIsoToVhd'
}