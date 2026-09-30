---
name: plan-refinement-loop
description: Iteratively review and harden an implementation plan (the 6-section plan under docs/plans) until a fresh plan-investigator sweep finds no Critical/Major. Adjudicates via finding-verifier, applies AUTO-FIXABLE fixes in place, routes NEEDS-USER to the user. Not for writing new plans (plan-writing), not for reviewing code (code-review-to-plan), not for specs or design docs.
when_to_use: '"プランを徹底調査して", "プランを精査して指摘を反映", "investigate this plan thoroughly", "review and fix my plan"'
---

# plan-refinement-loop

## 役割

- orchestrator（main）は調査も裁定も自分でしない。調査は plan-investigator、初回スイープの simplification-review は code-review-runner、裁定は finding-verifier。例外は Measurement の実行だけ。
- 対象は plan-doctrine の 6 節構成を持つ実装プランだけ。それ以外の文書は対象外と報告して止まる。
- subagent へレビュー履歴を渡さない。渡すのはプロジェクト文脈、reference のパス、プランのパスだけ。決定記録 節はプラン本文の一部として読まれる。

## entry

1. `~/.claude/references/plan-doctrine.md` と `~/.claude/references/review-criteria.md` を読む。
2. 対象プランを決める。引数のパス、無ければ会話中のプラン。

## スイープ

スイープ番号 k を 1 から数える。

1. fresh plan-investigator を 1 本起動する（`run_in_background: false`）。k = 1 のときだけ、同じメッセージで code-review-runner も `run_in_background: false` で起動する。依頼文は対象トークンにプランのパス、`スキル: simplification-review` の行。返った指摘に `PI-<n>` を振り、SR 指摘とあわせてこのスイープの指摘にする。
2. 行動予測型の指摘は Measurement を打ち、結果を 事実 行としてプランの 決定記録 へ書く。
3. Critical / Major を finding-verifier で裁定する（review-criteria の 票勘定。独立した指摘は並列起動可）。Minor / Nit は裁定を飛ばす。
4. 反映する。
   - REFUTED → 決定記録 の 判断 に却下を 1 行（反証つき、AI 判断）。
   - AUTO-FIXABLE（CONFIRMED、または Minor / Nit）→ プランを Edit で直す。既存の判断と衝突するなら doctrine の 判断行の書式 に従う。
   - NEEDS-USER、または票で決まらなかったもの → 要ユーザー判断 節へ選択肢を逐語で書く。
5. 終了判定。
   - 要ユーザー判断 節に問いがある → Awaiting user。
   - CONFIRMED の Critical / Major がゼロ → Complete。このスイープの Minor / Nit は手順 4 で当て済みなので再スイープしない。
   - k = 5 → Stopped。未解決を重大度つきで報告し、`/clear` して再開するよう勧める。
   - それ以外 → k + 1 で手順 1 へ。

## ユーザーの回答を受けたとき

1. 回答を 決定記録 の 判断 へ 1 行（ユーザー判断 マーカー）で移し、必要なら 修正内容 に項目を足し、要ユーザー判断 から消す。
2. 次のスイープへ。
3. 回答無しで再開されたときは、要ユーザー判断 節の選択肢を逐語で再提示し、Awaiting user のまま止まる。

## ターンの終わり

Awaiting user / Complete / Stopped のときだけターンを終える。

出力: `状態: <Awaiting user|Complete|Stopped> / スイープ: <k> / CONFIRMED: Critical <c> Major <m> / Minor <n> Nit <t>`、要ユーザー判断 の問い（review-criteria の 質問の出し方）、次の手順（Complete なら「新セッションで実装 → 実装後に code-review-to-plan」）。
