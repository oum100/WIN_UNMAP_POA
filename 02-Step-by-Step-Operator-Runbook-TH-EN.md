# 02 - Technical Operator Runbook / ขั้นตอนปฏิบัติทางเทคนิคสำหรับ Admin  
# ScheduledDefrag Trigger Validation + Cross-Layer Hang/Delay RCA  
# Windows Server 2022 + Veritas + VMware + HPE Alletra 9060

---

## Important Concept / แนวคิดสำคัญ

### English

Steps 4-16 are the **standard execution block for one scenario**.

You must repeat Steps 4-16 for each scenario:

```text
Scenario A: C:\Temp\TrimTest-A-Baseline
Scenario B: C:\Temp\TrimTest-B-DefragDisabled
Scenario C: C:\Temp\TrimTest-C-Mitigation
```

Each scenario must use a separate OutputDir.

Each scenario requires a large SQL backup file to exist before deletion.  
If the same file is used, recreate or copy the file again before starting the next scenario.

Main-plan note:

```text
Scenario A/B/C do not include a manual Optimize-Volume / ReTrim command.
If manual optimizer confirmation is needed, run it only as an optional appendix test after the main A/B/C plan is complete.
```

### ภาษาไทย

Step 4-16 คือ **standard execution block สำหรับ 1 scenario**

ต้องทำซ้ำ Step 4-16 สำหรับแต่ละ scenario:

```text
Scenario A: C:\Temp\TrimTest-A-Baseline
Scenario B: C:\Temp\TrimTest-B-DefragDisabled
Scenario C: C:\Temp\TrimTest-C-Mitigation
```

แต่ละ scenario ต้องใช้ OutputDir แยกกัน เพื่อไม่ให้ evidence ปนกัน

แต่ละ scenario ต้องมีไฟล์ SQL backup ขนาดใหญ่ให้ลบก่อนเริ่มทดสอบ  
ถ้าใช้ไฟล์เดิม ต้อง copy/recreate ไฟล์กลับมาก่อนเริ่ม scenario ถัดไป

---

# Common Preparation / เตรียมก่อนเริ่มทดสอบ

## Step 1 - Prepare Script Folder / เตรียม Folder สำหรับ Script

Where:

```text
Windows Server 2022 PowerShell - Run as Administrator
```

Estimated:

```text
5 minutes
```

Run:

```powershell
mkdir C:\Temp\TrimTest-Scripts
cd C:\Temp\TrimTest-Scripts
```

Copy these scripts into `C:\Temp\TrimTest-Scripts`:

```text
03-TrimLatencyTrace.ps1
04-Start-PerfMonBLG.ps1
05-Stop-PerfMonBLG.ps1
06-Collect-StorageEventSnapshot.ps1
07-Collect-VeritasWindowsEvidence.ps1
08-Export-WindowsTrimEvidence.ps1
```

Expected:

```text
Scripts are available in C:\Temp\TrimTest-Scripts
```

---

## Step 2 - Prepare External Collector Workstations / เตรียมเครื่องมือภายนอก

Where:

```text
VMware PowerCLI workstation
HPE Alletra 9060 management workstation
```

Estimated:

```text
10 minutes
```

Run / Prepare:

```text
VMware workstation:
  09-Collect-VMwareLatency.ps1

HPE Alletra 9060 management workstation:
  10-Collect-3PARLatency.ps1
```

Expected:

```text
VMware PowerCLI access confirmed
HPE Alletra 9060 SSH access confirmed
```

---

## Step 3 - Prepare Customer Test File Prerequisites / เตรียมความพร้อมของไฟล์ทดสอบจากฝั่งลูกค้า

Where:

```text
Customer application / backup owner
Windows Server 2022
```

Estimated:

```text
This should be completed before the test window starts.
```

Confirm:

| Item | What must be confirmed |
|---|---|
| File path | Full path of the large SQL backup file |
| File size | Target size, ideally around 1.2 TB or agreed equivalent |
| File type | Example: `.bak` |
| Target volume | Drive letter / volume that will be tested |
| Delete approval | Customer confirms the file can be safely deleted |
| Recreate method | Copy back / restore / regenerate method for next scenario |
| Recreate owner | Person/team responsible for preparing the file again |
| Recreate duration | Approximate time needed before the next scenario |

