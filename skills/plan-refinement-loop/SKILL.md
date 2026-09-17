---
name: plan-refinement-loop
description: 'Iteratively review and harden a plan file (implementation plan, spec, design doc) until a fresh sweep finds no Critical/Major issue (Minor/Nit are fixed in place without a re-sweep). Not for writing new plans from scratch (use plan-writing) or for reviewing source code (plans/specs/design docs only).'
when_to_use: '"プランを徹底調査して", "investigate this plan thoroughly", "review and fix my plan", "プランを精査して指摘を反映", and any request to critically review a plan and apply fixes repeatedly.'
---

# Plan Refinement Loop

A single convergence loop that hardens a plan file: investigate (fresh subagent) → adjudicate findings (fresh verifiers) → apply fixes (orchestrator) → investigate again — until **a fresh full sweep returns zero Critical/Major findings** (that sweep's Minor/Nit are fixed in place, not re-swept). The goal is a fast cycle, not a perfect plan: stochastic misses are caught by the post-implementation re-review (code-review-plan-loop), the designated backstop. Every plan-investigator sweep is performed by a fresh subagent with no history, so the investigation behind every sweep has "post-/clear fresh eyes" by construction — **no mandatory /clear anywhere**.

**All user-facing output (findings, questions, summaries) in Japanese.**

## Roles

- **Orchestrator (this session)**: launches subagents, checks coverage, tallies verifier votes, runs each finding's `Measurement` per step 2 手順 3, applies fixes to the plan (Edit), reflects user decisions into the plan text, manages state / limits / oscillation, and declares completion. **The orchestrator never investigates and never adjudicates**（例外は step 1 初回スイープの inline simplification-review） — its long context breeds bias for both; its job is bookkeeping and editing.
- **plan-investigator (read-only)**: every investigation, including the first. One fresh instance per sweep, given no history — it must read the whole plan from disk. The dimensions, review scope, and output structure live in the agent file, and the severity/class criteria in `~/.claude/references/finding-criteria.md` which the agent Reads itself; never restate either in the prompt.
- **finding-verifier (read-only)**: the precision filter. Independently adjudicates a finding's factual validity.

## Core principles

- **Plan format, posture, sections, and template live in `~/.claude/references/plan-doctrine.md`** (Read on entry). Follow it; never restate it here.
- **Iterate to convergence within the turn.** Investigate → verify → fix → re-investigate without ending the turn. Yield only at the genuine yield points below.
- **Two finding classes — AUTO-FIXABLE / NEEDS-USER — and the gates in front of NEEDS-USER are defined in `~/.claude/references/finding-criteria.md` の クラス 節** (Read on entry). Never restate them here. On top of the criteria file: whatever step 3's pre-fix check escalates on its own repetition trigger is NEEDS-USER too, reversible or not.
- **Every severity gets fixed or escalated; only Critical/Major get verified** — plus any finding whose action is filing an issue, at any severity. Other Minor/Nit AUTO-FIXABLE findings are applied without a finding-verifier call once step 2's Measurement (when the finding carries one) has matched; a NEEDS-USER finding that survives step 2 goes to the user at any severity, verified or not — never applied and never silently dropped. Fixes replace text rather than append, so they do not accrete.
- **The single rejection rule.** The criterion is `finding-criteria.md` の クラス 節 and the vote counting is `~/.claude/references/adjudication.md` (Read on entry) — a finding may be rejected only by finding-verifier votes counted there. Dropping a factually valid finding for any other reason is an implicit scope decision the user never approved — closing a finding against a standing 見送り in step 3's pre-fix check is not a rejection and takes no votes, since the 見送り already carries the user's decision. Likewise, a finding dropped in step 2 under `measurement-run.md` の 対象・実行・照合 節 is not a rejection and takes no votes — the criterion is `finding-criteria.md` の 重大度 節 の「仮説だけの指摘は成立しない」規則.
- **Never leak review history to subagents.** The per-agent input specs below are canonical; beyond what they name, pass nothing that reveals the plan was reviewed or recently edited. What may be passed is anything neutral and permanent — `verified_facts`, `document_type`, project context, the doctrine path.
- **Decisions live in the plan, not in chat.** When the user settles a NEEDS-USER item — including "leave it as is" — reflect the decision into the plan's 確定済みの判断 節 — one line with rationale, carrying the `（ユーザー判断: …）` marker — and, when the answer calls for work the plan does not yet carry, into a 修正内容 item as well (the AWAITING_USER_DECISION branch in Procedure spells out both). Otherwise the next fresh sweep re-flags the same issue and the loop cannot converge.
- **Settled decisions are revisitable.** A recorded decision is the current best answer. When a sweep finds a simpler solution that discards an earlier decision, that is a valid finding — for a line without the `（ユーザー判断: …）` marker its class follows the 可逆性 line of `~/.claude/references/finding-criteria.md` の クラス 節, not a rule restated here. A line carrying the marker binds（`finding-criteria.md` の 確定した判断の拘束力 節 が正本 — what a sweep does with it is the 判定表 in step 3）. When a sweep replaces a decision the table does not bind, write the new one on the same line with a one-clause reason. Apply a NEEDS-USER answer by **replacing** the old text and collapsing the record to one line (decision + one-clause reason); the superseded rationale is deleted, not appended.
- **Converge honestly.** Don't loosen criteria to finish. Don't auto-decide NEEDS-USER items. Subagents never decide completion.

## Out-of-scope findings（別課題）: file them now, never carry them as plan text

What counts as out of scope, and how to file it, live in `~/.claude/references/issue-filing.md` (read on entry). Follow it.

## Invoking subagents

**plan-investigator** (`Agent` tool, `subagent_type: plan-investigator`) — one fresh instance per sweep. Pass ONLY:

1. The plan file **path** (not contents — reading from disk forces a full read).
2. The document type: implementation-plan | spec-or-design-doc.
3. Only if needed: neutral, permanent project context (repo root, language, glossary).
4. If present: `verified_facts` from the sidecar (verified neutral external facts and Measurement results only — never findings or fix history; each Measurement record stripped of its `location` / `iteration` per step 2 手順 3), noting that listed facts need no re-verification via Context7/web.
5. When the document type is `implementation-plan`: the path `~/.claude/references/plan-doctrine.md` (a neutral, permanent conventions document — not review history, so it leaks no bias).

**Coverage check on return**: every dimension named in the COVERAGE block of `~/.claude/agents/plan-investigator.md`（coverage check の直前に Read する）must have its own COVERAGE line, and each must carry concrete evidence (sections examined + files/APIs re-verified this pass). Bare "checked" or evidence citing a single section = shallow sweep → relaunch a fresh investigator (a shallow pass does not count as a sweep; 連続再起動の上限は Limits and oscillation 節).

**finding-verifier** (`subagent_type: finding-verifier`) — one finding with an ID (`S1` 等; Location/Problem/Evidence) plus relevant file paths per invocation, parallelized across findings. A `NOTE` is a wording reservation — fold it into the fix, never a reason to defer. A **REFUTED** verdict, a split, or an UNVERIFIABLE adds verifiers per `~/.claude/references/adjudication.md`; what the resulting votes decide is there too. Which findings go through it is decided in step 2.

**general-purpose** (`subagent_type: general-purpose`) — one fresh instance per reader-behavior `Measurement` run (step 2). What to pass — and that it is not structurally read-only — is `~/.claude/references/measurement-run.md` の 実行 節; pass nothing beyond what that section lists.

## State (sidecar YAML)

`<plan>.review-state.yaml`. **The five keys shared with the seeding skills (`document_type` / `open_needs_user` / `rejected` / `filed_issues` / `verified_facts`) are defined in `~/.claude/references/review-state-schema.md` — never restate their semantics here.** On entry read the sidecar and resume from `phase`; write it back before ending any turn. A sidecar with no `phase` is a caller-provided seed (from plan-writing or code-review-plan-loop) — start fresh (`iteration: 0`), keeping its values. `applied_fixes` and `oscillation_log` live and die with this plan's sweeps.

以下のブロックは書式の例示であって、サイドカーをフェンスで囲む指定ではない。

```yaml
plan_file: docs/plan.md
document_type: implementation-plan
phase: RUNNING                # RUNNING | AWAITING_USER_DECISION | COMPLETE | STOPPED
iteration: 0                  # investigator sweeps completed
max_iterations: 15
last_investigation:
  critical: 0
  major: 1
  minor: 2
  nit: 0
  coverage:                   # one line per dimension. 次元の一覧は agents/plan-investigator.md の COVERAGE ブロックが正本。
                              # evidence = sections examined + files/APIs re-verified. Truly N/A → "n/a: <reason>"
    factual_grounding:    { checked: true, evidence: "verified bar() exists via Read (§A-2)" }
    # 以降の次元も同形式
open_needs_user: []
verified_facts: []
rejected: []
filed_issues: []
applied_fixes:                # entry = { iteration, location, kind, change }. kind は
                              # `finding-criteria.md` の 確定した判断の拘束力 節 の3種 = fact | 見送り | design。
                              # location は アンカーを含む 修正内容 項目 / 節 で書く（逐語アンカーそのものは書かない）。
  - { iteration: 1, location: "§修正内容-2", kind: fact, change: "replaced nonexistent API foo() with bar()" }
oscillation_log: []           # write [] explicitly when empty. entry =
                              # { iteration: 3, location: "<反復と判定した location>", note: "<何が反復したか（制約と両立しなかった / A→B→A で戻った / 同一 location の2回目の書き直し）/ どう決着したか>" }
```

## Procedure (the loop)

On entry, Read `~/.claude/references/plan-doctrine.md`, `~/.claude/references/finding-criteria.md`, `~/.claude/references/adjudication.md`, `~/.claude/references/review-state-schema.md`, `~/.claude/references/issue-filing.md`, `~/.claude/references/measurement-run.md` and `~/.claude/references/keep-turn.md`, then the sidecar. Create the marker per `keep-turn.md` first. Resolve `document_type` (key absent, or no sidecar → `spec-or-design-doc`), never infer it from the path, and write that same value back whenever you write the sidecar. Then resume from `phase`:

- **No sidecar, or no `phase` (a caller-provided seed)** → start fresh (`iteration: 0`), keeping `document_type` / `verified_facts` / `open_needs_user` / `rejected` / `filed_issues`（欠落キーは空として扱う）. A seeded `open_needs_user` is presented at step 3 bundled with this sweep's questions — **do not end the turn here**. Continue at step 1.
- **RUNNING** → continue at step 1.
- **AWAITING_USER_DECISION** → 回答の無い再開（`/clear` と「プランの調査を続けて」）は、各 `open_needs_user` エントリを stored `options` / `pivot` から逐語で再提示し、ターンを終える — 選択肢を再導出しない。回答があるときは以下を順に:
  1. **まず**すべての回答 — "leave as is" と 実施しない を含む — を Core principles のとおりプランの 確定済みの判断 へ反映する。実施しない は**加えて** schema の 形式 で `rejected` へ記録し（併記の正本は doctrine 姿勢 節）、完了時は `ユーザ判断で確定` 行で報告する（`却下（事実誤認）` 行にしない）。
  2. 回答がプランに既にある作業を変えるなら、該当 修正内容 項目をその場で置換で編集する（追記しない）。
  3. **回答がプランに無い作業を要するとき**（典型: seed された `open_needs_user` の指摘をユーザーが実在と確定したとき）、修正内容 節 があればそこへ項目（場所 / 変更 / 理由）と 検証 行を書き、修正内容 節・検証 節 それぞれが空ラウンドのプレースホルダ行を持つなら置き換える。目的 節 が findings list を持つならその採番の次の空き ID で1行足し、空ラウンド行（中立の「このラウンドは変更セットを持たない」または 要ユーザー判断 の行）を持つならその行を「以下の指摘を解決する」＋その1行（ID `F1`）へ置き換える。確定済みの判断 の1行は決定を記録するだけで、実装セッションが実行できるものを与えるのは 修正内容 項目だけ。
  4. `applied_fixes` へ同じ `kind` で記録する — 実施しない の回答は `kind: 見送り`、事実を確定した回答は `fact`、それ以外は `design`。`open_needs_user` をクリアし、**そのあと** step 1 から続行する。

1. **Investigate**: launch a fresh plan-investigator (contract above). Run the coverage check; relaunch if shallow. `iteration += 1`. Respect `max_iterations`. 同じ step で `simplification-review` を Skill tool で inline 実行する — **そのプランにつき1回だけ**（step 2 手順 2 の再起動で `iteration` を戻しても再実行しない）で、対象はプランのパスを引数で渡す（`修正案なし` は渡さない — Proposed fix をそのまま使う）。本スキル固有の扱いは2つ: ID は返ってきた接頭辞のまま S 系列とは別系列で並置する（合流も再採番もしない）、S 系列と同じ 場所 を指す PR 指摘は S 側を残して落とす。PR 系列は S 系列と同じく step 2 へ流すが、step 2 手順 2 の Options 件数照合は S 系列だけを数える — PR 由来が NEEDS-USER になったときの `options` / `pivot` は orchestrator が 質問の出し方 節 の形式で書く。
2. **Adjudicate**:
   1. このスイープの指摘に investigator のレポート順で `S1, S2, …` を振る。
   2. レポート末尾の Options ブロックを、同じ順序で NEEDS-USER の指摘へ対応づける。対応づける前に Options ブロック数が `Class: NEEDS-USER` の指摘数と一致することを確かめる — 一致しなければ順序という唯一の対応キーが失われているので、shallow sweep と同じくフレッシュな plan-investigator を起動し直す（step 1 から起動し直し、加算済みの `iteration` からこのスイープぶんを戻す。連続再起動の上限は Limits and oscillation 節）。
   3. **Measurement を実行する** — 対象・実行・照合・n の規則は `~/.claude/references/measurement-run.md`（entry で Read 済み）。一致で生き残った指摘と、不一致・実行不可でも落とさない Critical/Major は次の手順へ（Critical/Major は verifier へ、Minor/Nit は step 3 へ）。落とした Minor/Nit は生存しない。測定の結果は `measurement-run.md` の 結果 節 のとおり3経路とも `verified_facts` へ記録する — そのうち実行して落とした Minor/Nit の記録だけが次スイープの investigator に渡り、同じ指摘が再燃しない。不成立の記録は渡さない（`rejected` には書かない）。記録には指摘の 場所 を `location`、そのスイープの `iteration` を添える（形式は `measurement-run.md` の 照合 節）。`iteration` が `-` の記録は無条件に渡さない（別 producer が別の文書・差分を測ったもので、この文書の `applied_fixes` とは突合しえない）。同じ `location` の `applied_fixes` エントリが記録と同じか後の `iteration` にあれば、その記録は investigator へ渡さず、同じ指摘が再び挙がったらここで測り直す — 旧版に対する測定が新しい本文への指摘を封じないため。渡す記録からは `location` と `iteration` を落とす（過去の指摘の 場所 とスイープ番号は investigator へ渡さない契約のため）。
   4. 各 Critical/Major 指摘を finding-verifier へ渡す（並列起動）。票の数え方・追加する検証者の人数・決着しなかったときの行き先は `~/.claude/references/adjudication.md` が正本（entry で Read 済み） — 決着しなかった事実と、価値・スコープ・リスク姿勢の問いは、NEEDS-USER として step 3 の branch へ回す。Minor/Nit はこの step を飛ばす — 例外は起票を action に持つ Minor/Nit で、起票できるようここで裁定する。
   5. CONFIRMED で返ったスコープ外指摘はここで起票する（上の Out-of-scope findings 節のとおり）。verdict の `SOURCES`（外部確認済みの事実）はサイドカーの `verified_facts` へ追記し、次スイープの investigator が受け取れるようにする。
3. **Branch — apply first, then decide** — a finding settled in step 2 (rejected, dropped by Measurement, or resolved by an issue: newly filed, or deduped against an existing tracker issue or `filed_issues` entry) is not "surviving" in any branch below:
   - **First, apply every surviving AUTO-FIXABLE finding of any severity** to the plan and append each to `applied_fixes` with the `kind` its constraint carries — `fact` for a factual correction, `見送り` for work decided against, `design` for a design or wording choice — before any of the branches below. Ending the turn with unapplied fixes discards the sweep's work and forces the next sweep to re-find it. 各修正は書く前に pre-fix check を通す:
     1. **突合**: 指摘は 場所 を逐語アンカーで名指ししているので、そのアンカーを含む 修正内容 項目 / 節 を location とし、(a) `applied_fixes` の既存エントリと location で突合する（一致は「同じ 修正内容 項目 / 同じ 節 を指すか」で判定し、文言の一致は要らない）。あわせて (b) 確定済みの判断（プランが持つとき）と対象項目の 理由 行に、この修正が触れる制約が無いか確かめる。どちらもヒットせず、location に過去スイープの `oscillation_log` エントリも無ければ、手順 2–4 を飛ばして修正する（手順 5 の記帳は当てる）。
     2. **制約の kind は記録から取る — 散文の読み直しで再分類しない**: `applied_fixes` エントリは自身の `kind` を持つがマーカーを持たないので、`fact` 以外は拘束せず、拘束は (b) で見つかる行のマーカーで決まる。確定済みの判断 の行と 理由 行はその場で `finding-criteria.md` の 確定した判断の拘束力 節 で分類する（どの種類が拘束するかは同節が正本）。拘束する制約を満たすように修正を書く。拘束しない制約は捨ててよく、捨てても振動ではない（`oscillation_log` に書かない）。
     3. **衝突・反復（repetition trigger）の判定表** — 当たる行があれば通常の適用でなく行の 帰結 に従う（帰結が 適用 のときも、パッチか書き直しかという適用の形は手順 4 が決める。どの行にも当たらなければ通常の適用で、記録しない）。記録 = `oscillation_log` へ1エントリ（形式は `## State`、`iteration` は今スイープ）。手順 4 のエスカレートも同じ。拘束する制約を覆せるのがどの条件かは 手順 2 と同じく 確定した判断の拘束力 節 が正本で、下表はその条件の充足・不充足に対する帰結だけを与える:

        | 条件 | 帰結 |
        |---|---|
        | 拘束する 事実の訂正 と両立せず、正本の覆し条件を満たす | 適用し、記録 |
        | 拘束する 事実の訂正 と両立せず、満たさない | AUTO-FIXABLE でない — NEEDS-USER へエスカレートし、同様に記録 |
        | 拘束する 見送り と両立せず、正本の再オープン条件を満たす | NEEDS-USER へエスカレート |
        | 拘束する 見送り と両立せず、満たさない | 見送り が立つ — 指摘をそれで閉じ、完了サマリの ユーザ判断で確定 行で報告する（却下ではない） |
        | 拘束する 設計・表現の選択（`（ユーザー判断: …）` 付き）と両立しない（事実誤認の訂正を除く） | AUTO-FIXABLE でない — NEEDS-USER へエスカレートし、記録 |
        | 既存の `applied_fixes` エントリが置換前テキストを名指ししており、修正がそれを復元する（A→B→A） | AUTO-FIXABLE でない — NEEDS-USER へエスカレートし、記録 |
        | location に過去スイープの `oscillation_log` エントリがある | 同上 |
     4. **パッチが積み上がった location は書き直す**（正本: `finding-criteria.md` の 確定した判断の拘束力 節 の書き直し規則）: location の `applied_fixes` エントリが `kind` を問わず（`change` が `副作用:` で始まる手順 5 の記帳エントリは数えない）、最新の `rewrite:` エントリ以降（無ければ全エントリ）で3件以上になったら、既定は次のパッチでなく、その location が指す 修正内容 項目（節 を指すなら節全体）を正本の規則どおり 目的 から書き直す。書き直しは `kind: design`（書き直し自体が設計の選択）・`change` が `rewrite:` で始まるエントリとして `applied_fixes` へ記録し、**カウントはそこで再起動する** — 書き直した location は次に3件積もるまで通常のパッチへ戻る。**同じ location の2回目の書き直しは自動でない**: 既に `rewrite:` エントリを持つ location でカウントが再び3に達したら、AUTO-FIXABLE でない — NEEDS-USER へエスカレートし、手順 3 と同じ形式で `oscillation_log` へ記録する。
     5. **記帳**: 新規に 修正内容 項目を書いたときは、AWAITING_USER_DECISION バレットと同じ扱いで 修正内容 / 検証 / 目的 を更新し、副作用で書き換えた 検証 / 目的 / 確定済みの判断 の各節にも、その節を `location`、`kind: design`、`change` を `副作用: <新規項目の番号>` とするエントリを同じ `iteration` で足す（測定記録の無効化はこの location 一致で効くため）。制約を捨てた・覆したときは、その1行を doctrine の 意図的な省略 規則が指す場所へ書く（古い制約行がそこにあれば置換） — サイドカーは振動の台帳であって、実装セッションが読むものではない。
   - **Any open NEEDS-USER**（severity や step 2 の検証の有無を問わず、NEEDS-USER と分類された生存指摘すべて＋seed された `open_needs_user`）→
     1. `phase: AWAITING_USER_DECISION`。
     2. `open_needs_user` へ記録する — このスイープで新たに記録するものの `reason` は `NEEDS-USER クラス`、step 2 から回った未決着は `adjudication.md` が与える値、エスカレートした反復は `エスカレートした反復`、seed されたエントリは seed が書いた値を保つ。各エントリに、これから提示する問いの `options` / `pivot` を持たせる（必須条件と理由は `~/.claude/references/review-state-schema.md` の `open_needs_user` が正本）。
     3. すべての未決の問いを `finding-criteria.md` の 質問の出し方 節 の形式で提示する（entry で Read 済み）。`options` / `pivot` を既に持つ seed エントリは、初回提示でも AWAITING_USER_DECISION バレットのリード文と同じ規則で扱う。
     4. ターンを終える。
   - **This sweep had a surviving Critical or Major finding** → print the inline progress line and continue at step 1 **in the same turn** — a fix at that severity changes what the implementing session builds, so it needs a fresh sweep behind it.
   - **Otherwise (no Critical/Major, no open NEEDS-USER)** → **COMPLETE**: `phase: COMPLETE`, print the completion summary. This sweep's Minor/Nit fixes are applied but land unverified and un-reswept — an accepted residual risk; the post-implementation re-review is the only net under them.
4. **Session checkpoint (every 5 sweeps per session):** whenever step 3 loops back to step 1, first count the sweeps run in the CURRENT session (not the sidecar's total `iteration` — the cost lives in this session's context). If ≥ 5, write the sidecar (`phase: RUNNING`) and yield the session checkpoint recommending /clear — accumulated reports, verdicts, and edits ride as input cost on every later orchestrator call and are re-written whenever the cache expires. Resuming (「プランの調査を続けて」) re-enters at step 1 via the RUNNING branch; the per-session count restarts at 0. No new sidecar keys.

## Limits and oscillation

- `max_iterations` reached → `phase: STOPPED`, report remaining findings with severity, recommend manual review.
- フレッシュ再起動（step 1 の coverage check が検出する shallow sweep / step 2 の Options 件数不一致）は、受理されたスイープを挟まず連続3回まで。4回目が要る状態になったら `phase: STOPPED` — 上限到達と同じ報告に、どちらの再起動条件が尽きたかを1行添える。カウントの保持は step 4 のセッション内カウントと同じ扱い（対象は別のカウンタ）。未解決 行には棄却したスイープの指摘を 未検証 と明示して並べる。
- Oscillation → detection, logging and escalation all live in step 3's pre-fix check. This section sets no separate trigger and no separate granularity.

## Turn-end output

Yield points: Awaiting user decision（AWAITING_USER_DECISION 分岐の逐語再提示を含む）/ Session checkpoint / Complete / Stopped — いずれも出力の直前に marker を消す（`keep-turn.md`）。同一セッションで回答を受けて続きを実行するときは同文書の 作り直す のとおり。Subagent launches and fix application are NOT turn ends — continue in the same turn.

以下のブロックはいずれも書式の例示であって、出力をフェンスで囲む指定ではない。

Include the coverage line in every investigation report (a ✓ without backing evidence in the YAML is invalid):
```
観点: <plan-investigator.md の COVERAGE ブロックの次元名（`factual_grounding` 等の識別子）を ✓ 付きで並べる>
```

**Inline progress (fixes applied — continue):**
```
- ↳ Iteration I — auto-fixes applied: §修正内容-2 <…>, §検証 <…>
- <測定で落とした指摘があるときのみ: 測定で不成立 n 件: <指摘の一行要約> ← <理由（期待出力と生出力の食い違い / 実行しなかった理由）> を `  - ` のサブバレットで1件ずつ>
- <coverage 行> → 新しい調査エージェントで再スイープします（継続）
```

**Session checkpoint (5 sweeps this session):**
```
## Iteration I — セッションチェックポイント（このセッションで5スイープ実施）
- 調査は継続中です（未収束）。🔄 `/clear` してから「プランの調査を続けて」と送るのを推奨します（蓄積した調査レポート・裁定・修正の文脈は以降の呼び出し全部のコストに乗るため）。
- <測定で落とした指摘があるときのみ: 測定で不成立 n 件: <指摘の一行要約> ← <理由（期待出力と生出力の食い違い / 実行しなかった理由）> を `  - ` のサブバレットで1件ずつ>
- <oscillation_log が非空のときのみ: 反復した location（実装前に確認してください）: <location — note を `  - ` のサブバレットで1件ずつ>>
- 状態は <plan>.review-state.yaml に保存済み。/clear せず「続けて」でそのまま続行も可能です。
```

**Awaiting user decision:**
```
## Iteration I — 判断が必要な指摘

<finding-criteria.md の 質問の出し方 節 の書式で、未決の問いを1件ずつ（`[U1] §<場所> — <問い>` から `判断が分かれる点:` まで。entry で Read 済み）>

上記の指摘は設計判断のため自動修正していません。回答をいただければプランに反映して調査を続けます。

- <自動修正が1件以上のときのみ: ↳ このスイープの自動修正 n 件は適用済み: §<場所> <一言>>
- <測定で落とした指摘があるときのみ: 測定で不成立 n 件: <指摘の一行要約> ← <理由（期待出力と生出力の食い違い / 実行しなかった理由）> を `  - ` のサブバレットで1件ずつ>
- <oscillation_log が非空のときのみ: 反復した location（実装前に確認してください）: <location — note を `  - ` のサブバレットで1件ずつ>>
- 状態は <plan>.review-state.yaml に保存済み（/clear しても「プランの調査を続けて」で再開できます）。
```

**Complete:**
```
## 🎉 完了（全 I イテレーション）
- 独立したフレッシュ調査のフルスイープで Critical/Major ゼロを確認。
- <最終スイープに Minor/Nit があったときのみ: Minor/Nit n 件は同スイープで適用済み（再スイープなし）。>
- <coverage 行>
- 解決した指摘累計: Critical X / Major Y / Minor Z　ユーザ判断で確定: <list>
- 却下（事実誤認）: <`  - ` のサブバレットで1件ずつ（事実誤認のみ）>
- <測定で落とした指摘があるときのみ: 測定で不成立 n 件: <指摘の一行要約> ← <理由（期待出力と生出力の食い違い / 実行しなかった理由）> を `  - ` のサブバレットで1件ずつ>
- 別課題として起票: #<N>
- <oscillation_log が非空のときのみ: 反復した location（実装前に確認してください）: <location — note を `  - ` のサブバレットで1件ずつ>>
- 判定: プランは実行可能な状態です（残リスク: …）。取りこぼしは、実装後に code-review-plan-loop を実行すると拾えます。
```

**Stopped:**
```
## ⚠️ 上限到達で停止（Iteration I）
- 未解決: <list with severity>
- <測定で落とした指摘があるときのみ: 測定で不成立 n 件: <指摘の一行要約> ← <理由（期待出力と生出力の食い違い / 実行しなかった理由）> を `  - ` のサブバレットで1件ずつ>
- <oscillation_log が非空のときのみ: 反復した location（実装前に確認してください）: <location — note を `  - ` のサブバレットで1件ずつ>>
- 手動レビューを推奨します。状態は <plan>.review-state.yaml に保存済み。
```
