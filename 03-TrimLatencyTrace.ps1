<#
03-TrimLatencyTrace.ps1

Main Windows collector for POA.

Actions:
  Start  - starts background jobs
  Mark   - writes timeline marker
  Status - shows collector status
  Stop   - stops background jobs
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Start","Stop","Mark","Status")]
    [string]$Action,

    [string]$OutputDir = "C:\Temp\TrimTest",

    [int]$SampleInterval = 5,

    [string]$Message = ""
)

$ErrorActionPreference = "Continue"

if ($SampleInterval -lt 1) {
    throw "SampleInterval must be greater than or equal to 1 second."
}

function Ensure-Dir {
    param([string]$Path)
    if (!(Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-Stamp {
    return (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
}

function Remove-ExistingTrimJobs {
    $jobs = Get-Job -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "TrimTest-*" }
    if ($jobs) {
        $jobs | Stop-Job -ErrorAction SilentlyContinue
        $jobs | Wait-Job -Timeout 15 -ErrorAction SilentlyContinue | Out-Null
        $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
    }
}

function Write-Marker {
    param([string]$Text)
    Ensure-Dir $OutputDir
    $markerFile = Join-Path $OutputDir "timeline_markers.csv"
    if (!(Test-Path $markerFile)) {
        "Timestamp,Message" | Out-File $markerFile -Encoding utf8
    }
    $safe = $Text -replace '"','""'
    '"{0}","{1}"' -f (Get-Stamp), $safe | Out-File $markerFile -Append -Encoding utf8
}

function Write-EnvironmentSnapshot {
    Ensure-Dir $OutputDir
    $snapshot = Join-Path $OutputDir "environment_snapshot.txt"

    "===== Environment Snapshot =====" | Out-File $snapshot -Encoding utf8
    "Timestamp: $(Get-Stamp)" | Out-File $snapshot -Append -Encoding utf8
    hostname | Out-File $snapshot -Append -Encoding utf8

    Get-CimInstance Win32_OperatingSystem |
        Select-Object Caption, Version, BuildNumber, OSArchitecture, LastBootUpTime |
        Format-List | Out-File $snapshot -Append -Encoding utf8

    "===== DisableDeleteNotify =====" | Out-File $snapshot -Append -Encoding utf8
    fsutil behavior query DisableDeleteNotify 2>&1 | Out-File $snapshot -Append -Encoding utf8

    "===== ScheduledDefrag =====" | Out-File $snapshot -Append -Encoding utf8
    Get-ScheduledTask -TaskPath "\Microsoft\Windows\Defrag\" -TaskName "ScheduledDefrag" 2>&1 |
        Format-List * | Out-File $snapshot -Append -Encoding utf8

    "===== Volumes =====" | Out-File $snapshot -Append -Encoding utf8
    Get-Volume |
        Sort-Object DriveLetter |
        Format-Table DriveLetter, FileSystemLabel, FileSystem, DriveType, HealthStatus, SizeRemaining, Size -AutoSize |
        Out-File $snapshot -Append -Encoding utf8

    "===== Disks =====" | Out-File $snapshot -Append -Encoding utf8
    Get-Disk |
        Sort-Object Number |
        Format-Table Number, FriendlyName, SerialNumber, BusType, PartitionStyle, OperationalStatus, HealthStatus, Size -AutoSize |
        Out-File $snapshot -Append -Encoding utf8
}

function Start-Collectors {
    Ensure-Dir $OutputDir
    Remove-ExistingTrimJobs
    Write-EnvironmentSnapshot
    Write-Marker "START collection"

    $counterList = @(
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
        "\LogicalDisk(*)\Disk Reads/sec",
        "\LogicalDisk(*)\Disk Writes/sec",
        "\LogicalDisk(*)\Disk Transfers/sec",
        "\Processor(_Total)\% Processor Time",
        "\Processor(_Total)\% Privileged Time",
        "\System\Processor Queue Length",
        "\Memory\Available MBytes"
    )

    $counterScript = {
        param($OutputDir, $SampleInterval, $Counters)
        if (!(Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }
        $out = Join-Path $OutputDir "disk_latency_counters.csv"
        "Timestamp,Path,Value" | Out-File $out -Encoding utf8

        while ($true) {
            try {
                $sample = Get-Counter -Counter $Counters -ErrorAction SilentlyContinue
                if ($sample) {
                    foreach ($s in $sample.CounterSamples) {
                        '"{0}","{1}",{2}' -f `
                            ($sample.Timestamp.ToString("yyyy-MM-dd HH:mm:ss.fff")), `
                            ($s.Path -replace '"','""'), `
                            ([double]$s.CookedValue) |
                            Out-File $out -Append -Encoding utf8
                    }
                }
            } catch {
                '"{0}","ERROR:{1}",0' -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff"), ($_.Exception.Message -replace '"','""') |
                    Out-File $out -Append -Encoding utf8
            }
            Start-Sleep -Seconds $SampleInterval
        }
    }

    $processScript = {
        param($OutputDir, $SampleInterval)
        if (!(Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }
        $out = Join-Path $OutputDir "defrag_process_monitor.csv"
        "Timestamp,ProcessName,Id,CPU,StartTime,Path" | Out-File $out -Encoding utf8

        while ($true) {
            $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
            $p = Get-Process defrag -ErrorAction SilentlyContinue
            if ($p) {
                foreach ($x in $p) {
                    $start = ""
                    try { $start = $x.StartTime.ToString("yyyy-MM-dd HH:mm:ss.fff") } catch {}
                    '"{0}","{1}",{2},{3},"{4}","{5}"' -f `
                        $ts, $x.ProcessName, $x.Id, $x.CPU, $start, ($x.Path -replace '"','""') |
                        Out-File $out -Append -Encoding utf8
                }
            } else {
                '"{0}","NOT_RUNNING",,,,' -f $ts | Out-File $out -Append -Encoding utf8
            }
            Start-Sleep -Seconds $SampleInterval
        }
    }

    $eventScript = {
        param($OutputDir, $SampleInterval)
        if (!(Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }
        $out = Join-Path $OutputDir "defrag_event_monitor.csv"
        "CaptureTimestamp,EventTime,Id,ProviderName,Message" | Out-File $out -Encoding utf8
        $lastTime = (Get-Date).AddMinutes(-10)

        while ($true) {
            $captureTs = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
            try {
                $events = Get-WinEvent -FilterHashtable @{
                    LogName = "Microsoft-Windows-Defrag/Operational"
                    StartTime = $lastTime
                } -ErrorAction SilentlyContinue | Sort-Object TimeCreated

                foreach ($e in $events) {
                    if ($e.TimeCreated -gt $lastTime) {
                        '"{0}","{1}",{2},"{3}","{4}"' -f `
                            $captureTs, `
                            $e.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss.fff"), `
                            $e.Id, `
                            ($e.ProviderName -replace '"','""'), `
                            (($e.Message -replace "`r|`n"," ") -replace '"','""') |
                            Out-File $out -Append -Encoding utf8
                    }
                }

                $last = $events | Select-Object -Last 1
                if ($last) { $lastTime = $last.TimeCreated.AddMilliseconds(1) }
            } catch {
                '"{0}","","0","ERROR","{1}"' -f $captureTs, ($_.Exception.Message -replace '"','""') |
                    Out-File $out -Append -Encoding utf8
            }
            Start-Sleep -Seconds $SampleInterval
        }
    }

    $fsutilScript = {
        param($OutputDir)
        if (!(Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }
        $out = Join-Path $OutputDir "fsutil_trim_status.csv"
        "Timestamp,Output" | Out-File $out -Encoding utf8

        while ($true) {
            $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
            $result = (fsutil behavior query DisableDeleteNotify 2>&1 | Out-String).Trim() -replace "`r|`n"," | "
            '"{0}","{1}"' -f $ts, ($result -replace '"','""') | Out-File $out -Append -Encoding utf8
            Start-Sleep -Seconds 60
        }
    }

    Start-Job -Name "TrimTest-Counters" -ScriptBlock $counterScript -ArgumentList $OutputDir, $SampleInterval, $counterList | Out-Null
    Start-Job -Name "TrimTest-DefragProcess" -ScriptBlock $processScript -ArgumentList $OutputDir, $SampleInterval | Out-Null
    Start-Job -Name "TrimTest-DefragEvents" -ScriptBlock $eventScript -ArgumentList $OutputDir, $SampleInterval | Out-Null
    Start-Job -Name "TrimTest-Fsutil" -ScriptBlock $fsutilScript -ArgumentList $OutputDir | Out-Null

    Get-Job | Where-Object { $_.Name -like "TrimTest-*" } |
        Select-Object Id, Name, State |
        Format-Table -AutoSize
}

function Stop-Collectors {
    Ensure-Dir $OutputDir
    Write-Marker "STOP collection"

    $jobs = Get-Job | Where-Object { $_.Name -like "TrimTest-*" }
    if ($jobs) {
        $jobs | Stop-Job -ErrorAction SilentlyContinue
        $jobs | Wait-Job -Timeout 15 -ErrorAction SilentlyContinue | Out-Null
        $jobs | Receive-Job -ErrorAction SilentlyContinue | Out-File (Join-Path $OutputDir "job_output.txt") -Append -Encoding utf8
        $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
    }

    "Stopped at $(Get-Stamp)" | Out-File (Join-Path $OutputDir "summary_after_stop.txt") -Encoding utf8

    Get-Process defrag -ErrorAction SilentlyContinue |
        Format-List * |
        Out-File (Join-Path $OutputDir "summary_after_stop.txt") -Append -Encoding utf8

    Get-WinEvent -LogName "Microsoft-Windows-Defrag/Operational" -MaxEvents 50 2>&1 |
        Select-Object TimeCreated, Id, ProviderName, Message |
        Format-List |
        Out-File (Join-Path $OutputDir "summary_after_stop.txt") -Append -Encoding utf8
}

function Show-Status {
    Get-Job | Where-Object { $_.Name -like "TrimTest-*" } |
        Select-Object Id, Name, State |
        Format-Table -AutoSize

    Get-Process defrag -ErrorAction SilentlyContinue |
        Select-Object ProcessName, Id, CPU, StartTime, Path |
        Format-Table -AutoSize

    $markerFile = Join-Path $OutputDir "timeline_markers.csv"
    if (Test-Path $markerFile) {
        Get-Content $markerFile -Tail 10
    }
}

switch ($Action) {
    "Start"  { Start-Collectors }
    "Stop"   { Stop-Collectors }
    "Mark"   {
        if ([string]::IsNullOrWhiteSpace($Message)) { $Message = "Manual marker" }
        Write-Marker $Message
        Write-Host "Marker written: $Message"
    }
    "Status" { Show-Status }
}
