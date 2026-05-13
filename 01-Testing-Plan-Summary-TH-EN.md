# Testing Plan Summary / สรุปแผนการทดสอบสำหรับลูกค้า  
## ScheduledDefrag / Storage Optimizer Trigger / Cross-Layer Thin-Reclaimed RCA  
#### Windows Server 2022, InfoScale for Windows, VMware, HPE Alletra 9060

---

## Executive Summary / สรุปสำหรับผู้บริหาร

### English

The customer observed a hang/delay of approximately 20 minutes after deleting a large SQL backup file of about 1.2 TB in a Windows Server 2022 VM using Veritas / InfoScale for Windows with HPE Alletra 9060 storage.

The current field observation is that the issue no longer occurs when `DisableDeleteNotify=1`. However, because the customer requires `DisableDeleteNotify=0`, the purpose of this plan is to validate whether **ScheduledDefrag / Storage Optimizer / ReTrim** is the trigger for delayed **UNMAP(TRIM)** activity and to determine where the hang/delay occurs across the infrastructure stack.

The main customer-facing approach is:

- Reproduce the issue in a baseline condition
- Isolate whether disabling ScheduledDefrag changes the behavior
- Validate the current workaround as a comparison point
- Collect evidence across Windows, Veritas, VMware, and HPE Alletra 9060 so that the next RCA action can focus on the correct layer

ลูกค้าพบอาการ hang/delay ประมาณ 20 นาที หลังลบไฟล์ SQL backup ขนาดประมาณ 1.2 TB ภายใน VM ที่เป็น Windows Server 2022 ใช้งานร่วมกับ Veritas / InfoScale for Windows และ HPE Alletra 9060 storage

จาก field observation ปัจจุบัน พบว่าอาการดังกล่าวไม่เกิดเมื่อกำหนด `DisableDeleteNotify=1` แต่เนื่องจากลูกค้าต้องการใช้งานด้วย `DisableDeleteNotify=0` แผนนี้จึงมีเป้าหมายเพื่อพิสูจน์ว่า **ScheduledDefrag / Storage Optimizer / ReTrim** เป็น trigger ของ delayed **UNMAP(TRIM)** หรือไม่ และเพื่อระบุว่าอาการ hang/delay เกิดที่ layer ใดใน infrastructure stack

แนวทางหลักที่ใช้ในการสื่อสารกับลูกค้าคือ:

- ทำ baseline เพื่อ reproduce อาการ
- isolate ว่าการปิด ScheduledDefrag เปลี่ยนพฤติกรรมหรือไม่
- validate workaround ปัจจุบันในฐานะ comparison point
- เก็บหลักฐานจาก Windows, Veritas, VMware และ HPE Alletra 9060 เพื่อให้ next RCA action ลงลึกใน layer ที่ถูกต้อง

---

## 02 Purpose and Objectives / วัตถุประสงค์และเป้าหมาย

### English

This testing plan is designed to validate whether **Windows ScheduledDefrag / Storage Optimizer / ReTrim** is the trigger for delayed **UNMAP(TRIM)** activity after large SQL backup file deletion, and to identify where the observed hang/delay occurs across the infrastructure stack.

The main objectives are:

- Validate whether **ScheduledDefrag / Storage Optimizer / ReTrim** triggers UNMAP(TRIM) activity following large file deletion
- Isolate where the observed hang/delay occurs or propagates across the stack:

```text
Windows Server 2022 guest OS
Veritas / InfoScale for Windows / vxio
VMware virtual disk / datastore
HPE Alletra 9060 backend storage
```

- Produce a structured evidence set that supports the next RCA action on the correct layer
- Confirm whether the current workaround changes the observed behavior, while keeping `DisableDeleteNotify=0` as the main customer requirement for trigger isolation

แผนการทดสอบนี้มีวัตถุประสงค์เพื่อพิสูจน์ว่า **Windows ScheduledDefrag / Storage Optimizer / ReTrim** เป็น trigger ของ delayed **UNMAP(TRIM)** หลังลบไฟล์ SQL backup ขนาดใหญ่หรือไม่ และเพื่อหาว่าอาการ hang/delay เกิดที่ layer ใดใน infrastructure stack

เป้าหมายหลักของแผนมีดังนี้:

