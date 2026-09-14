<#
.SYNOPSIS
  Removes the "AI Office Remote Agent" scheduled task created by
  install_remote_agent_task.ps1. Does not stop an already-running agent
  process — close that window (or Stop-ScheduledTask) separately.
#>

$ErrorActionPreference = 'Stop'

$taskName = 'AI Office Remote Agent'

$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $existing) {
    Write-Host "'$taskName' 작업이 없습니다 — 이미 제거됐거나 등록된 적이 없습니다." -ForegroundColor Yellow
    exit 0
}

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
Write-Host "제거 완료: '$taskName'" -ForegroundColor Green
