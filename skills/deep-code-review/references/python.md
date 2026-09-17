# Python failure-mode pack

Python (`.py`) failure modes for deep-code-review lenses A/B/C/D/F.

## Mutable default arguments (lenses A/B)
- `def f(x, acc=[])` / `={}` — the default is created once at definition time and shared across calls → state leaks. Root: `None` sentinel + create inside. Spread: Grep other functions for `=\[\]` / `=\{\}` arguments.

## Exception swallowing (lenses A/F)
- Bare `except:` / `except Exception: pass` / overly broad catches hiding causes; `contextlib.suppress` abuse; un-awaited coroutine exceptions lost. Ask why the exception occurs (root); minimize catch scope, re-raise.

## async/await mix-ups (lens A, correctness)
- Forgotten `await` (calling `f()` does nothing / `RuntimeWarning`).
- Sync blocking I/O (`requests`, `time.sleep`) inside the event loop stalls it.
- `asyncio.create_task` return value not kept → task garbage-collected and lost.

## Context managers / resource leaks (lens D)
- `open()` / sockets / DB sessions without `with` (no close on exception).
- Are locks/transactions released via `try/finally` or `with`?

## Type hints / contracts (lenses A/D)
- Missing hints / heavy `Any` → vague contracts; caller-assumption breakage surfaces only at runtime.
- `Optional[T]` returns used without guarding (question the None design at the root).

## Cross-cutting (lenses B/C)
- Duplicated conversions / I/O wrappers / validation (reuse existing utilities, extract shared functions).
