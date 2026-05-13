<#
08-Export-WindowsTrimEvidence.ps1
Exports final Windows evidence.
#>

param(
    [string]$OutputDir = "C:\Temp\TrimTest"
)

if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$dir = Join-Path $OutputDir "eventlogs-$ts"
New-Item -ItemType Directory -Path $dir -Force | Out-Null

wevtutil epl System (Join-Path $dir "System.evtx")
wevtutil epl Application (Join-Path $dir "Application.evtx")

if (Get-WinEvent -ListLog "Microsoft-Windows-Defrag/Operational" -ErrorAction SilentlyContinue) {
    wevtutil epl "Microsoft-Windows-Defrag/Operational" (Join-Path $dir "Defrag-Operational.evtx")
    Get-WinEvent -LogName "Microsoft-Windows-Defrag/Operational" -MaxEvents 1000 |
        Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, Message |
        Export-Csv (Join-Path $dir "Defrag-Operational.csv") -NoTypeInformation -Encoding UTF8
} else {
    "Defrag Operational log not found." | Out-File (Join-Path $dir "Defrag-Operational.txt") -Encoding UTF8
}

$rx = "disk|stor|storport|stornvme|mpio|partmgr|volmgr|ntfs|refs|vmware|pvscsi|Veritas|Vx|VRTS|vxio|vxvm"

Get-WinEvent -LogName System -MaxEvents 3000 |
    Where-Object { $_.ProviderName -match $rx -or $_.Message -match "reset|timeout|failed|error|retry|path|queue|stor|disk" } |
    Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, Message |
    Export-Csv (Join-Path $dir "System-storage-filtered.csv") -NoTypeInformation -Encoding UTF8

Get-ScheduledTask -TaskPath "\Microsoft\Windows\Defrag\" -TaskName "ScheduledDefrag" |
    Format-List * |
    Out-File (Join-Path $dir "ScheduledDefrag-task-state.txt") -Encoding UTF8

fsutil behavior query DisableDeleteNotify 2>&1 |
    Out-File (Join-Path $dir "trim-status.txt") -Encoding UTF8

$zip = Join-Path $OutputDir "windows-eventlogs-$ts.zip"
Compress-Archive -Path $dir -DestinationPath $zip -Force

Write-Host "Windows evidence exported."
Write-Host "Output: $zip"