Expected:

```text
The customer-side file preparation plan is confirmed before execution day.
```

---

## Step 4 - Confirm Target File and Recreate Plan / ยืนยันไฟล์ที่จะลบ

Where:

```text
Windows Server 2022
```

Estimated:

```text
5 minutes
```

Run / Confirm:

```text
Confirm large SQL backup file path.
Confirm file can be safely deleted.
Confirm how the file will be recreated/copied for next scenario.
```

Example file path:

```text
D:\Backup\LargeSqlBackup.bak
```

Expected:

```text
Target file path confirmed.
File recreation plan confirmed.
```

---

# Scenario Configuration Matrix / ตารางตั้งค่า Scenario

Use the configuration below before running the standard execution block.

| Scenario | OutputDir | DisableDeleteNotify | ScheduledDefrag |
|---|---|---:|---|
| A - Baseline | C:\Temp\TrimTest-A-Baseline | 0 | Enabled/current |
| B - Defrag Disabled | C:\Temp\TrimTest-B-DefragDisabled | 0 | Disabled |
| C - Mitigation | C:\Temp\TrimTest-C-Mitigation | 1 | Disabled |

---

# Scenario A - Baseline / Reproduce

## Configure Scenario A

Where:

```text
Windows Server 2022 PowerShell - Run as Administrator
```

Estimated:

```text
5 minutes
```

Run:

```powershell
$OutputDir = "C:\Temp\TrimTest-A-Baseline"

fsutil behavior set DisableDeleteNotify 0
fsutil behavior query DisableDeleteNotify

Enable-ScheduledTask -TaskPath "\Microsoft\Windows\Defrag\" -TaskName "ScheduledDefrag"

Get-ScheduledTask -TaskPath "\Microsoft\Windows\Defrag\" -TaskName "ScheduledDefrag" |
Select-Object TaskName, State

Get-Process defrag -ErrorAction SilentlyContinue
```

Expected:

```text
NTFS DisableDeleteNotify = 0
ScheduledDefrag enabled/current
No unexpected defrag.exe before start
```

Then run:

```text
Step 5-17 using OutputDir = C:\Temp\TrimTest-A-Baseline
```

---

# Scenario B - Trigger Isolation / ScheduledDefrag Disabled

## Configure Scenario B

Where:

```text
Windows Server 2022 PowerShell - Run as Administrator
```

Estimated:

```text
5 minutes
```

Run:

```powershell
$OutputDir = "C:\Temp\TrimTest-B-DefragDisabled"

fsutil behavior set DisableDeleteNotify 0
fsutil behavior query DisableDeleteNotify

Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Defrag\" -TaskName "ScheduledDefrag"

Get-ScheduledTask -TaskPath "\Microsoft\Windows\Defrag\" -TaskName "ScheduledDefrag" |
Select-Object TaskName, State

Get-Process defrag -ErrorAction SilentlyContinue
```

Expected:

```text
NTFS DisableDeleteNotify = 0
ScheduledDefrag disabled
No defrag.exe running
```

Then run:

```text
Step 5-17 using OutputDir = C:\Temp\TrimTest-B-DefragDisabled
```

---

# Scenario C - Mitigation Validation / Known-Good Control

## Configure Scenario C

Where:

```text
Windows Server 2022 PowerShell - Run as Administrator
```

Estimated:

```text
5 minutes
```

Run:

```powershell
$OutputDir = "C:\Temp\TrimTest-C-Mitigation"

fsutil behavior set DisableDeleteNotify 1
fsutil behavior query DisableDeleteNotify

Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Defrag\" -TaskName "ScheduledDefrag"

Get-ScheduledTask -TaskPath "\Microsoft\Windows\Defrag\" -TaskName "ScheduledDefrag" |
Select-Object TaskName, State

Get-Process defrag -ErrorAction SilentlyContinue
```

Expected:

```text
NTFS DisableDeleteNotify = 1
ScheduledDefrag disabled
No defrag.exe running
```

Then run:

```text
Step 5-17 using OutputDir = C:\Temp\TrimTest-C-Mitigation
```

---

# Standard Execution Block / ขั้นตอนมาตรฐานสำหรับ 1 Scenario

## Step 5 - Create Scenario Output Folder / สร้าง Output Folder

Where:

