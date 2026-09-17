# VB6 failure-mode pack

VB6 (`.bas`/`.frm`/`.cls`/`.ctl`/`.vbp`) failure modes for deep-code-review lenses A/B/C/D/F.

## Error-handling design (lenses A/F)
- `On Error Resume Next` at function top, continuing without checking `Err` — errors vanish. Ask why the code can fail (root) and whether explicit `On Error GoTo <label>` handling fits.
- Missing `On Error GoTo 0` reset → later code drags an unintended handler.
- Spread: Grep other modules for the same `On Error Resume Next` pattern.

## Object lifetime (lens D, leaks)
- Missing `Set obj = Nothing` (especially circular refs, form/collection holds) → refcount never drops.
- Unreleased objects with events (`WithEvents`).
- Missing explicit closes for file/DB/COM handles (`Close #n`, ADO `Connection.Close`).

## Variant / type safety (lens A)
- Branching/comparison relying on implicit Variant conversion — types morph at runtime, breeding recurrent bugs.
- `Dim x, y As Integer` (x silently becomes Variant — the classic VB6 trap).
- Implicit string⇄number conversion; `= Null` comparison where `IsNull` is required.

## Cross-module (lenses B/C)
- Same computation / conversion / DB access copy-pasted across `.bas`/`.frm` files (consolidation opportunity).
- Duplicated magic numbers / hardcoded connection strings.