- พิสูจน์ว่า **ScheduledDefrag / Storage Optimizer / ReTrim** เป็น trigger ของ UNMAP(TRIM) หลังการลบไฟล์ขนาดใหญ่หรือไม่
- แยกให้ได้ว่าอาการ hang/delay เกิดขึ้นหรือ propagate ที่ layer ใด:

```text
Windows Server 2022 guest OS
Veritas / InfoScale for Windows / vxio
VMware virtual disk / datastore
HPE Alletra 9060 backend storage
```

- สร้างชุดหลักฐานที่ช่วยชี้ว่า next RCA action ควรลงลึกที่ layer ใด
- ยืนยันว่า workaround ปัจจุบันมีผลต่อพฤติกรรมที่พบอย่างไร โดยยังคง `DisableDeleteNotify=0` เป็น customer requirement หลักสำหรับการ isolate trigger

---

## 03 Current Working Hypothesis / สมมติฐานการทดสอบปัจจุบัน

### English

The current working hypothesis is that the customer-visible hang/delay may be associated with **Storage Optimizer / ReTrim-driven UNMAP activity** after large file deletion, rather than with the delete action alone.  
This plan is intentionally designed to validate or disprove that hypothesis with cross-layer evidence.

สมมติฐานการทดสอบปัจจุบันคือ อาการ hang/delay ที่ลูกค้าพบอาจสัมพันธ์กับ **Storage Optimizer / ReTrim-driven UNMAP activity** หลังลบไฟล์ขนาดใหญ่ มากกว่าจะเกิดจากคำสั่งลบไฟล์เพียงอย่างเดียว  
ดังนั้นแผนนี้จึงถูกออกแบบมาเพื่อพิสูจน์หรือหักล้างสมมติฐานดังกล่าวด้วยหลักฐานจากหลาย layer

---

## 04 Scope / ขอบเขต

### In Scope

```text
Windows Server 2022
Veritas / InfoScale for Windows
Windows ScheduledDefrag / Storage Optimizer / ReTrim
Windows disk latency / queue length
Defrag Operational Event Log
VMware VM disk and datastore latency
HPE Alletra 9060 VLUN / VV / port latency
Large SQL backup deletion workflow
```

### Out of Scope

```text
Permanent production tuning
Firmware upgrade
SQL Server performance tuning
Source code analysis
Long-term monitoring setup
```

---

## 05 Tools Used / เครื่องมือที่ใช้

| Layer | Tool / Method | Purpose |
|---|---|---|
| Windows Server 2022 | PowerShell collectors | Timeline, disk counters, defrag.exe, fsutil state |
| Windows Performance | PerfMon BLG / logman | Native Windows performance evidence |
| Windows Events | Event Viewer / Get-WinEvent | Defrag, System, Disk, StorPort, MPIO, PVSCSI events |
| Veritas / InfoScale | vxprint, vxstat, vxdisk, vxdmpadm, hastatus | VxVM/DMP/path/volume state |
| VMware | VMware PowerCLI / Get-Stat | VM disk and datastore latency |
| HPE Alletra 9060 | SSH CLI: `statvlun`, `srstatvlun`, `statvv`, `statport` | Backend storage latency and service stats |

### Mandatory collection

VMware and HPE Alletra 9060 are **mandatory** because Objective 2 is to identify where the hang/delay occurs.

```text
Without VMware latency, datastore/virtual layer cannot be confirmed.
Without HPE Alletra 9060 latency, backend storage layer cannot be confirmed.
```

---

## 06 Prerequisites / สิ่งที่ต้องเตรียมก่อนวันทดสอบ

### Customer preparation required

The following items should be prepared before the test window starts:

```text
Target SQL backup file for deletion
Confirmed file recreation/copy-back method for each next scenario
Windows admin access
VMware PowerCLI access
HPE Alletra 9060 management / SSH access
Agreed test window long enough for A/B/C execution
```

### Test file requirement / ข้อกำหนดของไฟล์ทดสอบ

| Item | Requirement |
|---|---|
| File type | Large SQL backup file, for example `.bak` |
| File size | Approximately 1.2 TB or equivalent agreed test size |
| File path | Full path must be confirmed before test start |
| Volume | Drive letter / target volume must be confirmed |
| Safety | Customer must confirm the file can be deleted safely |
| Reuse across scenarios | Same file or an equivalent file should be used for A/B/C consistency |
| Recreate plan | File must be recreated or copied back before the next scenario |
| Owner | Customer/team owner should be identified for file preparation and restore |

