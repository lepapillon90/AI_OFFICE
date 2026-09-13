[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('install', 'enable', 'disable', 'status', 'uninstall')]
    [string]$Action
)

$ErrorActionPreference = 'Stop'
$taskName = 'Codex Autonomous Loop'
$workspace = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $PSScriptRoot 'runner.ps1'
$powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

switch ($Action) {
    'install' {
        $taskAction = New-ScheduledTaskAction -Execute $powershell -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runner`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $settings = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Days 0)
        Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $trigger -Settings $settings -Description 'Runs the Codex autonomous development loop after login.' -Force | Out-Null
        Disable-ScheduledTask -TaskName $taskName | Out-Null
        Write-Output "Installed and disabled: $taskName"
    }
    'enable' { Enable-ScheduledTask -TaskName $taskName | Out-Null; Write-Output "Enabled: $taskName" }
    'disable' {
        Disable-ScheduledTask -TaskName $taskName | Out-Null
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Write-Output "Disabled: $taskName"
    }
    'status' {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($null -eq $task) { Write-Output "Not installed: $taskName"; break }
        $task | Select-Object TaskName, State | Format-List
    }
    'uninstall' { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false; Write-Output "Removed: $taskName" }
}
