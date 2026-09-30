---
name: plan-writing
description: Write a NEW implementation plan file under docs/plans that a fresh session can implement without this conversation. Sources are the user prompt, an issue (body + comments), and findings gathered in the conversation. Written by the main session, never a subagent. Not for reviewing or refining an existing plan (use plan-refinement-loop).
when_to_use: '"プランを書いて", "実装計画を立てて", "プランファイルを作って", "write an implementation plan", "draft a plan"'
user-invocable: false
---

# plan-writing

main セッションが書く。subagent へ委譲しない（プランはこの会話の産物）。

## 手順

1. `~/.claude/references/plan-doctrine.md` と `~/.claude/references/review-criteria.md`（質問の出し方）を読む。
2. 起点を集める。issue 起点なら `~/.claude/references/git-workflow.md` の hosting 表「issue を見る」で本文とコメントの両方を読む。
3. アンカーを接地する。プランが名指すファイル・関数・行は Read / Grep / Glob で実在を確かめ、ライブラリは Context7 で確かめる。
4. 未確定の判断は推測で埋めず、選択肢ごと 要ユーザー判断 節へ載せる。
5. `docs/plans/<name>.md` を doctrine の構成で書く。`<name>` は issue 起点なら `issue-<N>`、それ以外は主題から短く付ける。検証した外部事実・実測結果は 決定記録 の 事実 へ。
6. 完了出力。

## 完了出力

- プランのパス。
- 要ユーザー判断 の問い（review-criteria の 質問の出し方）。
- スコープ外指摘（未起票）: あれば 1 行ずつ。起票はしない。
- 次の手順: plan-refinement-loop で精査。
