$repoRoot = Split-Path -Parent $PSScriptRoot
$isWindows = $PSVersionTable.Platform -eq 'Win32NT' -or $env:OS -eq 'Windows_NT'

$scriptFiles = @(
    '03-TrimLatencyTrace.ps1',
    '04-Start-PerfMonBLG.ps1',
    '05-Stop-PerfMonBLG.ps1',
    '06-Collect-StorageEventSnapshot.ps1',
    '07-Collect-VeritasWindowsEvidence.ps1',
    '08-Export-WindowsTrimEvidence.ps1',
    '09-Collect-VMwareLatency.ps1',
    '10-Collect-3PARLatency.ps1',
    '11-Validate-TrimTestPrereqs.ps1'
) | ForEach-Object {
    Join-Path $repoRoot $_
}

Describe 'Trim test toolkit smoke checks' {
    It 'contains all expected PowerShell scripts' {
        foreach ($scriptPath in $scriptFiles) {
            Test-Path $scriptPath | Should -BeTrue
        }
    }

    It 'parses all scripts without PowerShell syntax errors' {
        foreach ($scriptPath in $scriptFiles) {
            $tokens = $null
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)

            $errors.Count | Should -Be 0 -Because "Parser errors in $scriptPath: $($errors | ForEach-Object Message | Out-String)"
        }
    }
}

Describe 'Parameter guard rails' {
    It '03-TrimLatencyTrace rejects SampleInterval below 1' {
        {
            & (Join-Path $repoRoot '03-TrimLatencyTrace.ps1') -Action Status -SampleInterval 0
        } | Should -Throw '*SampleInterval must be greater than or equal to 1 second*'
    }

    It '04-Start-PerfMonBLG rejects SampleInterval below 1' {
        {
            & (Join-Path $repoRoot '04-Start-PerfMonBLG.ps1') -SampleInterval 0
        } | Should -Throw '*SampleInterval must be greater than or equal to 1 second*'
    }

    It '06-Collect-StorageEventSnapshot rejects MaxEvents below 1' {
        {
            & (Join-Path $repoRoot '06-Collect-StorageEventSnapshot.ps1') -MaxEvents 0
        } | Should -Throw '*MaxEvents must be greater than or equal to 1*'
    }

    It '09-Collect-VMwareLatency rejects SampleInterval below 1 before connecting to vCenter' {
        {
            & (Join-Path $repoRoot '09-Collect-VMwareLatency.ps1') -vCenter 'vc.example.local' -VMName 'vm1' -DatastoreName 'ds1' -SampleInterval 0
        } | Should -Throw '*SampleInterval must be greater than or equal to 1 second*'
    }

    It '10-Collect-3PARLatency rejects SampleInterval below 1 before trying ssh' {
        {
            & (Join-Path $repoRoot '10-Collect-3PARLatency.ps1') -Array 'array1' -User 'monitor' -SampleInterval 0
        } | Should -Throw '*SampleInterval must be greater than or equal to 1 second*'
    }

    It '10-Collect-3PARLatency rejects simultaneous HostFilter and VVFilter' {
        {
            & (Join-Path $repoRoot '10-Collect-3PARLatency.ps1') -Array 'array1' -User 'monitor' -HostFilter 'host1' -VVFilter 'vv1'
        } | Should -Throw '*Specify either HostFilter or VVFilter, not both*'
    }
}

Describe 'VS Code workspace assets' {
    It 'contains VS Code workspace settings' {
        Test-Path (Join-Path $repoRoot '.vscode/settings.json') | Should -BeTrue
        Test-Path (Join-Path $repoRoot '.vscode/tasks.json') | Should -BeTrue
        Test-Path (Join-Path $repoRoot '.vscode/extensions.json') | Should -BeTrue
    }
}

Describe 'Platform expectations' {
    It 'documents whether the test session is Windows or non-Windows' {
        $isWindows | Should -BeOfType [bool]
    }
}
