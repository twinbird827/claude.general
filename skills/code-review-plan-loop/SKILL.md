---
name: code-review-plan-loop
description: 'Review a code diff (standard-code-review + deep-code-review + simplification-review, run inline in main), adjudicate every finding via finding-verifier subagents, then design ONE coherent change set that resolves all confirmed findings and write it as an implementation plan under docs/plans — never fix immediately. Out-of-scope findings are filed as issues on the spot. The plan is implemented in a fresh session; re-invoke after implementation to re-review (user-driven loop). For one-off reviews without a plan use standard-code-review directly; for refining an existing plan use plan-refinement-loop directly.'
when_to_use: '"指摘をプラン化して", "レビュー結果をドラフトプランにまとめて", "review into a draft plan", "指摘をプラン化→精査→実装のループで".'
---

# Code Review → Draft Plan（単一パス・stateless）

Review the target diff, adjudicate the findings, then design **one change set** that resolves all of them and write it as a plan under `docs/plans` — **never fix immediately**. Implementation happens in a separate session; re-running this skill after implementation is the re-review — the loop is **user-driven**, not automated. **All user-facing output in Japanese.**

**Division of responsibility** (stages are separated by user /clear — freshness comes from /clear, not from subagent fan-out):

- **Discovery (WHAT)** = `standard-code-review` + `deep-code-review` + `simplification-review`, all three run **inline in this session** via the Skill tool.
- **Adjudication (is the finding real?)** = `finding-verifier` subagents, one per root-cause/file cluster.
- **Design (HOW) + drafting** = this session, once, over all confirmed findings.
- **Final precision (plan-level)** = plan-refinement-loop, in a fresh session (fresh-eyes investigation, NEEDS-USER settlement, consistency/sequencing/risk). Always run — no skip gate — except the final plan of a converged round (step 3), which goes straight to implementation.
- **Implementation** = a fresh session reading the plan.

## Procedure (one invocation = one pass)

### 1. Scope

- **`~/.claude/references/keep-turn.md` を Read し、marker `.tmp/keep-turn` を作る**: 消す地点は step 2 の yield point 段落が列挙し、消し方・作り直しは同文書に従う。
- **Read `~/.claude/references/plan-doctrine.md`, `~/.claude/references/finding-criteria.md` and `~/.claude/references/measurement-run.md` first.** The doctrine's 姿勢 節 governs step 4's design scope and step 5's filing decision, not just step 6's drafting. The criteria file drives step 2's normalization, step 3's Nit gate, step 4's NEEDS-USER gate and fix-design default（確定した判断の拘束力 節）, and the turn-end question format.
- Target diff: **対象は次のいずれか1つの単一トークンへ解決する**（固定の既定は無い — どれになるかは Round バレットの**作業状態の判定表**が決める）: ユーザーが名指しした PR/MR・commit range / `<base>...HEAD` / 既定ターゲット（ローカルの未コミット+staged）。
  - `<base>` はこのブランチの分岐元で、既定ブランチを既定値とする。`<base>..HEAD` のコミット一覧にこのブランチの作業（前ラウンドの実装を含む）以外のコミットが混じるなら分岐元が別（current から切ったブランチ等）なので、推測せず対象をユーザーへ確認する。
  - **解決した単一トークンは step 2 の各ストリームへ引数で渡す** — 渡さなければ各ストリームは自分の既定（`~/.claude/references/review-target.md` の 既定）を見るので、コミット済みを再レビューするラウンドでは空を見てゼロ件を返す。
  - **既定ターゲットのときだけ渡さない** — 渡せる単一トークンが無く、正規化を発明すると各ストリームがその語を解釈する保証の無いまま誤警報を常時踏む。コミット済みと未コミットの和にも単一トークンは無い — merge-base のコミット ID を差分の起点にしても未追跡を含まず、各ストリームが解釈する対象文法も揃わない。
