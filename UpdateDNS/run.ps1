using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$rg = $Request.Query.Group
$name = $Request.Query.Name
$zone = $Request.Query.Zone
$reqIP = $Request.Query.reqIP

if (-not $rg) {
    $rg = $Request.Body.Group
}

if (-not $name) {
    $name = $Request.Body.Name
}

if (-not $zone) {
    $zone = $Request.Body.Zone
}

if (-not $reqIP) {
    $reqIP = $Request.Body.reqIP
}

If ($name -and $zone -and $reqIP) {
    #Check if name passed is already in DNS zone that was passed
    Try {$CurrentRec=Get-AzDnsRecordSet -Name $name -RecordType A -ZoneName $zone -ResourceGroupName $rg}
    Catch { write-host "Caught an exception:" -ForegroundColor Red
            write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red }
    If ($CurrentRec) {
        Write-Host "There is a current A record for $name in zone $zone"
        #Check current record IP against source/requested IP
        Write-Host "IP Address $reqIP passed - updating DNS record accordingly"
        $CurrentRec.Records[0].Ipv4Address = $reqIP
        Set-AzDnsRecordSet -RecordSet $CurrentRec
        $body = "good $reqIP"
        $status = [HttpStatusCode]::OK
        Write-Host $body
    } else {
        Write-Host "No current A record for $name in zone $zone, adding now."
        New-AzDnsRecordSet -Name $name -RecordType A -ZoneName $zone -ResourceGroupName $rg -Ttl 3600 -DnsRecords (New-AzDnsRecordConfig -Ipv4Address $reqIP)
        $status = [HttpStatusCode]::OK
        $body = "good $reqIP"
        Write-Host $body
    }      
} else {
    $status = [HttpStatusCode]::BadRequest
    $body = "Please pass a name, a zone and the reqIP param on the query string or in the request body."
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $body
})
