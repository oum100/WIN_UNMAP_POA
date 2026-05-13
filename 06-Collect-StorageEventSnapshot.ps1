<#
06-Collect-StorageEventSnapshot.ps1
Collects storage-related Windows event snapshot.
#>

param(
    [string]$OutputDir = "C:\Temp\TrimTest\StorageSnapshot",
    [int]$MaxEvents = 3000
)

if ($MaxEvents -lt 1) {
    throw "MaxEvents must be greater than or equal to 1."
}

if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path $OutputDir "storage-snapshot-$stamp"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

"Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')" | Out-File (Join-Path $outDir "timestamp.txt") -Encoding UTF8

fsutil behavior query DisableDeleteNotify 2>&1 |
    Out-File (Join-Path $outDir "fsutil-disabledeletenotify.txt") -Encoding UTF8

Get-Process defrag -ErrorAction SilentlyContinue |
    Select-Object ProcessName, Id, CPU, StartTime, Path |
    Export-Csv (Join-Path $outDir "defrag-process-now.csv") -NoTypeInformation -Encoding UTF8

Get-Disk |
    Select-Object Number, FriendlyName, SerialNumber, BusType, OperationalStatus, HealthStatus, Size |
    Export-Csv (Join-Path $outDir "get-disk.csv") -NoTypeInformation -Encoding UTF8

Get-Volume |
    Select-Object DriveLetter, FileSystemLabel, FileSystem, DriveType, HealthStatus, SizeRemaining, Size |
    Export-Csv (Join-Path $outDir "get-volume.csv") -NoTypeInformation -Encoding UTF8

$providerRegex = "disk|stor|storport|stornvme|mpio|partmgr|volmgr|ntfs|refs|vmware|pvscsi|Veritas|Vx|VRTS|vxio|vxvm"

Get-WinEvent -LogName System -MaxEvents $MaxEvents |
    Where-Object { $_.ProviderName -match $providerRegex -or $_.Message -match "reset|timeout|failed|error|retry|path|queue|stor|disk" } |
    Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, Message |
    Export-Csv (Join-Path $outDir "system-storage-events-filtered.csv") -NoTypeInformation -Encoding UTF8

if (Get-WinEvent -ListLog "Microsoft-Windows-Defrag/Operational" -ErrorAction SilentlyContinue) {
    Get-WinEvent -LogName "Microsoft-Windows-Defrag/Operational" -MaxEvents 500 |
        Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, Message |
        Export-Csv (Join-Path $outDir "defrag-operational-events.csv") -NoTypeInformation -Encoding UTF8
} else {
    "Defrag Operational log not found." | Out-File (Join-Path $outDir "defrag-operational-events.txt") -Encoding UTF8
}

$zip = Join-Path $OutputDir "storage-snapshot-$stamp.zip"
Compress-Archive -Path $outDir -DestinationPath $zip -Force

Write-Host "Storage snapshot completed."
Write-Host "Output: $zip"