- Pick `<name>`:
  - **対象が current ブランチの作業のとき**（既定ターゲット、または current ブランチ上の range/PR）はブランチ名から導出する — current ブランチ名を取り、`A-Z a-z 0-9 -` 以外の文字をすべて `-` へ置換する（例: ブランチ `refactor/plan-skills` → `refactor-plan-skills`）。写像は決定的なので、同じブランチは照会なしで常に同じ系列に載る。
  - **それ以外の対象と detached HEAD**（ブランチ名が空）は、差分のテーマから、既存のどの `docs/plans/**/cr-fixes-*` 系列とも一致しない新しい `<name>` を付ける — Round バレットは `<name>` だけをキーにするので、衝突する名前は別系列の carry を引き継いでしまう。
- **Fetch only what scoping needs** (token efficiency): branch refs + `git diff --numstat <range>` (file list/sizes). **Do NOT pull the full PR/MR description body or whole-file dumps into context** — the review runs on the diff, not the prose. Read specific files only later, when a finding needs confirmation.
- Round: `N` is **this** run's round number in every `Round` and `-r<N>` reference in this skill.
  1. **`N` の決定**: 既存の `docs/plans/**/cr-fixes-<name>-r*` の最大ラウンドを `N-1` とし、この実行を `N` とする。該当ファイルが無ければ `N` = 1。数えるのは `docs/plans/` 配下をサブディレクトリまで再帰で、`.md` と `.review-state.yaml` の両方（`.review-state.yaml` もサブディレクトリも数えるのは、既存の系列でラウンド番号を振り出しへ戻さないため — `.md` を伴わないサイドカーだけのラウンド（旧規則の収束記録）と、repo ごとに名前の異なる退避先フォルダに残る系列がある）。
  2. **対象の決定**: ユーザーが対象を名指ししていないときの対象はラウンド番号でなく作業状態で決まり、判定はラウンドを問わず同じ — **作業状態の判定表**（このバレット末尾の表）が決める。Round ≥2 は実装後の再レビューで、対象は前ラウンドの修正を含む範囲になり、こうして決めた対象を通しでレビューすることが再検証を兼ねる。
  3. **停止条件**: 次の3つは step 2 へ進まない（ラウンドを問わず。(a)(c) はユーザーが対象を名指ししていないラウンド限定 — 名指しの PR/MR・commit range はローカルの作業状態と無関係。当てる順は (c) → (a) → (b)）。いずれも turn-end の定型テンプレは使わない — 指摘を1件も持たないので、出力は `git add`・コミット・対象指定のいずれかを促す1行のみ。
     - (c) **未追跡ファイルがある** — 本スキル自身の生成物（step 6 が書く `docs/plans/` と作業用の `.tmp/`）を除いて未追跡ファイルがあるなら、その未追跡は既定ターゲットにも `<base>...HEAD` にも現れずどのストリームにも渡らないので、`git add`（`<base>..HEAD` にコミットがあるならコミットまで）してから再実行するようユーザーへ促して終える（base へ直接コミットせず branch + PR）。生成物を除外するのは、それらは常に未追跡で残りうるため — 除外しないと自分の出力で毎ラウンド止まる。
     - (a) **混在** — 和を表せる単一トークンが無いので（Target diff バレット）、レビューへ進まず、未コミット分をコミットしてから再実行するようユーザーへ促して終える（base へ直接コミットせず branch + PR）。
     - (b) **対象が空** — commit range なら `git diff --numstat <対象>`、PR/MR なら「MR 差分」（`~/.claude/references/git-hosting/<hosting>.md`）、既定ターゲットなら `git diff --numstat` と `git diff --numstat --staged` の両方、これが0行なら対象が空。そのまま回すと全ストリームがゼロ件を返し「収束」と誤報するので、対象の指定をユーザーへ確認して終える。
  4. **Round ≥2 の carry**: 前ラウンドのサイドカー `cr-fixes-<name>-r<N-1>.review-state.yaml`（`docs/plans/` 直下に無ければ配下のサブディレクトリから探す）を読み、`rejected`（step 2 が該当分を落とす）・`filed_issues`（再起票しない）・`verified_facts`（step 6 が書き継ぐ。carry する範囲は `review-state-schema.md` の共通規則）をこの実行へ carry する。

  | `<base>..HEAD` のコミット | working tree の変更（`git diff --numstat` と `git diff --numstat --staged` の両方が空なら「無」） | 対象 |
  |---|---|---|
  | 無 | 有 | 既定ターゲット |
  | 有 | 無 | `<base>...HEAD` |
  | 無 | 無 | 対象が空 → 停止条件 (b) |
  | 有 | 有 | 混在 → 対象を作らない・停止条件 (a) |

