<#
.SYNOPSIS
  Registers a Windows Scheduled Task that starts docs/PHASE8_REMOTE_AGENT.md's
  local agent (bin/remote_agent.dart) automatically when this computer's user
  logs in, and restarts it if it crashes.

.DESCRIPTION
  Runs `dart run bin\remote_agent.dart [--config <ConfigFile>]` with no other
  arguments — the agent reads its company id / service key / agent key from
  that config file (default bin\remote_agent.config.json; see
  bin\remote_agent.config.example.json for the shape), so nothing secret ever
  needs to be stored in the scheduled task's own settings.

  One computer can run more than one agent (e.g. the default `@서버` one
  alongside a specific employee's) by registering this twice with different
  -TaskName and -ConfigFile values — each needs its own config file (see
  .gitignore's bin/remote_agent.*.config.json pattern for the naming).

  No administrator rights needed: this registers a per-user "at log on"
  task, not a system-boot service. (Some Windows configurations still
  require an elevated PowerShell to register even a per-user task — if
  Register-ScheduledTask fails with "액세스가 거부되었습니다", re-run this
  from an elevated PowerShell.)

.PARAMETER TaskName
  Scheduled task name. Defaults to "AI Office Remote Agent". Give a second
  instance on the same computer a distinct name, e.g.
  "AI Office Remote Agent (기본 컴퓨터)".

.PARAMETER ConfigFile
  Config file name, resolved relative to bin\ (matches how the agent itself
  resolves --config). Defaults to "remote_agent.config.json". A second
  instance needs a different file, e.g. "remote_agent.default.config.json".

.EXAMPLE
  # Default instance, from this project's root:
  powershell -ExecutionPolicy Bypass -File scripts\install_remote_agent_task.ps1

.EXAMPLE
  # A second, differently-configured instance on the same computer:
  powershell -ExecutionPolicy Bypass -File scripts\install_remote_agent_task.ps1 `
    -TaskName "AI Office Remote Agent (기본 컴퓨터)" `
    -ConfigFile "remote_agent.default.config.json"
#>

param(
    [string]$TaskName = 'AI Office Remote Agent',
    [string]$ConfigFile = 'remote_agent.config.json'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot "bin\$ConfigFile"

if (-not (Test-Path $configPath)) {
    Write-Host "설정 파일이 없습니다: $configPath" -ForegroundColor Yellow
    Write-Host "bin\remote_agent.config.example.json을 복사해 위 경로로 만들고, 실제 값을 채워주세요." -ForegroundColor Yellow
    exit 1
}

$dartCommand = Get-Command dart -ErrorAction SilentlyContinue
if (-not $dartCommand) {
    Write-Host "dart 명령을 찾을 수 없습니다 — Flutter/Dart SDK가 PATH에 있는지 확인해주세요." -ForegroundColor Red
    exit 1
}

$argument = 'run bin\remote_agent.dart'
if ($ConfigFile -ne 'remote_agent.config.json') {
    $argument = "$argument --config `"$ConfigFile`""
}

$action = New-ScheduledTaskAction `
    -Execute $dartCommand.Source `
    -Argument $argument `
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
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "AI Office 원격 명령 에이전트($ConfigFile) — docs/PHASE8_REMOTE_AGENT.md" `
    -Force | Out-Null

Write-Host "등록 완료: '$TaskName' — 다음 로그인부터 자동 시작됩니다." -ForegroundColor Green
Write-Host "지금 바로 시작하려면: Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Green
Write-Host "제거하려면: scripts\uninstall_remote_agent_task.ps1 -TaskName '$TaskName'" -ForegroundColor Green
