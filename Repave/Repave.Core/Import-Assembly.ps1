function Import-Assembly {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullorEmpty()]
        [ValidateScript({ Test-Path $_ })]
        [ValidatePattern("\.dll$")]
        [string]$Dll
    )

    # Load the DLL as a byte stream so that the PS console doesn't lock/hold a reference
    $fileStream = ([System.IO.FileInfo] (Get-Item $Dll)).OpenRead()
    $assemblyBytes = New-Object byte[] $fileStream.Length
    $fileStream.Read($assemblyBytes, 0, $fileStream.Length)
    $fileStream.Close()

    $assemblyLoaded = [System.Reflection.Assembly]::Load($assemblyBytes)
    return $assemblyLoaded
}
