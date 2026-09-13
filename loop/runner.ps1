$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$codexCandidates = Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin') -Filter 'codex.exe' -Recurse -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending
$codex = $codexCandidates | Select-Object -First 1
if ($null -eq $codex) { throw 'codex.exe was not found under %LOCALAPPDATA%\OpenAI\Codex\bin.' }

# Scheduled tasks do not inherit the interactive terminal environment.
$env:PATH = "{0};C:\Windows\System32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0" -f $codex.DirectoryName
& (Join-Path $PSScriptRoot 'loop.ps1') -Workspace $workspace -CodexCommand $codex.FullName
