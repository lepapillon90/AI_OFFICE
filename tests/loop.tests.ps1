$ErrorActionPreference = 'Stop'

function Assert-Equal {
    param([object]$Actual, [object]$Expected, [string]$Message)
    if ($Actual -ne $Expected) { throw "$Message Expected '$Expected', got '$Actual'." }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$loopScript = Join-Path $projectRoot 'loop/loop.ps1'

if (-not (Test-Path -LiteralPath $loopScript)) {
    throw 'loop/loop.ps1 is missing.'
}

$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-loop-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $sandbox | Out-Null
New-Item -ItemType Directory -Path (Join-Path $sandbox 'loop'), (Join-Path $sandbox 'logs') | Out-Null
Set-Content -LiteralPath (Join-Path $sandbox 'loop/env.sh') -Value @(
    'MODEL=',
    'MAX_TURNS=3',
    'WAIT_SECONDS=0',
    'MAX_RUNS=2'
)
Set-Content -LiteralPath (Join-Path $sandbox 'loop/PROMPT.md') -Value 'Test prompt'

$fakeCodex = Join-Path $sandbox 'fake-codex.ps1'
Set-Content -LiteralPath $fakeCodex -Value @(
    'param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)',
    "Add-Content -LiteralPath (Join-Path `$PSScriptRoot 'calls.txt') -Value ('call ' + [DateTime]::UtcNow.Ticks)",
    "'fresh session completed'"
)

try {
    & $loopScript -Workspace $sandbox -CodexCommand $fakeCodex
    Assert-Equal -Actual ((Get-Content -LiteralPath (Join-Path $sandbox 'calls.txt')).Count) -Expected 2 -Message 'The loop must create one fresh Codex process for each configured run.'
    Assert-Equal -Actual ((Get-ChildItem -LiteralPath (Join-Path $sandbox 'logs') -File).Count) -Expected 1 -Message 'The loop must create a dated log file.'
    $logFile = Get-ChildItem -LiteralPath (Join-Path $sandbox 'logs') -File | Select-Object -First 1
    $matches = Get-Content -LiteralPath $logFile.FullName | Where-Object { $_ -eq 'fresh session completed' }
    $recordedRuns = @($matches).Count
    Assert-Equal -Actual $recordedRuns -Expected 2 -Message 'The dated log must capture both Codex runs.'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output 'PASS: loop runs fresh Codex processes and records dated logs.'
