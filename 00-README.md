# POA Customer Review Final v5

This package contains the customer-facing testing-plan set for hang/delay RCA during thin reclamation after large-file deletion.

Key correction in v5:

- Step 5-17 are now clearly defined as the **standard execution block**.
- The standard execution block must be repeated for each scenario.
- Each scenario uses a separate OutputDir to prevent evidence mixing.
- VMware and HPE Alletra 9060 collection are mandatory.
- DisableDeleteNotify=1 is only used for Scenario C / mitigation validation, not for main trigger isolation.
- Main scenarios are A/B/C only; manual `Optimize-Volume` confirmation is kept as an optional appendix test.
- Parameter tuning such as `vol_tp_reclaim_limit` and `vol_tp_reclaim_idle_delay` is not part of the main test flow and is documented separately as an appendix note.

Document roles:

- `01-Testing-Plan-Summary-TH-EN.md` = executive / customer-facing summary
- `02-Step-by-Step-Operator-Runbook-TH-EN.md` = technical operator runbook

Files:

```text
00-README.md
01-Testing-Plan-Summary-TH-EN.md
02-Step-by-Step-Operator-Runbook-TH-EN.md
03-TrimLatencyTrace.ps1
04-Start-PerfMonBLG.ps1
05-Stop-PerfMonBLG.ps1
06-Collect-StorageEventSnapshot.ps1
07-Collect-VeritasWindowsEvidence.ps1
08-Export-WindowsTrimEvidence.ps1
09-Collect-VMwareLatency.ps1
10-Collect-3PARLatency.ps1
11-Validate-TrimTestPrereqs.ps1
.vscode/settings.json
.vscode/tasks.json
.vscode/extensions.json
.vscode/PSScriptAnalyzerSettings.psd1
tests/TrimToolkit.Smoke.Tests.ps1
```

VS Code helpers:

- Install the recommended extensions from `.vscode/extensions.json`
- On macOS, use `pwsh` (PowerShell 7) with `PowerShell: Run Script Analyzer`, `PowerShell: Run Pester Smoke Tests`, or `PowerShell: macOS Static Validation Bundle`
- On Windows, run `PowerShell: Validate Local Prereqs (Windows only)` before test day
- On Windows, run `PowerShell: Validate Local Prereqs + VMware + Alletra (Windows only)` on the appropriate collector/admin host
- Static linting and parser-based smoke tests can be run from macOS, but the main collector scripts still require Windows for real execution
