function Restore-NuGetPackages {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory)]
        [ValidateNotNullorEmpty()]
        [ValidateScript({ Test-Path $_ })]
        [ValidatePattern("\.config$")]
        [string]$PackageConfig
    )

    New-Item -ItemType Directory -Force -Path ".\packages" | Out-Null
    & nuget restore (Resolve-Path $PackageConfig) -PackagesDirectory (Resolve-Path ".\packages") | %{ Write-Verbose "[NuGet] $_" }
}
