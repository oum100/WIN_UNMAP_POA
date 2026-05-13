<#
05-Stop-PerfMonBLG.ps1
Stops native Windows PerfMon BLG collector.
#>

param(
    [string]$CollectorName = "TrimPoaDiskLatency"
)

logman stop $CollectorName -ets 2>$null | Out-Null
logman delete $CollectorName 2>$null | Out-Null

Write-Host "PerfMon BLG collector stopped."
