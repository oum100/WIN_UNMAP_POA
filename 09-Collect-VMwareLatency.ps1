<#
09-Collect-VMwareLatency.ps1
Mandatory VMware PowerCLI collector.
Run from VMware PowerCLI workstation.
#>

param(
    [Parameter(Mandatory=$true)][string]$vCenter,
    [Parameter(Mandatory=$true)][string]$VMName,
    [Parameter(Mandatory=$true)][string]$DatastoreName,
    [string]$OutputDir = "C:\Temp\TrimTest\VMware",
    [int]$SampleInterval = 20
)

if ($SampleInterval -lt 1) {
    throw "SampleInterval must be greater than or equal to 1 second."
}

if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Import-Module VMware.PowerCLI -ErrorAction Stop
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope Session -Confirm:$false | Out-Null

if (-not $global:DefaultVIServers) {
    $global:DefaultVIServers = @()
}

$server = $global:DefaultVIServers | Where-Object { $_.Name -ieq $vCenter } | Select-Object -First 1
if (-not $server) {
    $server = Connect-VIServer -Server $vCenter -ErrorAction Stop
}

$vm = Get-VM -Server $server -Name $VMName -ErrorAction Stop
$ds = Get-Datastore -Server $server -Name $DatastoreName -ErrorAction Stop

$vmCsv = Join-Path $OutputDir "vmware-vm-disk-latency.csv"
$dsCsv = Join-Path $OutputDir "vmware-datastore-latency.csv"
$errLog = Join-Path $OutputDir "vmware-collector-errors.log"

"CaptureTimestamp,Entity,MetricId,Instance,Timestamp,Value,Unit" | Out-File $vmCsv -Encoding UTF8
"CaptureTimestamp,Entity,MetricId,Instance,Timestamp,Value,Unit" | Out-File $dsCsv -Encoding UTF8

$vmStats = @(
    "virtualDisk.totalReadLatency.average",
    "virtualDisk.totalWriteLatency.average",
    "datastore.totalReadLatency.average",
    "datastore.totalWriteLatency.average"
)

$dsStats = @(
    "datastore.totalReadLatency.average",
    "datastore.totalWriteLatency.average",
    "datastore.read.average",
    "datastore.write.average",
    "datastore.numberReadAveraged.average",
    "datastore.numberWriteAveraged.average"
)

Write-Host "Collecting VMware latency. Press Ctrl+C to stop."

while ($true) {
    $cap = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"

    try {
        Get-Stat -Server $server -Entity $vm -Stat $vmStats -Realtime -MaxSamples 1 -ErrorAction Stop |
            ForEach-Object {
                '"{0}","{1}","{2}","{3}","{4}",{5},"{6}"' -f `
                    $cap, $_.Entity.Name, $_.MetricId, $_.Instance, $_.Timestamp.ToString("yyyy-MM-dd HH:mm:ss.fff"), $_.Value, $_.Unit |
                    Out-File $vmCsv -Append -Encoding UTF8
            }
    } catch {
        '"{0}","VM","{1}"' -f $cap, ($_.Exception.Message -replace '"','""') |
            Out-File $errLog -Append -Encoding UTF8
    }

    try {
        Get-Stat -Server $server -Entity $ds -Stat $dsStats -Realtime -MaxSamples 1 -ErrorAction Stop |
            ForEach-Object {
                '"{0}","{1}","{2}","{3}","{4}",{5},"{6}"' -f `
                    $cap, $_.Entity.Name, $_.MetricId, $_.Instance, $_.Timestamp.ToString("yyyy-MM-dd HH:mm:ss.fff"), $_.Value, $_.Unit |
                    Out-File $dsCsv -Append -Encoding UTF8
            }
    } catch {
        '"{0}","DATASTORE","{1}"' -f $cap, ($_.Exception.Message -replace '"','""') |
            Out-File $errLog -Append -Encoding UTF8
    }

    Start-Sleep -Seconds $SampleInterval
}
