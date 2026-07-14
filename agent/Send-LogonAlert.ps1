<#
  Send-LogonAlert.ps1
  ---------------------------------------------------------------
  Fires (via Task Scheduler) the instant a Windows Security event
  matching EventID 4625 (failed logon) is written to the log.
  Reads the newest matching event and POSTs it to the Next.js API.
  Requires: Run as Administrator (reading the Security log needs it).
#>
param(
  [string]$ApiUrl = "http://192.169.10.220:3000/api/logon-event",
  [string]$ApiSecret = "123456",
  [int]$EventId      = 4625
)

$logFile = "C:\LogonMonitor\alert-log.txt"

# Grab the single most recent matching event from the Security log
$xmlFilter = @"
<QueryList>
  <Query Id='0' Path='Security'>
    <Select Path='Security'>*[System[(EventID=$EventId)]]</Select>
  </Query>
</QueryList>
"@
$event = Get-WinEvent -FilterXml $xmlFilter -MaxEvents 1 -ErrorAction SilentlyContinue
if (-not $event) {
  "$(Get-Date -Format o) - NO EVENT FOUND" | Out-File -FilePath $logFile -Append
  Write-Output "No matching event found."
  exit 0
}

# Pull useful fields out of the event XML
[xml]$eventXml = $event.ToXml()
$eventData = $eventXml.Event.EventData.Data
function Get-EventValue($name) {
  ($eventData | Where-Object { $_.Name -eq $name }).'#text'
}

$payload = @{
  computerName  = $env:COMPUTERNAME
  eventId       = $EventId
  account       = Get-EventValue "TargetUserName"
  sourceIp      = Get-EventValue "IpAddress"
  timestamp     = $event.TimeCreated.ToString("o")
  failureReason = Get-EventValue "FailureReason"
} | ConvertTo-Json

try {
  Invoke-RestMethod -Uri $ApiUrl -Method Post -Body $payload `
    -ContentType "application/json" `
    -Headers @{ "x-api-secret" = $ApiSecret }
  "$(Get-Date -Format o) - SUCCESS - Alert sent for $($env:COMPUTERNAME)" | Out-File -FilePath $logFile -Append
  Write-Output "Alert sent successfully."
} catch {
  "$(Get-Date -Format o) - FAILED - $_" | Out-File -FilePath $logFile -Append
  Write-Output "Failed to send alert: $_"
}