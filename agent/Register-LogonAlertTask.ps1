<#
  Register-LogonAlertTask.ps1
  ---------------------------------------------------------------
  One-time setup: creates a Scheduled Task that triggers the instant
  Event ID 4625 is written to the Security log, and runs
  Send-LogonAlert.ps1 in response.

  Run this ONCE, as Administrator, on every PC you want monitored.
#>

param(
  [string]$ScriptPath = "C:\LogonMonitor\Send-LogonAlert.ps1",
  [string]$TaskName   = "LogonMonitor-4625-Alert"
)

# Trigger: fire whenever Event ID 4625 is logged in the Security log
$triggerXml = @"
<QueryList>
  <Query Id='0' Path='Security'>
    <Select Path='Security'>*[System[(EventID=4625)]]</Select>
  </Query>
</QueryList>
"@

$class = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler
$trigger = New-CimInstance -CimClass $class -ClientOnly
$trigger.Subscription = $triggerXml
$trigger.Enabled = $true

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
  -Principal $principal -Description "Emails alert on Windows Event 4625 (failed logon)" -Force

Write-Output "Task '$TaskName' registered. It will run Send-LogonAlert.ps1 on every 4625 event."