```text
Windows Server 2022 PowerShell - Run as Administrator
```

Estimated:

```text
1 minute
```

Run:

```powershell
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
```

Expected:

```text
Scenario OutputDir created.
```

---

## Step 6 - Collect Pre-check Storage Snapshot / เก็บ Storage Snapshot ก่อนทดสอบ

Where:

```text
Windows Server 2022 PowerShell - Run as Administrator
```

Estimated:

```text
5 minutes
```

Run:

```powershell
cd C:\Temp\TrimTest-Scripts
.\06-Collect-StorageEventSnapshot.ps1 -OutputDir "$OutputDir\PreCheck"
```

Expected:

```text
storage-snapshot-*.zip created under <OutputDir>\PreCheck
```

---

## Step 7 - Collect Baseline Veritas Evidence / เก็บ Veritas Baseline

Where:

```text
Windows Server 2022 PowerShell - Run as Administrator
```

Estimated:

```text
10 minutes
```

Run:

```powershell
cd C:\Temp\TrimTest-Scripts
.\07-Collect-VeritasWindowsEvidence.ps1 -OutputDir "$OutputDir\Veritas"
```

Expected:

```text
veritas-windows-*.zip created under <OutputDir>\Veritas
```

---

## Step 8 - Start Windows Collectors / เริ่ม Windows Collectors

Where:

```text
Windows Server 2022 PowerShell - Run as Administrator
```

Estimated:

```text
5 minutes
```

Run:

```powershell
cd C:\Temp\TrimTest-Scripts

.\03-TrimLatencyTrace.ps1 -Action Start -OutputDir $OutputDir -SampleInterval 5

.\04-Start-PerfMonBLG.ps1 -OutputDir $OutputDir -SampleInterval 5
```

Verify:

```powershell
Get-Job
```

Expected:

```text
TrimTest-Counters        Running
TrimTest-DefragProcess   Running
TrimTest-DefragEvents    Running
TrimTest-Fsutil          Running

disk_latency_perfmon.blg created under <OutputDir>
```

---

## Step 9 - Start VMware Collector / เริ่ม VMware Collector

Where:

```text
VMware PowerCLI workstation
```

Estimated:

```text
5 minutes
```

Run:

```powershell
.\09-Collect-VMwareLatency.ps1 `
  -vCenter "vcenter.example.com" `
  -VMName "SQL-Windows-VM" `
  -DatastoreName "DATASTORE_NAME" `
  -OutputDir "<ScenarioOutputDir>\VMware" `
  -SampleInterval 20
```

Example:

```powershell
.\09-Collect-VMwareLatency.ps1 `
  -vCenter "vcenter.example.com" `
  -VMName "SQL-Windows-VM" `
  -DatastoreName "DATASTORE_NAME" `
  -OutputDir "C:\Temp\TrimTest-B-DefragDisabled\VMware" `
  -SampleInterval 20
```

Expected:

```text
vmware-vm-disk-latency.csv
vmware-datastore-latency.csv
```

Important:

```text
Keep this collector running until Step 15.
```

---

## Step 10 - Start HPE Alletra 9060 Collector / เริ่ม HPE Alletra 9060 Collector

Where:

```text
Management workstation with SSH access to HPE Alletra 9060
```

Estimated:

```text
5 minutes
```

Run:

```powershell
.\10-Collect-3PARLatency.ps1 `
  -Array "3par-array.example.com" `
  -User "monitoruser" `
  -HostFilter "SQL_HOST_NAME" `
  -OutputDir "<ScenarioOutputDir>\3PAR" `
  -SampleInterval 5
```

Example:

```powershell
.\10-Collect-3PARLatency.ps1 `
  -Array "3par-array.example.com" `
  -User "monitoruser" `
  -HostFilter "SQL_HOST_NAME" `
  -OutputDir "C:\Temp\TrimTest-B-DefragDisabled\3PAR" `
  -SampleInterval 5
```

Expected:

```text
3par-latency-*.log
3par-commands-*.txt
```

Important:

```text
Keep this collector running until Step 15.
```

---

## Step 11 - Mark Before Delete / Mark ก่อนลบไฟล์

Where:

```text
Windows Server 2022 PowerShell - Run as Administrator
```

Estimated:

```text
1 minute
```

Run:

