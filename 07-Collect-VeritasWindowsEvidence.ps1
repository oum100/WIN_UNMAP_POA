<#
07-Collect-VeritasWindowsEvidence.ps1
Collects Veritas / InfoScale for Windows evidence.
#>

param(
    [string]$OutputDir = "C:\Temp\TrimTest\Veritas"
)

$ErrorActionPreference = "Continue"

if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$out = Join-Path $OutputDir "veritas-windows-$stamp"
New-Item -ItemType Directory -Path $out -Force | Out-Null

function Run-Cmd {
    param(
        [string]$Name,
        [string]$Command
    )

    $file = Join-Path $out "$Name.txt"
    "===== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') :: $Command =====" |
        Out-File $file -Encoding UTF8

    cmd.exe /c $Command 2>&1 |
        Out-File $file -Append -Encoding UTF8

    "ExitCode: $LASTEXITCODE" | Out-File $file -Append -Encoding UTF8
}

"Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')" | Out-File (Join-Path $out "timestamp.txt") -Encoding UTF8
hostname | Out-File (Join-Path $out "hostname.txt") -Encoding UTF8

Get-CimInstance Win32_OperatingSystem |
    Select-Object Caption, Version, BuildNumber, OSArchitecture, LastBootUpTime |
    Format-List |
    Out-File (Join-Path $out "windows-os.txt") -Encoding UTF8

Get-Disk |
    Format-Table Number, FriendlyName, SerialNumber, BusType, OperationalStatus, HealthStatus, Size -AutoSize |
    Out-File (Join-Path $out "windows-disks.txt") -Encoding UTF8

Get-Volume |
    Format-Table DriveLetter, FileSystemLabel, FileSystem, HealthStatus, SizeRemaining, Size -AutoSize |
    Out-File (Join-Path $out "windows-volumes.txt") -Encoding UTF8

fsutil behavior query DisableDeleteNotify 2>&1 |
    Out-File (Join-Path $out "fsutil-disabledeletenotify.txt") -Encoding UTF8

Run-Cmd "vxprint" "vxprint -ht"
Run-Cmd "vxdisk-list" "vxdisk list"
Run-Cmd "vxassist-list" "vxassist list"
Run-Cmd "vxvol-list" "vxvol list"
Run-Cmd "vxdg-list" "vxdg list"
Run-Cmd "vxstat" "vxstat"
Run-Cmd "vxstat-5samples" "vxstat -i 1 -c 5"
Run-Cmd "vxdmpadm-getsubpaths" "vxdmpadm getsubpaths"
Run-Cmd "vxdmpadm-listctlr" "vxdmpadm listctlr all"
Run-Cmd "hastatus-sum" "hastatus -sum"

$ev = Join-Path $out "eventlogs"
New-Item -ItemType Directory -Path $ev -Force | Out-Null

wevtutil epl System (Join-Path $ev "System.evtx")
wevtutil epl Application (Join-Path $ev "Application.evtx")

Get-WinEvent -LogName System -MaxEvents 3000 |
    Where-Object { $_.ProviderName -match "Veritas|Vx|VRTS|vxio|vxvm|disk|stor|mpio|partmgr|volmgr|ntfs|refs|vmware|pvscsi" } |
    Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, Message |
    Export-Csv (Join-Path $ev "System-storage-veritas-filtered.csv") -NoTypeInformation -Encoding UTF8

$zip = Join-Path $OutputDir "veritas-windows-$stamp.zip"
Compress-Archive -Path $out -DestinationPath $zip -Force

Write-Host "Veritas evidence completed."
Write-Host "Output: $zip"
