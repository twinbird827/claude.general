# PowerShell failure-mode pack

PowerShell (`.ps1`/`.psm1`/`.psd1`) review cues for deep-code-review.

## Error suppression
- Spread: when the diff adds or removes error suppression (`-ErrorAction SilentlyContinue` / `-EA 0`, `$ErrorActionPreference = 'SilentlyContinue'`, `2>$null`, empty `catch`), Grep other scripts for the same suppression patterns.

## Non-terminating vs terminating errors
- A "wrapped it in catch but it still isn't caught" fix is symptomatic — check for the root fix that makes the error terminating (`-ErrorAction Stop` or `$ErrorActionPreference = 'Stop'`).
