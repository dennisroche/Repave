function Retry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false, ParameterSetName="Attemps")]
        [int]$maxAttempts = 3,
        
        [Parameter(Mandatory=$false, ParameterSetName="Delay")]
        [int]$secondsBeforeRetrying = 5,
                
        [Parameter(Mandatory=$true)]
        [ScriptBlock]$script
    )
 
    $attempts = 0
    
    do {
	    try {
		    &$script
		} catch {
            $attempts = $attempts + 1
		    if ($attempts -gt $maxAttempts){
			    Throw
		    }
		    Start-Sleep -Seconds $secondsBeforeRetrying
	    }
    } while ($true)
 
}