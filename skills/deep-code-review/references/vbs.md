# VBScript failure-mode pack

VBS (`.vbs`) failure modes for deep-code-review.

## Declarations / type safety
- Missing `Option Explicit` — typos silently become new variables; a root reliability killer for the whole script.
- Implicit Variant typing morphs types (mixing `&` concatenation vs `+` addition).

## No structured error handling
- `On Error Resume Next` continuing without checking `Err.Number` — failures swallowed. Root: identify which operations can fail (file/WMI/COM/network) and branch on explicit `Err` checks.
- Spread: the same unchecked `On Error Resume Next` in other scripts?

## Late binding without type safety
- `CreateObject("...")` late binding — nonexistent method/property calls surface only at runtime.
- Nothing pins ProgID / method-name typos → design room for early validation (existence checks, wrapper functions).

## Resources / cross-cutting
- Unclosed/unreleased `FileSystemObject`/`ADODB`/WMI handles.
- Same WMI query / file walk / registry logic duplicated across scripts (shared-function opportunity).