```powershell
cd C:\Temp\TrimTest-Scripts

.\03-TrimLatencyTrace.ps1 -Action Mark -OutputDir $OutputDir -Message "Before delete SQL backup"
```

Expected:

```text
timeline_markers.csv updated.
```

---

## Step 12 - Delete Large SQL Backup File / ลบไฟล์ SQL Backup ขนาดใหญ่

Where:

```text
Windows Server 2022 PowerShell - Run as Administrator
```

Estimated:

```text
1-5 minutes
```

Run:

```powershell
Remove-Item "D:\Backup\LargeSqlBackup.bak" -Force
```

Expected:

```text
Large SQL backup file deleted.
```

Important:

```text
Replace D:\Backup\LargeSqlBackup.bak with the actual file path.
Before running the next scenario, recreate/copy this file again.
```

---

## Step 13 - Mark After Delete / Mark หลังลบไฟล์

Where:

```text
Windows Server 2022 PowerShell - Run as Administrator
```

Estimated:

```text
1 minute
```

Run:

```powershell
cd C:\Temp\TrimTest-Scripts

.\03-TrimLatencyTrace.ps1 -Action Mark -OutputDir $OutputDir -Message "After delete SQL backup"
```

Expected:

```text
timeline_markers.csv updated.
```

---

## Step 14 - Observe 60+ Minutes / Monitor อย่างน้อย 60 นาที

Where:

```text
Windows Server 2022
VMware PowerCLI workstation
HPE Alletra 9060 management workstation
```

Estimated:

```text
60 minutes minimum
```

Optional Windows status check:

```powershell
cd C:\Temp\TrimTest-Scripts

.\03-TrimLatencyTrace.ps1 -Action Status -OutputDir $OutputDir
```

Watch for:

```text
hang/slowness
defrag.exe activity
Defrag Operational events
Windows disk latency spike
Windows disk queue spike
VMware datastore latency spike
HPE Alletra 9060 latency spike
Veritas / path / disk events
```

If hang/slowness occurs:

```powershell
cd C:\Temp\TrimTest-Scripts

.\06-Collect-StorageEventSnapshot.ps1 -OutputDir "$OutputDir\DuringSpike"

.\07-Collect-VeritasWindowsEvidence.ps1 -OutputDir "$OutputDir\Veritas"
```

Expected:

```text
Observation completed with or without issue.
If issue occurs, DuringSpike evidence captured.
```

---

## Step 15 - Stop Windows Collectors / หยุด Windows Collectors

Where:

```text
Windows Server 2022 PowerShell - Run as Administrator
```

Estimated:

```text
5 minutes
```

Run:

```powershell
cd C:\Temp\TrimTest-Scripts

.\03-TrimLatencyTrace.ps1 -Action Stop -OutputDir $OutputDir

.\05-Stop-PerfMonBLG.ps1
```

Expected:

```text
Windows collector jobs stopped.
PerfMon BLG stopped.
```

---

## Step 16 - Stop VMware and HPE Alletra 9060 Collectors / หยุด VMware และ HPE Alletra 9060

Where:

```text
VMware PowerCLI workstation
HPE Alletra 9060 management workstation
```

Estimated:

```text
1 minute
```

Run:

```text
Press Ctrl+C in each collector window.
```

Expected:

```text
VMware CSV collection stopped.
HPE Alletra 9060 log collection stopped.
```

---

## Step 17 - Export Final Evidence / Export Evidence หลังจบ Scenario

Where:

```text
Windows Server 2022 PowerShell - Run as Administrator
```

Estimated:

```text
10-15 minutes
```

Run:

```powershell
cd C:\Temp\TrimTest-Scripts

.\08-Export-WindowsTrimEvidence.ps1 -OutputDir $OutputDir

.\06-Collect-StorageEventSnapshot.ps1 -OutputDir "$OutputDir\PostTest"

.\07-Collect-VeritasWindowsEvidence.ps1 -OutputDir "$OutputDir\Veritas"
```

Expected:

```text
windows-eventlogs-*.zip created
storage-snapshot-*.zip created
veritas-windows-*.zip created
```

---

# After Each Scenario / หลังจบแต่ละ Scenario

Before moving to the next scenario:

