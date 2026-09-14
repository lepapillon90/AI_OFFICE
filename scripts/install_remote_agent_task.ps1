<#
.SYNOPSIS
  Registers a Windows Scheduled Task that starts docs/PHASE8_REMOTE_AGENT.md's
  local agent (bin/remote_agent.dart) automatically when this computer's user
  logs in, and restarts it if it crashes.

.DESCRIPTION
  Runs `dart run bin\remote_agent.dart` with no arguments — the agent reads
  its company id / service key / agent key from bin\remote_agent.config.json
  (see bin\remote_agent.config.example.json for the shape), so nothing
  secret ever needs to be stored in the scheduled task's own settings.

  No administrator rights needed: this registers a per-user "at log on"
  task, not a system-boot service.

.EXAMPLE
  # From this project's root (or anywhere — the script locates the repo
  # itself via $PSScriptRoot):
  powershell -ExecutionPolicy Bypass -File scripts\install_remote_agent_task.ps1
#>

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot 'bin\remote_agent.config.json'

if (-not (Test-Path $configPath)) {
    Write-Host "설정 파일이 없습니다: $configPath" -ForegroundColor Yellow
    Write-Host "bin\remote_agent.config.example.json을 복사해 bin\remote_agent.config.json으로 만들고, 실제 값을 채워주세요." -ForegroundColor Yellow
    exit 1
}

$dartCommand = Get-Command dart -ErrorAction SilentlyContinue
if (-not $dartCommand) {
    Write-Host "dart 명령을 찾을 수 없습니다 — Flutter/Dart SDK가 PATH에 있는지 확인해주세요." -ForegroundColor Red
    exit 1
}

$taskName = 'AI Office Remote Agent'

$action = New-ScheduledTaskAction `
    -Execute $dartCommand.Source `
    -Argument 'run bin\remote_agent.dart' `
    -WorkingDirectory $repoRoot

$trigger = New-ScheduledTaskTrigger -AtLogOn

# Unlimited execution time (the agent runs forever by design) and a
# generous auto-restart policy so a transient crash (network blip, etc.)
# doesn't leave the computer silently unattended.
$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description 'AI Office 원격 명령 에이전트 — docs/PHASE8_REMOTE_AGENT.md' `
    -Force | Out-Null

Write-Host "등록 완료: '$taskName' — 다음 로그인부터 자동 시작됩니다." -ForegroundColor Green
Write-Host "지금 바로 시작하려면: Start-ScheduledTask -TaskName '$taskName'" -ForegroundColor Green
Write-Host "제거하려면: scripts\uninstall_remote_agent_task.ps1" -ForegroundColor Green
