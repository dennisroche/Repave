function Enable-FireWallRule {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory, ValueFromPipeline)]
        [string]$path,

        [Parameter(Position=1, Mandatory)]
        [string]$ruleName
    )

    $rules = Get-ItemProperty $key
    $rule = $rules.$ruleName
    $newVal = $rule.Replace("|Active=FALSE|","|Active=TRUE|")
    Set-ItemProperty $key -Name $ruleName -Value $newVal
    Write-Output "Changed $ruleName firewall rule to: $newVal"
}

function Disable-FireWallRule {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory, ValueFromPipeline)]
        [string]$path,

        [Parameter(Position=1, Mandatory)]
        [string]$ruleName
    )

    $rules = Get-ItemProperty $key
    $rule = $rules.$ruleName
    $newVal = $rule.Replace("|Active=TRUE|","|Active=FALSE|")
    Set-ItemProperty $key -Name $ruleName -Value $newVal
    Write-Output "Changed $ruleName firewall rule to: $newVal"
}