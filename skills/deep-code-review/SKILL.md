---
name: deep-code-review
description: 'Supplementary multi-language (C#/VB6/VBS/PowerShell/Python) review used alongside standard-code-review. Covers only the layers the standard structurally misses: codebase-wide sweeps (spreading the same bug, missed reuse/consolidation), root cause vs symptomatic fixes, design ripple, silent failures (error suppression), regression tests. Reads per-language failure-mode packs from references/. Never repeats findings the standard review covers (in-diff correctness such as null/exceptions and boundary values, plus the style/conventions and generic security a CLAUDE.md mandates).'
when_to_use: '"コードレビューして", "PR を見て", "この差分を確認" and similar requests for a deeper review.'
---

# Deep Code Review (supplement to standard-code-review, multi-language)

A supplementary review skill for C#/VB6/VBS/PowerShell/Python, designed to run **alongside** `standard-code-review`. It adds only the perspectives the standard review structurally misses. **All findings and user-facing output in Japanese.**

> **Code search via Grep/Glob/Read (delegate broad sweeps to code-explorer):**
> - Delegate broad multi-file investigation to the read-only `code-explorer` subagent (`Agent` tool, `subagent_type: code-explorer`) and fold in only a concise summary.
> - When this skill itself runs inside a subagent, do the exploration yourself — subagents can't nest agents.

## Division of labor (the critical premise)

- **Never repeat what `standard-code-review` covers**: in-diff correctness (null/exceptions, boundary values), and CLAUDE.md-mandated style/conventions and generic security (injection / hardcoded secrets) — those reach its report only through its CLAUDE.md-compliance lens.
- This skill adds exactly the layers the standard is weak at:
  1. **Codebase-wide** — the standard sees only the diff in a single context; repo-wide perspectives are structurally absent.
  2. **Root cause** — the standard stops at symptomatic advice ("add a null check"); it doesn't trace back.
  3. **Design ripple** — effects outside the diff (callers, contracts, lifecycles) go unseen.
  4. **Silent failures** (lens F) — language-specific error-suppression idioms the standard under-detects (empty catch, `On Error Resume Next`, `-ErrorAction SilentlyContinue`, bare `except`).
  5. **Regression prevention** (lens E) — the standard reviews the diff itself, not whether a fix is locked in by a test; missing regression tests go unreported.
- **Overlap avoidance**:
  - Deletion- and complexity-type local simplifications (dead code, reinvented stdlib, speculative abstractions, nesting) belong to `simplification-review`.
  - Local naming-only nits are no stream's target unless a CLAUDE.md explicitly names them — then they are standard-code-review's CLAUDE.md-compliance lens's job.
  - Performance has no dedicated lens in any stream.
  - Lens C stays on **codebase-wide** reuse/consolidation misses.

## Language detection and packs

Detect languages from the diff's extensions and **read `${CLAUDE_SKILL_DIR}/references/<lang>.md` for each detected language**（`<lang>` = 下表 Language の小文字表記。`C#` だけ `csharp`）. Packs supply language-specific high-frequency failure modes; each pack's opening line states which lenses it feeds. Unlisted languages get the same lenses (Procedure step 2) without a pack.

| Language | Extensions |
|---|---|
| C# | `.cs` |
| VB6 | `.bas`/`.frm`/`.cls`/`.ctl`/`.vbp` |
| VBS | `.vbs` |
| PowerShell | `.ps1`/`.psm1`/`.psd1` |
| Python | `.py` |

## Procedure

### 1. Scope and context

**With a git repo, first:**
- 対象の変更セットを取得する — 対象引数の規約は `~/.claude/references/review-target.md`。
- Detect languages and read the packs (Language detection and packs section).
- For a bug fix, evaluate "symptom or cause" first.