### Why this prerequisite matters / เหตุผลที่ต้องเตรียมล่วงหน้า

```text
Each scenario consumes the target file by deleting it.
Without a confirmed recreate/copy-back plan, Scenario B and Scenario C cannot be executed consistently.
If the file size or location differs between scenarios, the comparison value of the test results is reduced.
```

---

## 07 Main Test Scenarios / Scenario หลักของการทดสอบ

Important note:

```text
The main customer test plan uses Scenario A/B/C only.
Manual Optimize-Volume / ReTrim is NOT part of the main A/B/C execution flow.
If extra confirmation is needed, use Appendix A as an optional test after the main scenarios are completed.
```

### Scenario A — Reproduce / Baseline

Purpose:

```text
Confirm issue can be reproduced under TRIM-enabled behavior.
```

Configuration:

| Setting | Value |
|---|---|
| DisableDeleteNotify | 0 |
| ScheduledDefrag | Enabled / current production behavior |
| VMware collection | Mandatory |
| HPE Alletra 9060 collection | Mandatory |

Expected:

```text
If hang/delay occurs, this is the known-bad baseline evidence set.
```

---

### Scenario B — Trigger Isolation: ScheduledDefrag Disabled

Purpose:

```text
Determine whether ScheduledDefrag / Storage Optimizer / ReTrim is the trigger.
```

Configuration:

| Setting | Value |
|---|---|
| DisableDeleteNotify | 0 |
| ScheduledDefrag | Disabled |
| defrag.exe | Not running before deletion |
| VMware collection | Mandatory |
| HPE Alletra 9060 collection | Mandatory |

Expected:

```text
If no hang/slowness occurs for 60+ minutes after deletion,
ScheduledDefrag / Storage Optimizer / ReTrim is strongly supported as the trigger.
```

---

### Scenario C — Mitigation Validation / Known-Good Control

Purpose:

```text
Validate customer mitigation effectiveness.
```

Configuration:

| Setting | Value |
|---|---|
| DisableDeleteNotify | 1 |
| ScheduledDefrag | Disabled |
| defrag.exe | Not running before deletion |
| VMware collection | Mandatory |
| HPE Alletra 9060 collection | Mandatory |

Expected:

```text
No hang/slowness should occur.
This confirms mitigation effectiveness but does not by itself prove ScheduledDefrag is the only trigger.
```

---

## 08 Estimated Duration / เวลาที่ใช้โดยประมาณ

### Per Scenario

| Phase | Activity | Estimated Time |
|---|---|---:|
| 1 | Configure scenario state | 5 mins |
| 2 | Baseline Windows / Veritas snapshot | 10 mins |
| 3 | Start Windows / VMware / HPE collectors | 10-15 mins |
| 4 | Mark before delete + delete file + mark after delete | 5-10 mins |
| 5 | Observation window | 60 mins minimum |
| 6 | Stop collectors and export evidence | 10-15 mins |
| 7 | Quick evidence sanity check | 10 mins |

Estimated per scenario:

```text
~1.5 to 2 hours
```

### Full A/B/C run

```text
~4.5 to 6 hours total
```

Note:

```text
Each scenario requires a large SQL backup file to exist before deletion.
If the same file is used, it must be recreated/copied again before the next scenario.
Customer preparation time for recreating/copying the file should be included in the test schedule.
```

---

## 09 Step-by-Step Runbook / ขั้นตอนการทำงาน

The detailed operator runbook is in:

```text
02-Step-by-Step-Operator-Runbook-TH-EN.md
```

Important structure:

```text
Steps 1-3 = Common preparation
Steps 4-16 = Standard execution block for ONE scenario
Repeat Steps 4-16 for Scenario A, Scenario B, and Scenario C
Use a separate OutputDir for each scenario
```

Recommended OutputDir:

```text
Scenario A: C:\Temp\TrimTest-A-Baseline
Scenario B: C:\Temp\TrimTest-B-DefragDisabled
Scenario C: C:\Temp\TrimTest-C-Mitigation
```

---

## 10 Expected Results / ผลที่คาดหวัง

