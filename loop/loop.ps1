[CmdletBinding()]
param(
    [string]$Workspace = (Split-Path -Parent $PSScriptRoot),
    [string]$CodexCommand = 'codex',
    [int]$MaxRunsOverride = -1
)

$ErrorActionPreference = 'Stop'

function Get-LoopSettings {
    param([string]$Path)
    $settings = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*([A-Z_]+)\s*=\s*"?([^"#\r\n]*)"?\s*(?:#.*)?$') {
            $settings[$matches[1]] = $matches[2].Trim()
        }
    }
    foreach ($required in 'MODEL', 'MAX_TURNS', 'WAIT_SECONDS', 'MAX_RUNS') {
        if (-not $settings.ContainsKey($required)) { throw "Missing $required in $Path" }
    }
    return $settings
}

$loopDirectory = Join-Path $Workspace 'loop'
$promptPath = Join-Path $loopDirectory 'PROMPT.md'
$stopPath = Join-Path $loopDirectory 'STOP'
$logDirectory = Join-Path $Workspace 'logs'
$settings = Get-LoopSettings -Path (Join-Path $loopDirectory 'env.sh')

if (-not (Test-Path -LiteralPath $promptPath)) { throw "Missing prompt: $promptPath" }
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null

$maxRuns = if ($MaxRunsOverride -ge 0) { $MaxRunsOverride } else { [int]$settings.MAX_RUNS }
$waitSeconds = [int]$settings.WAIT_SECONDS
$run = 0

while ($maxRuns -eq 0 -or $run -lt $maxRuns) {
    $run++
    $logPath = Join-Path $logDirectory ("{0}.log" -f (Get-Date -Format 'yyyy-MM-dd'))
    $header = "`n===== {0} | run {1} | fresh codex exec =====" -f (Get-Date -Format 'o'), $run
    Add-Content -LiteralPath $logPath -Value $header -Encoding utf8

    $instruction = "Read and follow $promptPath. This is a fresh autonomous-loop session; do not resume or continue any prior session. Keep this session to at most $($settings.MAX_TURNS) turns."
    $arguments = @('exec', '--cd', $Workspace, '--sandbox', 'workspace-write', '--approve-for-me')
    if (-not [string]::IsNullOrWhiteSpace($settings.MODEL)) { $arguments += @('--model', $settings.MODEL) }
    $arguments += $instruction

    & $CodexCommand @arguments 2>&1 | ForEach-Object {
        $_
        Add-Content -LiteralPath $logPath -Value $_ -Encoding utf8
    }
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    Add-Content -LiteralPath $logPath -Value ("===== run {0} ended with exit code {1} =====" -f $run, $exitCode) -Encoding utf8

    if (Test-Path -LiteralPath $stopPath) {
        Add-Content -LiteralPath $logPath -Value 'STOP detected after completed run; exiting cleanly.' -Encoding utf8
        break
    }
    if ($maxRuns -ne 0 -and $run -ge $maxRuns) { break }
    if ($waitSeconds -gt 0) { Start-Sleep -Seconds $waitSeconds }
}
