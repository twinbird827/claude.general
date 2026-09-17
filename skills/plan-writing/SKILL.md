---
name: plan-writing
description: 'Write a NEW implementation plan file that a fresh session can implement without the current conversation as context. Crystallizes the requirements, investigation results, and user confirmations accumulated in this conversation into a self-contained plan (default location: docs/plans/). Do NOT use for reviewing or refining an existing plan — use plan-refinement-loop. Written by the main session, never a subagent (the plan is a product of this conversation context).'
when_to_use: '"プランを書いて", "実装計画を立てて", "プランファイルを作って", "write an implementation plan", "draft a plan".'
user-invocable: false
---

# Plan Writing

Produce a plan file a fresh session can implement without this conversation. Write it in the main session — never delegate to a subagent (requirements, investigation, and user confirmations live in this context and would be lost in re-transmission).

**All user-facing output in Japanese. Plan body in Japanese** (technical terms/code as-is).

## Procedure

1. **Read `~/.claude/references/plan-doctrine.md`** — the canonical posture, document type, anchor rules, writing rules, and template. Follow it; never restate it here.
2. **Ground the anchors** against the real codebase before writing them down (Read/Grep/Glob — paths, symbols, signatures actually exist). Check library/framework claims via Context7. A plan built on unverified anchors just shifts the cost to plan-refinement-loop's first sweep.
   - **issue 起点のときは本文とコメントの両方を読む**（本文だけで起案して失敗した実例: issue #19 → MR !79） — `~/.claude/references/git-hosting/<hosting>.md` の「issue を見る」で取る（hosting の決め方は `~/.claude/references/mr-workflow.md` の 規則 節）。
3. **Write the plan** per the doctrine template. 確定済みの判断 節: list the hard-to-reverse decisions settled in this conversation. 起案中に出る残余は2系統に分けて扱う:
   - **未確定の判断** — never guess it. Carry each into step 4's sidecar as `open_needs_user`（`reason: 未確定`）, with the `options` / `pivot` keys of the question you are about to present, and present it in the completion output in the 質問の出し方 節 format of `~/.claude/references/finding-criteria.md`（Read it when there is at least one open question; 推奨は書かない）.
   - **スコープ外指摘**（pre-existing defect, follow-up refactor surfaced while drafting）— never plan text — **this skill writes nothing to the tracker**, and nothing here hands it off — whether it gets filed is the user's call. List it on the completion output's スコープ外指摘（未起票） line so the user sees it, and keep it out of the sidecar (`open_needs_user` is for open questions only).
4. **Write the sidecar** `<plan>.review-state.yaml` (always, even when nothing external was verified) with `document_type: implementation-plan`. **Keys, seed rules, and formats live once in `~/.claude/references/review-state-schema.md` — Read it before writing the sidecar.**

## Completion output

以下のブロックは書式の例示であって、出力をフェンスで囲む指定ではない。

```
## プラン作成完了: <path>
- ユーザー確認点: <下記のとおり。1 件も無ければ「なし」>
- 検証済み外部事実: <N> 件を <plan>.review-state.yaml に seed（無ければ「なし」）
- スコープ外指摘（未起票）: <一行要約のリスト、無ければ「なし」>
- 次: 「プランを徹底調査して」で plan-refinement-loop による精査を開始できます。

<未確定の判断が 1 件以上のときのみ: 質問の出し方 節 の書式で1件ずつ（`[U1] <場所> — <問い>` から `判断が分かれる点:` まで）>
```
