<#
10-Collect-3PARLatency.ps1
Mandatory HPE 3PAR collector using SSH.
Run from management workstation with ssh.exe available.
#>

param(
    [Parameter(Mandatory=$true)][string]$Array,
    [Parameter(Mandatory=$true)][string]$User,
    [string]$HostFilter = "",
    [string]$VVFilter = "",
    [string]$OutputDir = "C:\Temp\TrimTest\3PAR",
    [int]$SampleInterval = 5
)

if ($SampleInterval -lt 1) {
    throw "SampleInterval must be greater than or equal to 1 second."
}

if ($HostFilter -and $VVFilter) {
    throw "Specify either HostFilter or VVFilter, not both."
}

Get-Command ssh -ErrorAction Stop | Out-Null

if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$out = Join-Path $OutputDir "3par-latency-$ts.log"
$cmdlog = Join-Path $OutputDir "3par-commands-$ts.txt"
$sshTarget = "{0}@{1}" -f $User, $Array

function Invoke-3PAR {
    param([string]$Command)
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    "===== $stamp :: $Command =====" | Out-File $out -Append -Encoding UTF8
    $Command | Out-File $cmdlog -Append -Encoding UTF8
    ssh $sshTarget $Command 2>&1 | Out-File $out -Append -Encoding UTF8
    "ExitCode: $LASTEXITCODE" | Out-File $out -Append -Encoding UTF8
    return $LASTEXITCODE
}

if ((Invoke-3PAR "showversion") -ne 0) {
    throw "Initial SSH connectivity check to HPE Alletra 9060 failed."
}

Invoke-3PAR "showhost" | Out-Null
Invoke-3PAR "showvlun" | Out-Null
Invoke-3PAR "showvv" | Out-Null

Write-Host "Collecting HPE 3PAR latency. Press Ctrl+C to stop."

while ($true) {
    if ($HostFilter -ne "") {
        Invoke-3PAR "statvlun -host $HostFilter" | Out-Null
    } elseif ($VVFilter -ne "") {
        Invoke-3PAR "statvlun $VVFilter" | Out-Null
    } else {
        Invoke-3PAR "statvlun" | Out-Null
    }

    if ($VVFilter -ne "") {
        Invoke-3PAR "statvv $VVFilter" | Out-Null
        Invoke-3PAR "srstatvlun -vv $VVFilter" | Out-Null
    } else {
        Invoke-3PAR "statvv" | Out-Null
        Invoke-3PAR "srstatvlun" | Out-Null
    }

    Invoke-3PAR "statport" | Out-Null
    Start-Sleep -Seconds $SampleInterval
}