- **Bias guard:** if THIS session authored the changes under review, tell the user that re-invoking after /clear gives an unbiased review (author-reviews-author); offer to continue anyway if they prefer.

### 2. Review (inline — no subagent fan-out)

Run all three streams in this session. **Returning from a Skill invocation is not a yield point — even when its output reads like a completion.** 進め方:

1. 各ストリームの指摘は compact な作業リストとしてだけ出す: 先頭にそのストリームの echo 行（echo 契約を持つストリームのみ — 下の各バレット）、続いて指摘1件につき、下の merge が要る事実を載せた1行。見出しは「（途中経過 — 続行中）」。この作業リストは各ストリーム自身の出力契約に優先する（例外は本スキルが受領を確認する行 — 下の各ストリーム・バレットが指定する）。
2. 次のストリームは**その作業リストと同じ assistant メッセージ内で**起動する。
3. 3本目のあと、この step の merge/dedupe に続き、そのまま step 3 へ — ただし指摘ゼロで `open_needs_user` に持ち越すエントリも無いときはラウンドをここで終える（この step 末尾の guarded exit）。

各 step が明示する exit・停止、step 1 の bias guard、末尾の turn-end 出力だけが本スキルの yield point で、いずれも出力の直前に marker を消す（`keep-turn.md`）。同一セッションで pass を再開しうるもの（step 1 の bias guard、step 4 のユーザー判断停止）は同文書の 作り直す のとおり。The three streams:

