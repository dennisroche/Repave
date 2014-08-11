function Add-ToPath() {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        [ValidateScript({ Test-Path $_ })]
        [string]$path
    )

    # Get the current search path from the environment keys in the registry.
    $currentPath = (Get-ItemProperty -Path "Registry::HKLM\System\CurrentControlSet\Control\Session Manager\Environment" -Name PATH).Path

    if ($Env:Path | Select-String -SimpleMatch $path) { 
        Write-Warning "$ENV:PATH already has $path"
    }

    $NewPath= "$currentPath;$path"
    Set-ItemProperty -Path "Registry::HKLM\System\CurrentControlSet\Control\Session Manager\Environment" -Name PATH –Value $newPath

    return $NewPath
}