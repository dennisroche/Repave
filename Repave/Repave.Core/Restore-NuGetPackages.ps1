function Restore-NuGetPackages {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory)]
        [ValidateNotNullorEmpty()]
        [ValidateScript({ Test-Path $_ })]
        [ValidatePattern("\.config$")]
        [string]$PackageConfig,

        [Parameter(Position=1)]
        [ScriptBlock]$PostRestoreScript
    )

    Push-Location (Get-ChildItem $PackageConfig | %{ $_.Directory.FullName })

        New-Item -ItemType Directory -Force -Path ".\packages" | Out-Null
        & nuget restore (Resolve-Path $PackageConfig) -PackagesDirectory (Resolve-Path ".\packages") | %{ Write-Verbose "$_" }
        
        if ($PostRestoreScript -ne $null) {
            &$PostRestoreScript
        }

    Pop-Location
}