- **`standard-code-review` via the Skill tool** — Round 1 passes `high`, every later round passes `medium` (issue #19 の方針: Round 1 で lens C/D を必ず通し、再レビューは medium に固定する). The user may request another effort at invocation. No `--fix` / no `--comment`. **対象の渡し方は `~/.claude/references/review-target.md` の 対象トークン に従う**（渡す条件は step 1 の Target diff バレット）。返ってきた1行目の `対象: <range>` が渡したものと一致することを確認する — 不一致は引数が解釈されていない印で、effort の echo と同じガード。
  - **Invoke it ONCE; never spawn your own review subagents on top** — it already fans out internally, scaled to effort, so the extra pass re-reads the same files for no added coverage.
  - **Confirm the echoed effort matches what you passed** — anything else (a higher tier such as `xhigh`, or a value you did not pass) means the arg was not parsed; re-invoke with the effort as its own token.
- **`deep-code-review` via the Skill tool** — runs inline; it reads its own language packs and covers codebase-wide spreading, root cause, design ripple, regression tests, and silent-failure idioms (lens F). Its broad sweeps may delegate to read-only `code-explorer`; fold in concise summaries only. **Pass `修正案なし`** — findings come back without a per-finding fix, so step 4's design pass is not anchored to a symptomatic patch before it starts. **Confirm the returned 概要 節 carries `修正案: 省略（呼び出し元指定）`** — its absence means the argument was not parsed, the same guard the `effort` echo gives. 対象も同じ引数列で渡す（概要 `- 対象:` は自由記述のプレースホルダ）。
- **`simplification-review` via the Skill tool** — runs inline; the over-engineering / deletion lens the other two don't own. **`修正案なし` を引数に渡す**（deep-code-review と同じ理由）。対象を併せて渡すかは step 1 の Target diff バレットの条件に従う（既定ターゲットのときは渡さない）。返ってきた1行目の `対象:` / `修正案:` が渡したものと一致することを確認する。続く simplification-review 手順 2 の 捨てた: 行 の有無も確認する（無ければ手順 2 を経ていない）。このストリームの作業リスト行は返ってきた指摘の1行要約でよい。

**Normalize before merging**（`~/.claude/references/finding-criteria.md` が正本 — ID 接頭辞の割り当ては同ファイルの 共通フィールド 節 の `ID の採番は生成側ごと` の段落に従う）:

1. **Merge & dedupe**: 3ストリームを合流し、**findings list — facts only**（重大度 / 場所の逐語アンカー / 何が問題か / 根拠 / Measurement — 持つ指摘だけ）へ重複排除して `F1, F2, …` に振り直す（出所の接頭辞はここで捨てる — 内訳は turn-end の件数行が持つ）。この ID が step 3 の verdict を突合するキー。2ストリームが同じものを別の重大度で挙げたときは高い方を残す。
2. **step 1 で carry した `rejected` をここで当てる** — carry が効くのはここ: 既存エントリが該当する指摘を落とす。REFUTED エントリ（事実誤認）も `見送り（ユーザー判断: …）` エントリも `測定不一致: …` エントリ（手順 3 が書く）も同じ扱い。例外は2つ、いずれも「エントリが依って立つ前提を今ラウンドの差分が無効化した」とき:
   - REFUTED エントリの反証が載っていたコードが変わった → その指摘は落とさず、step 3 の裁定へ通常どおり回す。測定不一致 エントリは、測定対象の文書が今ラウンドの差分で変わったとき同じ — 落とさず手順 3 で測り直す。
   - 見送り の理由が崩れた → CONFIRMED verdict だけでは再提案しないという規則の、REFUTED と同じ escape。落としも黙って再採用もせず、サイドカーの `open_needs_user` へ `reason: NEEDS-USER クラス` で記録し、turn-end の `要ユーザー判断` に数える。提示地点は他の `open_needs_user` エントリと同じ route: step 4 が設計判断で停止するターンならそこ、さもなければサイドカー経由で plan-refinement-loop。

   落とした分は turn-end の `除外の内訳` 行で報告する。`却下` には決して入れない — あれは step 3 の裁定結果。
3. **Measurement を実行する** — 対象・実行・照合・n の規則は `~/.claude/references/measurement-run.md`（step 1 で Read 済み）。一致・不一致とも `verified_facts` へ記録し、不一致で落とした指摘は `rejected` へ `reason: 測定不一致: <期待出力と生出力の食い違いを一言>` でも記録する（どちらも step 6 が書き出し、次ラウンドは手順 2 の carry で落とす。手順 5 の 指摘ゼロ exit と step 3 の empty-change-set exit ではサイドカーが書かれず失われ、次ラウンドで再測定になる — 許容済み）。同文書 対象 節 が落とすと定める指摘もここで落とし、不成立形式で `verified_facts` へ記録する（`rejected` には書かない）。落とした指摘は turn-end の `除外の内訳` 行で報告し、`却下` には数えない。全件落ちて残りゼロなら手順 5 の 指摘ゼロ exit。
4. **Do not draft solutions yet**: いま書いた解法は step 4 の設計パスを対症療法へ係留する。
5. **指摘ゼロ → 報告して停止（プランファイル無し）** — ただし `open_needs_user` に永続化が要るエントリがあるときを除く。step 3 の empty-change-set exit と同じガードで、理由も同じ: この exit は step 6 の手前で止まるので、手順 2 で記録した再オープンの 見送り が未作成のサイドカーごと消える。該当エントリがあるときは通常どおり step 3 へ進む（step 3 の exit もガード済み — そのエントリはラウンドを empty-change-set exit からも staged convergence からも外し、step 6 へ届いて empty-change-set variant でプランを書く）。無ければ報告: Round 1 「修正不要」 / Round ≥2 「前ラウンドの修正を再検証、指摘ゼロ — 収束」。

### 3. Adjudicate (finding-verifier)

Read `~/.claude/references/adjudication.md` and `~/.claude/references/issue-filing.md` now — the out-of-scope criterion and the vote counting are first needed here.

Group the non-Nit findings — plus any Nit whose action is filing an issue — by root-cause/file cluster and launch **`finding-verifier`** (`Agent` tool, `subagent_type: finding-verifier`), one per cluster, in parallel. Pass ONLY: the findings in that cluster (場所 / 問題 / 根拠, each with its ID) and the relevant code file paths — **never the carried `rejected`**: past verdicts bias the only path that can drop a finding **in adjudication**, and step 2 already applied that carry when it built the findings list, never through the verifier. Its verdict contract lives in the agent file — don't restate it. **Nit-level findings (style/wording, no behavioral impact) skip adjudication.** The one exception is a Nit whose action is filing an issue: filing requires CONFIRMED (step 5), so it is adjudicated with the rest.

Verdict handling:

- **CONFIRMED** → goes into the design pass. Record the in-repo anchors from `CHECKED` for use as the plan's 場所.
- **REFUTED / UNVERIFIABLE** → 票の数え方・追加する検証者の人数・1件単位で回すこと・決着しなかったときの行き先は `~/.claude/references/adjudication.md` が正本（この step の冒頭で Read 済み）。本スキル固有の部分だけをここに書く: 生きた指摘は step 4 の設計へ送る。価値・スコープ・リスク姿勢の問いとしてここから `open_needs_user` へ回すものは `reason: NEEDS-USER クラス` で記録する。`open_needs_user` へ回った問いの提示経路は step 2 の Normalize 段落の route rule に従う。**却下はこの経路だけ**で、他の drop path は step 2 の carried `rejected` と、同 step の Normalize 手順 3 が `measurement-run.md` の 対象・実行・照合 節 のとおり落とすものの2つ。その3つの外で落とさない。
- **SOURCES** (externally confirmed facts) → append to the sidecar's `verified_facts`.

**Empty-change-set exit:** when adjudication leaves nothing for step 4 — no CONFIRMED finding, no Nit that skipped adjudication — and no `open_needs_user` entry needs persisting, report via the 全件却下 variant of the 指摘ゼロ / 全件却下 template and stop: no plan file. Dropping this round's `rejected` records and step 3 `SOURCES` (`verified_facts`) is safe — the next round still carries round `N-1`'s sidecar; a re-found finding is re-adjudicated, a dropped fact re-verified. When anything needs persisting — with zero CONFIRMED that can only be an `open_needs_user` entry — this exit does not fire; the route from there is the one step 2's guard describes.

**Staged convergence（Critical/Major ゼロで収束）:** 上の Empty-change-set exit で止まらなかったラウンドは、次の2つがともに成り立つとき収束（(2) は step 4 の結果を含むので、判定が確定するのは step 6 でサイドカーを書く時点）: (1) 裁定を終えて CONFIRMED に Critical も Major も無い（CONFIRMED が Minor だけ・裁定を飛ばした Nit だけのときを含む）。(2) step 6 でサイドカーへ書く `open_needs_user` が空 — この step で持ち越すエントリも step 4 の振動ガードが生むエントリも数える。散文仕様への冗長・可読性指摘は事実上無限に供給され、指摘ゼロは漸近目標にしかならないため、Minor/Nit だけのラウンドを精査→再レビューのもう1周へ回さない（plan-refinement-loop と同じ収束条件）。収束はラウンドの進み方を変えない — step 4（Minor ゲートを含む）→ step 5 → step 6 へ通常どおり進む。変わるのは出口だけ: このプランは**最終プラン** — 実装すれば終わりで、plan-refinement-loop の精査も実装後の再レビューも掛けず、turn-end は 収束（Critical/Major ゼロ）template。条件 (2) が要るのは、この turn-end が plan-refinement-loop へ案内せず、持ち越した問いを読む主体が消えるため。

### 4. Design one change set (batched)

Take **all CONFIRMED findings plus the Nits that skipped adjudication** as a single problem statement — 「この指摘群を解決する」 — and design the change set once:

- Solve by **root cause**, not per finding. Several findings sharing a cause get **one** change item.
- **同型横展開（必須）**: 各変更項目を確定する前に、その項目が直す問題の同型を機械的に見つける grep パターンを設計し、レビュー対象の差分に限らず repo のソース全体（生成物は除く — ビルド出力・`.tmp/`・本スキル自身の生成物である `docs/plans/`（配下のサブディレクトリ含む））へ当てる。各ヒットの内容を確認し、同じ欠陥が実際に成立している箇所だけを同じ変更項目の 場所 に列挙して一括適用の設計にする — 同一クラスの問題をラウンドをまたいで逐次発見させない。同型でないヒット（その箇所では意図して正しい）は除外し、doctrine 姿勢 節 の除外ヒット例外が定める形で記録する（場所 に載せてよいのはこのスイープのヒットだけ）。使ったパターンは step 6 のプランの 検証 節 に同じ範囲指定込みで再実行手順として書く — 実装後の再 grep が横展開漏れの検出になり、同じ箇所が返っても実装セッションと次ラウンドの本スイープがその場で除外済みと突合できる。**Round ≥2** では各ヒットの内容確認の前に、既存全ラウンドのプラン `docs/plans/**/cr-fixes-<name>-r*.md` の 検証 節 の `除外:` 行を読み、同じ箇所が今ラウンドもヒットしてその箇所が step 1 で解決した今ラウンドの対象差分に現れていなければ内容確認を繰り返さず除外を引き継ぎ、今ラウンドのプランの 検証 節 にもその箇所の除外行を書く — 複写でなく、今ラウンドのスイープが自分で書く除外行と同じ形にする（<箇所> は今のファイルから取り、<理由> が元のプランの項目番号など今ラウンドに無いものを指すなら今ラウンドで成立する語へ書き直す）。
- Prefer reuse and consolidation over new code (the ponytail ladder applies to the plan itself).
- Determine the **implementation order** and flag conflicts (does change A break change B's premise?).
- **振動ガード（Round ≥2）**: 変更セットを確定する前に、既存全ラウンドのプラン `docs/plans/**/cr-fixes-<name>-r*.md` の 修正内容 節を読み、各変更項目と突合する。変更項目が過去のラウンドのプランが指示した修正（実装済みかは問わない）を元へ戻すもの（A→B→A — 置換された側の文言・構造を復元する）なら、その変更項目は自動採用しない: 変更セットから外し、その項目が束ねる指摘すべて（CONFIRMED と裁定を飛ばした Nit）を `open_needs_user` へ `reason: エスカレートした反復` で記録して turn-end の 要ユーザー判断 に数える。提示経路は step 2 の Normalize 段落の route rule に従う。
- A design choice with several defensible answers that only the user can settle (scope, risk posture, business context) is **not decided here, and the round stops here**:
  1. `finding-criteria.md` の クラス 節 のゲートを1つずつすべて当てる（step 1 で Read 済み）。ゲートを通らず AUTO-FIXABLE に落ちたものは、決めて 確定済みの判断 に1行残す。
  2. ゲートを生き残った問いが1つでもあれば、**それを避けて設計せず、プランも書かない** — 片方の案でプランを書くと、どんな 推奨 行よりも強くユーザーをその案へ係留する。下の 要ユーザー判断（プラン未作成）template でターンを終える。
  3. 回答は同じセッションに返ってくる — step 4 の設計へ畳み込み、step 5 以降を続行する。
  4. step 6 がプランを書くとき、各回答を 確定済みの判断 の1行（`（ユーザー判断: …）` マーカー付き）として記録する。実施しない の回答は**加えて** doctrine のとおりサイドカーの `rejected` エントリにする。この2箇所の外に回答の書き先は無い。

  `open_needs_user` へ回ったエントリはラウンドを止めない（どのエントリがそれかは `~/.claude/references/review-state-schema.md` の同キーの producer 行）。サイドカーが書かれるのは step 6 なので、それまでエントリはこの停止地点の他の情報と同じくセッションの文脈にある。**このターンでユーザーが答えたエントリは設計判断の回答と同じ形で記録し、step 6 がサイドカーを書く前に `open_needs_user` から出す** — キーに残すと、決着済みの問いを plan-refinement-loop がもう一度きくことになる。指摘の実在を確定した回答は、設計判断の回答と同じく step 4 の設計へ畳み込む — 修正内容 項目（場所 / 変更 / 理由）とその 検証 行、加えて 目的 節 の findings list の1行になり、確定済みの判断 の1行だけにしない。
- A confirmed finding that the change set deliberately leaves out — typically a behavior-preserving quality improvement outside this diff's theme — is **not dropped**: it becomes an out-of-scope item and is filed per step 5. Never silently omit a confirmed finding. A Nit that turns out to be out of scope only here is adjudicated now — filing requires CONFIRMED — and then filed the same way.
- **A Minor finding gets an explicit in-or-out call, one at a time** (`~/.claude/references/finding-criteria.md` の 重大度 節): make it **after** the change items above are designed, never before — the call is the same scope question the bullet above asks (is this change set where the fix belongs?), never a severity question. It stays when its fix belongs to a change item already being written — a shared root cause, or a line or two inside that item — **or when it belongs to this diff's theme on its own**. Otherwise it leaves as an out-of-scope item and is filed per step 5. Critical and Major findings are outside this gate — their in-or-out call stays the bullet above and `~/.claude/references/issue-filing.md`.

Every CONFIRMED finding must be traceable to exactly one outcome: a change item, a filed issue, `open_needs_user` の1エントリ、または 実施しない と答えられたときの 確定済みの判断 1行。

**Don't over-invest here.** The design deep-dive is plan-refinement-loop's `solution_quality` dimension, run by a fresh investigator over the whole change set — never self-review this design pass; a converged round's final plan (step 3) skips the refinement pass but gets no self-review in its place either.

### 5. File out-of-scope items as issues (now, not later)

What counts as out of scope, and how to file it — adjudication gate, dedupe, CLI choice, body handling, and the `filed_issues` record — all live in `~/.claude/references/issue-filing.md` (read at step 3). Follow it.

### 6. Write the plan and sidecar

Write `docs/plans/cr-fixes-<name>-r<N>.md` per the doctrine template.

- 目的 節 = 「以下の指摘を解決する」＋**この変更セットが解決する指摘**の1行要約リスト（何が載るかの正本は doctrine 姿勢 節 の例外 — 起票済みの指摘は載らない）。
- 修正内容 節 = step 4 の変更項目を実装順で。
- **変更項目ゼロでも永続化が要るとき**（`open_needs_user` エントリがある、または全 CONFIRMED がスコープ外で今ラウンド起票された）: step 3 の exit は発火せず、プランは書く。目的 節 は findings list を持たず1行だけ — 未決の 要ユーザー判断 があればそれ、無ければ中立の「このラウンドは変更セットを持たない」。修正内容 節 は「（このラウンドの変更セットは空 — <その理由>）」の1行、検証 節 は「（変更が無いため検証項目なし）」の1行。

Write `docs/plans/cr-fixes-<name>-r<N>.review-state.yaml` with `document_type: implementation-plan`. **Keys, seed rules, and formats live once in `~/.claude/references/review-state-schema.md` — Read it before writing the sidecar.**

- **`open_needs_user`**: step 4 で提示したエントリが書き出されるのはここ（提示とは別ターン）なので、**提示した `options` / `pivot` を付ける** — schema の「キーの不在が未提示の印」に従う。
- **Round ≥2**: carry the previous round's `rejected` / `filed_issues` / `verified_facts` entries in alongside this round's, or Round N+1 loses them.（carry の範囲は `review-state-schema.md` の共通規則）

## Safety rails

- **No code fixes, no commits.** This skill writes the plan, its sidecar, and issue bodies in `.tmp/`; the only outward-facing action is filing out-of-scope issues (step 5).
- Subagents are read-only and scoped: `finding-verifier` (the listed findings only) and `code-explorer` summaries inside deep-code-review's broad sweeps. The `general-purpose` reader-behavior run of a `Measurement` in step 2's Normalize is not structurally read-only — what to pass and why is `~/.claude/references/measurement-run.md` の 実行 節. Never delegate the reviews or the design pass.

## Turn-end output

以下のブロックは書式の例示であって、出力をフェンスで囲む指定ではない。1つ目の 次の手順 は、出力する行だけを 1. から連番で採番する。

**指摘あり（プラン作成）:**
```
## Round <N> レビュー完了 — 実装プラン作成
- 指摘 X 件（standard-code-review: n / deep-code-review: m / simplification-review: p）
- 裁定: CONFIRMED a / 却下 b　要ユーザー判断: c（= step 6 でサイドカーへ書き出す open_needs_user の件数）
- <落とした指摘があるときのみ: 除外の内訳 <件数> 件: <指摘の一行要約> ← <理由（一致した rejected エントリ / 期待出力と生出力の食い違い / 実行しなかった理由）> を `  - ` のサブバレットで1件ずつ>
- 変更セット: <項目数> 件（根本原因でまとめた結果 X 件 → <項目数> 件）
- 別課題として起票: #<N>, #<M>（重複スキップ: k 件）
- → docs/plans/cr-fixes-<name>-r<N>.md

次の手順（各ステップで /clear 推奨 — フレッシュな文脈が精度とトークンの両方に効きます）:

1. /clear → 「docs/plans/cr-fixes-<name>-r<N>.md を plan-refinement-loop で精査して」（ユーザー判断待ちの c 件はここで提示されます）
<変更セットが 1 件以上、または 要ユーザー判断が 1 件以上のときのみ: 2. /clear → 「docs/plans/cr-fixes-<name>-r<N>.md を実装して」（変更セット 0 件で出したときは、1. の精査で 修正内容 項目が生まれたときだけ実施）>
3. /clear → 本スキルを再実行（再レビュー）
```

**要ユーザー判断（プラン未作成）:**
```
## Round <N> — 判断が必要です（プランはまだ書いていません）
- 指摘 X 件（standard-code-review: n / deep-code-review: m / simplification-review: p）
- 裁定: CONFIRMED a / 却下 b　要ユーザー判断: c（= このターンで提示した問いの総数）
- <落とした指摘があるときのみ: 除外の内訳 <件数> 件: <指摘の一行要約> ← <理由（一致した rejected エントリ / 期待出力と生出力の食い違い / 実行しなかった理由）> を `  - ` のサブバレットで1件ずつ>

<finding-criteria.md の 質問の出し方 節 の書式で、未決の問いを1件ずつ（`[U1] <場所> — <問い>` から `判断が分かれる点:` まで。step 1 で Read 済み）>

<`open_needs_user` へ回した問い（step 3 由来の未決着、step 3 由来の価値・スコープ・リスク姿勢の問い、carry した 見送り の前提が今ラウンドの差分で崩れたもの、振動ガードが検出した逆操作）も同じ形式でここに並べる — 中断したターンではここが唯一の提示地点。サイドカーへ書き出されるのは step 6 なので、この時点ではまだファイルに無い>

回答をこのまま返してください（例:「[U1] は B」）。受け取り次第、変更セットの設計とプラン作成を続けます。

⚠️ ここで `/clear` するとレビュー結果と裁定は失われます（サイドカーにもプランにも保存していないため、本スキルを最初から回し直しになります）。
```

**指摘ゼロ / 全件却下:**
```
## ✅ <指摘ゼロ / 全件却下>（Round <N>）
- <Round 1: 修正不要です。 / Round ≥2: 前ラウンドの修正に問題なし — 収束しました。 / 全件却下: 裁定にかけた指摘 X 件はすべて事実誤認と判明 — 修正不要です。却下の内訳: <指摘の一行要約> ← <反証> を X 件ぶん `  - ` のサブバレットで1件ずつ>
- <落とした指摘があるときのみ: 除外の内訳 <件数> 件: <指摘の一行要約> ← <理由（一致した rejected エントリ / 期待出力と生出力の食い違い / 実行しなかった理由）> を `  - ` のサブバレットで1件ずつ>
```

**収束（Critical/Major ゼロ）:**
```
## ✅ 収束 — Critical/Major ゼロ（Round <N>）— 最終プラン作成
- 指摘 X 件（standard-code-review: n / deep-code-review: m / simplification-review: p）
- 裁定: CONFIRMED a / 却下 b
- <落とした指摘があるときのみ: 除外の内訳 <件数> 件: <指摘の一行要約> ← <理由（一致した rejected エントリ / 期待出力と生出力の食い違い / 実行しなかった理由）> を `  - ` のサブバレットで1件ずつ>
- 変更セット: <項目数> 件（根本原因でまとめた結果 X 件 → <項目数> 件）
- <起票が 1 件以上のときのみ: 別課題として起票: #<N>, #<M>（重複スキップ: k 件）>
- → docs/plans/cr-fixes-<name>-r<N>.md
- <変更セットが 1 件以上のときのみ: 次の手順: /clear → 「docs/plans/cr-fixes-<name>-r<N>.md を実装して」>

Critical/Major ゼロのため収束です。<変更セットが 1 件以上のときのみ: このプランを実装すれば終わりにしてよく、精査（plan-refinement-loop）も再レビューのラウンドも不要です。>
```