```text
1. Confirm all collectors are stopped.
2. Confirm evidence files exist in the scenario OutputDir.
3. Recreate/copy the large SQL backup file again.
4. Configure the next scenario.
5. Repeat Step 5-17.
```

---

# Final Evidence Checklist / Checklist หลักฐานสุดท้าย

After all scenarios, evidence should be separated as:

```text
C:\Temp\TrimTest-A-Baseline
C:\Temp\TrimTest-B-DefragDisabled
C:\Temp\TrimTest-C-Mitigation
```

Each folder should contain:

```text
disk_latency_counters.csv
disk_latency_perfmon.blg
defrag_process_monitor.csv
defrag_event_monitor.csv
fsutil_trim_status.csv
timeline_markers.csv
environment_snapshot.txt
summary_after_stop.txt
windows-eventlogs-*.zip
PreCheck\storage-snapshot-*.zip
PostTest\storage-snapshot-*.zip
Veritas\veritas-windows-*.zip
VMware\vmware-vm-disk-latency.csv
VMware\vmware-datastore-latency.csv
3PAR\3par-latency-*.log
3PAR\3par-commands-*.txt
```

---

# Appendix A - Optional Manual Optimize-Volume / ReTrim Confirmation

Use this appendix only if the customer requests extra confirmation after Scenario A/B/C are complete.

Purpose:

```text
Confirm whether a manually triggered optimizer/retrim pass reproduces the same delay pattern
after the file deletion has already completed.
```

Important:

```text
This appendix is optional and is not part of the main customer A/B/C plan.
Use a separate OutputDir so the optional evidence does not mix with the main evidence set.
```

Recommended OutputDir:

```text
C:\Temp\TrimTest-D-ManualRetrim
```

## Appendix A Step 1 - Configure Optional Scenario

Where:

```text
Windows Server 2022 PowerShell - Run as Administrator
```

Run:

```powershell
$OutputDir = "C:\Temp\TrimTest-D-ManualRetrim"

fsutil behavior set DisableDeleteNotify 0
fsutil behavior query DisableDeleteNotify

Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Defrag\" -TaskName "ScheduledDefrag"

Get-ScheduledTask -TaskPath "\Microsoft\Windows\Defrag\" -TaskName "ScheduledDefrag" |
Select-Object TaskName, State

Get-Process defrag -ErrorAction SilentlyContinue
```

Expected:

```text
DisableDeleteNotify = 0
ScheduledDefrag disabled
No unexpected defrag.exe before start
```

## Appendix A Step 2 - Run Standard Execution Block Through Step 12

Run Step 5-13 using:

```text
OutputDir = C:\Temp\TrimTest-D-ManualRetrim
```

Important:

```text
Do not stop the collectors after Step 13.
```

## Appendix A Step 3 - Mark Before Manual ReTrim

Where:

```text
Windows Server 2022 PowerShell - Run as Administrator
```

Run:

```powershell
cd C:\Temp\TrimTest-Scripts

.\03-TrimLatencyTrace.ps1 -Action Mark -OutputDir $OutputDir -Message "Before manual Optimize-Volume ReTrim"
```

## Appendix A Step 4 - Run Manual Optimize-Volume / ReTrim

Where:

```text
Windows Server 2022 PowerShell - Run as Administrator
```

Run:

```powershell
Optimize-Volume -DriveLetter D -ReTrim -Verbose
```

Important:

```text
Replace drive letter D with the actual target volume drive letter.
Run the command only after evidence collectors are already running.
```

## Appendix A Step 5 - Mark After Manual ReTrim

Run:

```powershell
cd C:\Temp\TrimTest-Scripts

.\03-TrimLatencyTrace.ps1 -Action Mark -OutputDir $OutputDir -Message "After manual Optimize-Volume ReTrim"
```

## Appendix A Step 6 - Observe 60+ Minutes and Complete Step 13-16

Run:

```text
Observe for at least 60 minutes, then complete Step 14-17.
```

Interpretation:

```text
If the environment remains stable after file deletion but degrades only after manual ReTrim,
that strengthens the case for an optimizer-driven reclaim trigger.
```

---

# Appendix B - Tuning Note

The following items are intentionally excluded from the main execution plan and from Appendix A execution unless separately approved for a later tuning phase:

```text
vol_tp_reclaim_limit
vol_tp_reclaim_idle_delay
```