**Context gathering (this skill's lifeblood)** — cross-repo judgments are impossible from the changed files alone. Do all of the following (Grep/Glob/Read; broad sweeps via code-explorer):
- Search the repo for equivalent existing logic (same computation / transformation / communication wrapper).
- Locate shared utilities, extension methods, base classes, helpers, common modules.
- Sweep the repo for the same bug/anti-pattern found in the diff (use pack idioms as search terms).
- Identify and read callers / derived types / implemented interfaces of changed functions to check contract impact.

**Without repo access (snippet only), most supplementary lenses don't hold.** In that case:
- Say so explicitly.
- Mark findings as conditional ("equivalent may exist — verify").
- Be frank that the difference from the standard review shrinks.

### 2. Apply the supplementary lenses A–F below.
### 3. Classify severity and クラス (severity criteria below; クラス のゲートは `~/.claude/references/finding-criteria.md` の クラス 節).
### 4. Report with the output template (担当外の層の排除は Division of labor 節 が正本).

---

## Supplementary lenses (only the layers the standard misses)

> **Maintenance-cost criterion (paramount, applies to every lens):**
> - Report anything that lowers future maintenance cost, **even if the blast radius is wide or runtime behavior is unchanged** — breadth and lack of immediate impact are never reasons to omit.
> - How such findings are scored is the Severity section's domain (not restated here).
> - Avoid speculative over-abstraction (YAGNI); the test is "does it reduce debt that exists today?"

### A. Root cause vs symptomatic fix
- **Null/undefined handling**: the standard says "add a guard"; here ask "can null occur by design?" If not, fix the root (initialization order, constructor, contract, non-nullable types, `Option Explicit` / type hints) instead of stacking guards.
- **"Works for now" fixes**: assess recurrence risk — did a conditional merely paper over an underlying inconsistency?
- Error-swallowing detection itself is lens F's job; A focuses on whether the fix reaches the cause.

### B. Spreading (codebase-wide)
Found a bug/anti-pattern? **Sweep the repo for its siblings** (exact literals via `Grep`; broad sweeps via code-explorer), using the pack's failure-mode idioms as search terms. One bug is often the tip of an iceberg — propose the same fix elsewhere when found.

### C. Existing assets and consolidation (codebase-wide)
- **Reinvention detection** — does an existing utility / extension method / base class / shared module already do what the added code does? Propose reuse.
- **Consolidation** — if the addition is generic, propose extracting to a shared function/library; also flag over-abstraction (YAGNI) at that codebase-wide scope.

### D. Design and contract ripple
- **Contracts/invariants** — does the change break assumptions of callers, derived classes, implemented interfaces? (Read outside the diff to confirm.)
- **Public APIs/signatures** — compatibility impact, breaking changes.
- **Lifecycle consistency** (framework-specific, easily missed): WPF/ReactiveUI ViewModel teardown (`CompositeDisposable`/`DisposeWith`, event handlers, Disposables), VB6 object lifetime (`Set Nothing`), Python context managers. Diff-only reading misses the teardown side (specifics in packs).

### E. Regression prevention
- **Regression test** — does the bug fix include a test reproducing the defect? Root fixes (A) and spreading (B) are only locked in by regression tests.
- **Changed-logic tests** — are key branches / error paths covered?
- **Testability** — side effects / static deps / tight coupling blocking tests → propose design improvement (C/D).

### F. Silent failures (error suppression — zero tolerance)
Pack idioms are the search terms (check the diff, then sweep the repo for siblings via lens B):
- **Swallowing** — catching and discarding, or converting to `null`/empty/default and losing cause context (language idioms in each pack).
- **Inadequate logging** — context-poor messages, wrong severity, log-and-forget (log then continue, cause unaddressed).
- **Dangerous fallbacks** — defaults that mask real failures; "graceful-looking" paths that cripple downstream diagnosis.
- **Propagation problems** — lost stack traces, generic rethrow destroying cause info, async exception loss (PowerShell non-terminating errors, Python un-awaited coroutine exceptions).
- **Unhandled risky paths** — network/file/DB calls without timeout/error handling; missing transaction rollback.

---

## Severity

**判定基準は `~/.claude/references/finding-criteria.md` の 重大度 節が正本** — 採点の前に Read する。ここには再掲しない。

- 本スキルの補完レンズ（A–F）が拾う指摘は、多くが **Major** と **Minor** に落ちる（どちらかは正本の表で決める）。
- **Nit（表記・語彙のみ）は本スキルの担当外** — 行き先は Division of labor 節 の Overlap avoidance。

---

## Output format (always this template; write it in Japanese)

以下のブロックは書式の例示であって、出力をフェンスで囲む指定ではない（テンプレ内側の 修正案 の code fence は出力に含める）。

```markdown
# 追加レビュー結果（standard-code-review 補完）

## 概要
- 対象: <ファイル/PR/差分の範囲>・<検出言語>
- 総評: <1〜3文。補完レンズ（A–F）の観点での全体評価>
- 件数: Critical N件 / Major N件 / Minor N件
<呼び出し元が `修正案なし` を渡したときのみ: - 修正案: 省略（呼び出し元指定）>
- 注記: 差分内の基本的な正当性は standard-code-review、過剰実装・削除系の簡素化は simplification-review の担当。本レビューは補完分のみ。

## 🔴 Critical
### DC1. <一行サマリ>
- **観点**: 根本原因 / 横展開 / 既存資産・集約 / 設計波及 / 再発防止 / 静かな失敗 のいずれか
- **場所**: <逐語アンカー。補助として `path/to/File.ext` L123 または該当関数/メソッド>
- **問題**: <何が、なぜ問題か。本番で何が起きるか>
- **根拠**: <実際に何を確認したか（`path:line`、grep 結果、差分の外の呼び出し元）>
- **クラス**: AUTO-FIXABLE | NEEDS-USER
- **Measurement**: <finding-criteria.md 共通フィールド 節 の形。同ファイル 重大度 節 が要求する指摘だけ。他は行ごと省略>
- **修正案**:
  ```
  // 改善後の例（対象言語で）
  ```
- **横展開**: <同種箇所の有無・要否。該当なければ「不要」>

## 🟠 Major
### DC2. <一行サマリ>
（同じ構造）

## 🟡 Minor
### DC3. <一行サマリ>
（同じ構造）

## 良い点（あれば）
- <"正しいので変えるべきでない"実装・優れた設計。過剰修正の防止になる。無ければこの節ごと省略>
```

### Output principles
- Layer boundaries follow the Division of labor section (never restated here); angle overlapping topics toward this skill's lenses instead.
- Every finding carries the common fields of `~/.claude/references/finding-criteria.md` (共通フィールド 節) plus this skill's own 観点 line, 修正案, and 横展開.
- **When the caller passes `修正案なし`** (code-review-plan-loop does):
  - Omit the 修正案 field entirely — do not draft one; a per-finding fix written now would anchor the caller's single change-set design to a symptomatic patch.
  - Echo `- 修正案: 省略（呼び出し元指定）` once in the 概要 節 so a dropped argument is visible instead of silent.
- Mark speculation/assumptions explicitly (don't assert).
- Constructive tone; findings target the code. No forced praise, no over-reporting.
