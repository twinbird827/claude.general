# PowerShell failure-mode pack

PowerShell (`.ps1`/`.psm1`/`.psd1`) failure modes for deep-code-review lenses A/B/C/D/F.

## Error suppression (lenses A/F)
- `-ErrorAction SilentlyContinue` / `-EA 0` (and `$ErrorActionPreference = 'SilentlyContinue'`) silences failures → later code proceeds on false premises. Root: identify what can fail and replace with `-ErrorAction Stop`
  + `try/catch`.
- `2>$null` discarding the error stream; `$null` assignment discarding pipelines.
- Spread: Grep other scripts for the same suppression patterns.

## Non-terminating vs terminating errors (lens A, correctness)
- Cmdlet non-terminating errors are NOT caught by `try/catch` (needs `-ErrorAction Stop` or `$ErrorActionPreference='Stop'`). A "wrapped it in catch but it still isn't caught" fix is symptomatic — check for the root fix that makes the error terminating.
- Missing `$?` / `$LASTEXITCODE` checks (external exes).

## Pipeline / return semantics (lenses A/D)
- Values **unintentionally emitted to the pipeline** inside functions pollute the return value (expressions emit even without `return`).
- Stray `Write-Output`; `return $x` returning both `$x` and prior expression output.
- Array/scalar shape breakage (`@()` coercion, `,` operator).

## Encoding (lens D — repo-specific rule)
- **`.ps1` files containing Japanese comments are intentionally Shift-JIS for PowerShell 5.1 compatibility — do NOT convert them to BOM-less UTF-8.** PS 5.1 reads BOM-less UTF-8 as ANSI(SJIS) and garbles the text.
- Missing `-Encoding` on `Out-File`/`Set-Content` (defaults differ across versions).

## Cross-cutting (lenses B/C)
- Duplicated helper functions / parameter validation / logging (module-extraction opportunity).
