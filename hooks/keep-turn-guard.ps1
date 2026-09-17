# Stop hook: refuse to end the turn while a skill turn guard is active.
# A skill creates <cwd>/.tmp/keep-turn on entry and deletes it right before
# every yield point / turn-end output (contract: references/keep-turn.md).
# ASCII only (PowerShell 5.1 stdout encoding).
# Fail open: any unreadable/unparseable input ends the turn instead of blocking it.
$ErrorActionPreference = 'Stop'
try {
  # Read stdin via the raw handle: [Console]::In is empty when the harness runs
  # powershell.exe with -WindowStyle Hidden (no console attached).
  $raw = (New-Object IO.StreamReader([Console]::OpenStandardInput())).ReadToEnd()
  $cwd = ($raw | ConvertFrom-Json).cwd
} catch { exit 0 }
if (-not $cwd -or -not (Test-Path (Join-Path $cwd '.tmp\keep-turn'))) { exit 0 }
'{"decision":"block","reason":"A skill turn guard is active (.tmp/keep-turn exists). Continue with the next step of the running skill. If the skill has already reached a yield point or its turn-end output, or this session is not running a skill that uses this guard, delete .tmp/keep-turn and end the turn."}'
