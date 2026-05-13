<#
11-Validate-TrimTestPrereqs.ps1
Performs a lightweight prerequisite check for the Trim test toolkit.

This script does not run the collectors. It validates whether the local
machine appears ready to run the Windows, VMware, or HPE Alletra 9060
collector scripts.
#>

param(
    [switch]$CheckVMware,
    [switch]$CheckAlletra
)

$ErrorActionPreference = "Continue"

function Add-Result {
    param(
        [string]$Area,
        [string]$Item,
        [bool]$Passed,
        [string]$Details
    )

    [pscustomobject]@{
        Area    = $Area
        Item    = $Item
        Status  = if ($Passed) { "PASS" } else { "FAIL" }
        Details = $Details
    }
}

$results = @()

foreach ($cmd in @("fsutil", "logman", "wevtutil")) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    $results += Add-Result -Area "Windows" -Item $cmd -Passed ([bool]$found) -Details (
        if ($found) { $found.Source } else { "Command not found" }
    )
}

foreach ($psCmd in @("Get-Disk", "Get-Volume", "Get-WinEvent", "Get-ScheduledTask", "Get-CimInstance")) {
    $found = Get-Command $psCmd -ErrorAction SilentlyContinue
    $results += Add-Result -Area "Windows" -Item $psCmd -Passed ([bool]$found) -Details (
        if ($found) { $found.Source } else { "Cmdlet not found" }
    )
}

$defragLog = Get-WinEvent -ListLog "Microsoft-Windows-Defrag/Operational" -ErrorAction SilentlyContinue
$results += Add-Result -Area "Windows" -Item "Defrag Operational Log" -Passed ([bool]$defragLog) -Details (
    if ($defragLog) { "Log found" } else { "Log not found" }
)

foreach ($vxCmd in @("vxprint", "vxdisk", "vxassist", "vxvol", "vxdg", "vxstat", "vxdmpadm", "hastatus")) {
    $found = Get-Command $vxCmd -ErrorAction SilentlyContinue
    $results += Add-Result -Area "Veritas" -Item $vxCmd -Passed ([bool]$found) -Details (
        if ($found) { $found.Source } else { "Command not found on this host" }
    )
}

if ($CheckVMware) {
    $module = Get-Module -ListAvailable -Name VMware.PowerCLI | Select-Object -First 1
    $results += Add-Result -Area "VMware" -Item "VMware.PowerCLI module" -Passed ([bool]$module) -Details (
        if ($module) { $module.Version.ToString() } else { "Module not installed" }
    )
}

if ($CheckAlletra) {
    $ssh = Get-Command ssh -ErrorAction SilentlyContinue
    $results += Add-Result -Area "Alletra" -Item "ssh" -Passed ([bool]$ssh) -Details (
        if ($ssh) { $ssh.Source } else { "ssh not found" }
    )
}

$results | Format-Table -AutoSize

$failCount = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
Write-Host ""
Write-Host "Validation complete. Failures: $failCount"

if ($failCount -gt 0) {
    exit 1
}