| Scenario | Expected Result | Meaning |
|---|---|---|
| A | Issue reproduces | Baseline/known-bad confirmed |
| B | No hang/slowness | ScheduledDefrag/ReTrim likely trigger |
| B | hang/slowness still occurs | Trigger may not be ScheduledDefrag alone; deeper path/RCA needed |
| C | No hang/slowness | Mitigation effective |
| C | hang/slowness still occurs | Issue not fully dependent on TRIM/Optimizer path |

---

## 11 Interpretation Logic / วิเคราะห์ผลทดสอบ

Use the matrix below during result review. Mark `Yes` or `No` based on the evidence collected in each scenario.

ใช้ตารางด้านล่างระหว่างการ review ผลทดสอบ โดยทำเครื่องหมาย `Yes` หรือ `No` ตามหลักฐานที่เก็บได้ในแต่ละ scenario

| Area | Checkpoint / Expected Evidence | Yes | No | Meaning if Yes |
|---|---|---|---|---|
| Trigger | Scenario A: issue is reproduced under baseline condition | `☐` | `☐` | Baseline issue confirmed |
| Trigger | Scenario B: with `DisableDeleteNotify=0` and ScheduledDefrag = disabled, issue is not reproduced | `☐` | `☐` | ScheduledDefrag / Storage Optimizer / ReTrim is likely trigger |
| Trigger | Scenario C: with `DisableDeleteNotify=1` and ScheduledDefrag = disabled, issue is not reproduced | `☐` | `☐` | Workaround behavior confirmed |
| Layer | Windows evidence shows latency spike at issue time | `☐` | `☐` | Windows / filesystem / Veritas layer involved |
| Layer | VMware evidence shows latency spike at issue time | `☐` | `☐` | VMware layer involved |
| Layer | HPE Alletra 9060 evidence shows latency spike at issue time | `☐` | `☐` | Backend storage / reclaim layer involved |
| Layer | Windows, VMware, and HPE Alletra 9060 show spikes at the same time | `☐` | `☐` | Backend propagation or shared-path stall is possible |
| Optimizer path | Optimizer activity is still observed while ScheduledDefrag = disabled | `☐` | `☐` | Another optimizer trigger may exist; check `defrag.exe`, Defrag Operational events, `Optimize-Volume`, policy, third-party tools, or manual trigger |

---

## 12 Deliverables / หลักฐานที่ต้องส่งมอบ

For each scenario, deliver a separate evidence folder.

```text
Scenario A: C:\Temp\TrimTest-A-Baseline
Scenario B: C:\Temp\TrimTest-B-DefragDisabled
Scenario C: C:\Temp\TrimTest-C-Mitigation
```

Each evidence folder should include:

### Windows

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
storage-snapshot-*.zip
```

### Veritas / InfoScale

```text
veritas-windows-*.zip
```

### VMware

```text
vmware-vm-disk-latency.csv
vmware-datastore-latency.csv
```

### HPE Alletra 9060

```text
3par-latency-*.log
3par-commands-*.txt
```

### Final customer summary

```text
Scenario comparison table
Trigger conclusion
Most likely hang/delay layer
Recommended next action
```

---

## Appendix A - Optional Manual Optimize-Volume / ReTrim Confirmation Test

Purpose:

```text
Use only if the customer wants additional confirmation after Scenario A/B/C.
This optional test helps determine whether a manually initiated optimizer/retrim pass can reproduce the same delay pattern.
```

Key positioning:

```text
This is not part of the main customer A/B/C test flow.
This appendix is only for additional confirmation when the customer requests deeper validation.
```

Suggested setup:

| Setting | Value |
|---|---|
| DisableDeleteNotify | 0 |
| ScheduledDefrag | Disabled |
| Manual Optimize-Volume | Run only after file deletion and evidence collectors are already running |
| OutputDir | Separate optional folder, for example C:\Temp\TrimTest-D-ManualRetrim |

Interpretation:

```text
If the environment stays stable after deletion but slows/hangs only after manual Optimize-Volume/ReTrim,
that would further support the hypothesis that the optimizer-driven reclaim path is the trigger.
```

---

## Appendix B - Tuning Considerations (Not Part of Main Test Execution)

The following items are intentionally excluded from the main A/B/C scenarios and should be discussed only after the trigger and affected layer are validated:

```text
vol_tp_reclaim_limit
vol_tp_reclaim_idle_delay
```

Reason:

```text
Tuning may change behavior, pacing, or visibility of the issue.
Applying tuning before trigger isolation would weaken the evidentiary value of the RCA test.
```
