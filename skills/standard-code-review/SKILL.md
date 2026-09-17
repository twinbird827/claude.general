---
name: standard-code-review
description: 'Standard correctness code review of a diff: high-confidence bugs, CLAUDE.md compliance, git-history context. Confidence-scored, Minor/Nit findings under 80 filtered out; Critical/Major kept regardless of confidence — few, high-signal findings, no nitpicks. Read-only: never fixes, never posts comments. Accepts a commit range or PR/MR ref, and an effort arg (low|medium|high, default medium). Used as the standard-review stream inside code-review-plan-loop. For over-engineering use simplification-review; for codebase-wide spread / root-cause / design-ripple / regression / silent-failure lenses use deep-code-review.'
---

# standard-code-review — standard correctness review

**First output line: echo the parsed args** — `対象: <range> / effort: <low|medium|high>`. Callers (code-review-plan-loop) verify the effort arg was actually parsed. **All user-facing output in Japanese.**

## Target & effort

- 対象引数の規約は `~/.claude/references/review-target.md`。
- `effort` scales the internal fan-out:
  - **low** — lenses A+B, run inline in main (no subagents).
  - **medium** (default) — lenses A+B as 2 parallel read-only subagents.
  - **high** — lenses A–D as 4 parallel read-only subagents.

## Procedure

1. Collect the diff. List (paths only, not contents) the relevant CLAUDE.md files: repo root plus each directory whose files the diff touches.
2. Run the lenses. Each returns findings with a 逐語アンカー (the quoted line at the finding's location, which the lens has already read) and its `file:line`, why flagged, evidence, and a **provisional** severity and confidence 0–100. No lens is handed `~/.claude/references/finding-criteria.md` (and at medium/high a lens runs in its own subagent context), so every grading against it — severity, confidence, クラス — happens in main at step 3:
   - **A. Bug scan** — read the changed hunks; shallow scan for real bugs in the changes themselves. Large bugs only; ignore nitpicks and likely false positives; avoid reading context beyond the changes.
   - **B. CLAUDE.md compliance** — audit the changes against the listed CLAUDE.md files. CLAUDE.md is authoring guidance, so not every instruction applies at review time; flag only what a CLAUDE.md explicitly calls out.
   - **C. History** (high only) — the modified code's history (blame + log); bugs visible only in historical context.
   - **D. In-code guidance** (high only) — comments in the modified files; do the changes comply with guidance written in them?

   Subagents: `general-purpose` with read-only instructions, launched in parallel in one message. Lenses never spawn their own agents.
3. **Score and filter in main.** Read `~/.claude/references/finding-criteria.md` here, then apply it to every finding in this order:
   1. **Re-grade severity** against the 重大度 節 — first, because the drop below depends on the result.
   2. **Re-check confidence** against the 0–100 anchors of the 実在確度 節.
   3. **Drop a Minor/Nit scoring below 80; keep a Critical/Major whatever it scores** — closing an unconfirmed premise is finding-verifier's job and this filter sits upstream of it.
   4. **Assign クラス** against the クラス 節 — the lenses never produce it.
   5. **Write `Measurement`** where the 重大度 節 requires one — content and the 行動型 limit are in the 共通フィールド 節. A finding that needs one you cannot write is handled here per the 重大度 節.
4. **Output.** Findings numbered `SC1, SC2, …`: 一行サマリ / 重大度 / 場所（逐語アンカー、補助として `file:line`）/ 問題 / 根拠 / クラス / Measurement（持つ指摘だけ）/ 由来レンズ / confidence。問題 と 根拠 は別フィールドに分ける（`~/.claude/references/finding-criteria.md` の 共通フィールド 節）。指摘ゼロ → 「指摘なし（バグ + CLAUDE.md 準拠を確認）」。

## Never report (false positives)

- Pre-existing issues; real issues on lines the diff did not modify.
- Anything a linter, typechecker, compiler, or CI would catch (do not run builds yourself).
- General quality wishes (test coverage, docs, generic security) unless a CLAUDE.md explicitly requires them.
- **Nit-severity findings** (naming, formatting, wording). This floor is what keeps confidence a pure truth axis: with frequency moved to severity, a true nit now scores 100 and would otherwise pass the filter.
  - Exception: a CLAUDE.md explicitly calls the item out → report it at whatever severity it earns (lens B's job).
- Behavior changes that are likely intentional or directly tied to the broader change.
- CLAUDE.md items explicitly silenced in code (e.g. a lint-ignore comment).

## Rails

- **Read-only: no fixes, no commits, no PR/MR comments.** Findings return to the caller only.
- No fan-out beyond the lens subagents listed above.
