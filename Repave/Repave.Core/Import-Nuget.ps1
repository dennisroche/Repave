function Import-Nuget {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullorEmpty()]
        [ValidateScript({ Test-Path $_ })]
        [ValidatePattern("\.config$")]
        [string]$PackageConfig,

        [Parameter(Position=1, ParameterSetName="RestorePackages")]
        [switch]$RestorePackages,

        [Parameter(Position=2)]
        [ScriptBlock]$PostRestoreScript
    )

    Push-Location (Get-ChildItem $PackageConfig | %{ $_.Directory.FullName })

        if ($RestorePackages) {
            New-Item -ItemType Directory -Force -Path ".\packages" | Out-Null
            & nuget restore (Resolve-Path $PackageConfig) -PackagesDirectory (Resolve-Path ".\packages") | %{ Write-Verbose "$_" }
        }

        &$PostRestoreScript

    Pop-Location
}
