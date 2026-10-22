---
paths:
  - "**/*.ps1"
  - "**/*.psm1"
  - "**/*.psd1"
---

# PowerShell write-time rules

## Error suppression
- Do not silence failures with `-ErrorAction SilentlyContinue` / `-EA 0` or `$ErrorActionPreference = 'SilentlyContinue'` — later code proceeds on false premises. Identify what can fail and use `-ErrorAction Stop` + `try/catch`.
- Do not discard the error stream with `2>$null`, and do not assign a pipeline to `$null` to hide its failures.

## Non-terminating vs terminating errors
- Cmdlet non-terminating errors are NOT caught by `try/catch`. Make them terminating with `-ErrorAction Stop` or `$ErrorActionPreference = 'Stop'` before relying on `catch`.
- After calling an external exe, check `$LASTEXITCODE` (or `$?`).

## Pipeline / return semantics
- Inside functions, every uncaptured expression is emitted to the pipeline and becomes part of the return value, even without `return`. Suppress unwanted output (`[void]`, `| Out-Null`, `$null = ...`).
- Do not add stray `Write-Output`; remember `return $x` returns `$x` plus any earlier emitted output.
- Keep array/scalar shape explicit: wrap with `@()` where a collection is expected, and use the `,` operator to return a single-element array intact.

## Encoding
- Always pass `-Encoding` to `Out-File` / `Set-Content` (defaults differ across PowerShell versions).
- **`.ps1` / `.psm1` / `.psd1` を BOM 無し（BOM 無し UTF-8・Shift-JIS）にしない** — Windows PowerShell 5.1 は BOM 無しを cp932 で読み日本語を壊す。`Write`/`Edit` 後は PostToolUse フック `hooks/ps1-utf8-bom.sh` が BOM を付ける。

## Cross-cutting
- Do not duplicate helper functions, parameter validation, or logging across scripts; reuse or extract a module.
