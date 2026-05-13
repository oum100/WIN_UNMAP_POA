<#
04-Start-PerfMonBLG.ps1
Starts native Windows PerfMon BLG collector.
#>

param(
    [string]$OutputDir = "C:\Temp\TrimTest",
    [int]$SampleInterval = 5,
    [string]$CollectorName = "TrimPoaDiskLatency"
)

if ($SampleInterval -lt 1) {
    throw "SampleInterval must be greater than or equal to 1 second."
}

if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$counterFile = Join-Path $OutputDir "perfmon-counters.txt"
$blgFile = Join-Path $OutputDir "disk_latency_perfmon.blg"
$sampleIntervalFormatted = [TimeSpan]::FromSeconds($SampleInterval).ToString("hh\:mm\:ss")

@(
"\PhysicalDisk(*)\Avg. Disk sec/Read",
"\PhysicalDisk(*)\Avg. Disk sec/Write",
"\PhysicalDisk(*)\Avg. Disk sec/Transfer",
"\PhysicalDisk(*)\Disk Reads/sec",
"\PhysicalDisk(*)\Disk Writes/sec",
"\PhysicalDisk(*)\Disk Transfers/sec",
"\PhysicalDisk(*)\Current Disk Queue Length",
"\PhysicalDisk(*)\Avg. Disk Queue Length",
"\PhysicalDisk(*)\Split IO/Sec",
"\LogicalDisk(*)\Avg. Disk sec/Read",
"\LogicalDisk(*)\Avg. Disk sec/Write",
"\LogicalDisk(*)\Avg. Disk sec/Transfer",
"\LogicalDisk(*)\Current Disk Queue Length",
"\Processor(_Total)\% Processor Time",
"\Processor(_Total)\% Privileged Time",
"\System\Processor Queue Length",
"\Memory\Available MBytes"
) | Out-File $counterFile -Encoding ASCII

logman stop $CollectorName -ets 2>$null | Out-Null
logman delete $CollectorName 2>$null | Out-Null

logman create counter $CollectorName `
    -cf $counterFile `
    -si $sampleIntervalFormatted `
    -f bincirc `
    -max 1024 `
    -o $blgFile | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "logman create counter failed for collector '$CollectorName'."
}

logman start $CollectorName -ets | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "logman start failed for collector '$CollectorName'."
}

Write-Host "PerfMon BLG collector started."
Write-Host "CollectorName: $CollectorName"
Write-Host "Output: $blgFile"
