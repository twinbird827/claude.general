---
name: code-review-to-plan
description: Review a code diff (uncommitted changes, commit range, or PR/MR ref) with standard-code-review + deep-code-review + simplification-review run serially by one code-review-runner subagent, adjudicate Critical/Major via finding-verifier, then write ONE implementation plan under docs/plans that resolves the confirmed findings — never fix immediately. Out-of-scope confirmed findings are filed as issues on the spot. For a one-off review use standard-code-review directly; for refining an existing plan use plan-refinement-loop.
when_to_use: '"指摘をプラン化して", "実装後レビュー", "レビュー結果をプランにまとめて", "review into a plan"'
---

# code-review-to-plan

単一パス。レビュー → 裁定 → プランを 1 本書く。コードを修正しない。commit しない。外向きの動作は起票だけ。

## entry

1. `~/.claude/references/plan-doctrine.md`、`~/.claude/references/review-criteria.md`、`~/.claude/references/git-workflow.md` を読む。
2. 対象を決める。
   - 引数に対象トークンがあればそれ（review-criteria の レビュー対象引数）。
   - 無ければ作業状態で決める。`<base>..HEAD` にコミットがあり working tree に変更が無い → `<base>..HEAD`。コミットが無く working tree に変更がある → 既定（トークンを渡さない）。両方ある（混在）、両方無い（空）→ 止まる。
     - 未追跡ファイルがあれば止まる。`docs/plans/` 配下と `.tmp/` は除く。
   - `<base>` は git-workflow の 規則 節 分岐元の解決 で決める（親ブランチがあればそれ、無ければ base）。
3. `<name>` を current branch 名から作る（`A-Z a-z 0-9 -` 以外を `-` へ）。detached HEAD なら止まる。
4. Round 番号 N = `docs/plans/` 配下の `cr-fixes-<name>-r*.md`（サブディレクトリまで再帰）の番号の最大 + 1、無ければ 1。N ≥ 2 なら番号最大のものを前ラウンドのプランとする。

## レビュー

1. code-review-runner を 1 回起動する（`run_in_background: false`）。依頼文: 対象トークン（既定なら「既定」）、effort（N = 1 は `high`、それ以外は `medium`）。
2. 返った findings を前ラウンドの 決定記録 の 判断 と照合する（doctrine の 判断行の書式）。
3. 行動予測型の指摘は Measurement を打ち、結果を 事実 行として控える。

## 裁定

1. Critical / Major を finding-verifier で裁定する（review-criteria の 票勘定。独立した指摘は並列起動可）。
2. Minor / Nit は裁定しない。
3. スコープ外（対象差分が持ち込んだのでない問題）の指摘は、重大度を問わず finding-verifier で裁定し、CONFIRMED なら git-workflow の 起票 でその場で起票する。deep-code-review の 横展開 が返した同型箇所はスコープ外に含めない（変更セット 2 で 変更 へ取り込む）。

## 変更セット

1. CONFIRMED の Critical / Major を根本原因で束ね、変更項目にする。
2. 各変更項目を確定する前に、同型を機械的に見つける grep を repo 全体へ当て、成立する箇所と deep-code-review の 横展開 が返した同型箇所を同じ項目の 変更 に足す。同型でない除外ヒットは `除外: <逐語アンカー> — <理由>` で 事実 に控える。
3. Minor は変更項目の設計後に 1 件ずつ in / out を判定する（スコープの問い）。out は 裁定 3 のスコープ外として扱う。
4. 設計判断（スコープ・リスク姿勢）が残る指摘、票で決まらなかった指摘、ユーザーの判断と衝突する指摘は、片方の案で書かず 要ユーザー判断 へ選択肢を逐語で書く。

## プラン

1. `docs/plans/cr-fixes-<name>-r<N>.md` を doctrine の構成で書く。
2. 決定記録 は、前ラウンドのプランの 決定記録 全行を写してから、このラウンドの 事実（Measurement、除外ヒット、起票番号）と 判断（REFUTED の却下、見送り）を足す。
3. 変更項目がゼロでも 要ユーザー判断 があればプランを書く。変更項目も問いも無ければプランを書かず `指摘なし` を報告する。
4. ユーザー判断待ちで止まるときも、ここまでのプランを書いてからターンを終える。

## ターンの終わり

1. 出力: `Round <N> / CONFIRMED: Critical <c> Major <m> / Minor <n> Nit <t> / 起票 <i> 件`、プランのパス、要ユーザー判断 の問い（review-criteria の 質問の出し方）、次の手順。
   - 通常: plan-refinement-loop で精査 → 新セッションで実装 → 実装後に code-review-to-plan。
   - CONFIRMED の Critical / Major がゼロ: 実装で終わり。再レビューは案内しない。
