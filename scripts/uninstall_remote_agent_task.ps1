<#
.SYNOPSIS
  Removes a scheduled task created by install_remote_agent_task.ps1. Does
  not stop an already-running agent process — close that window (or
  Stop-ScheduledTask) separately.

.PARAMETER TaskName
  Defaults to "AI Office Remote Agent" (the default instance). Pass the
  same -TaskName you gave install_remote_agent_task.ps1 to remove a
  second/named instance instead.
#>

param(
    [string]$TaskName = 'AI Office Remote Agent'
)

$ErrorActionPreference = 'Stop'

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $existing) {
    Write-Host "'$TaskName' 작업이 없습니다 — 이미 제거됐거나 등록된 적이 없습니다." -ForegroundColor Yellow
    exit 0
}

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
Write-Host "제거 완료: '$TaskName'" -ForegroundColor Green
