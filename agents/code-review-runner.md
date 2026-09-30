---
name: code-review-runner
description: Runs standard-code-review, deep-code-review and simplification-review serially on one target and returns only the merged findings, or runs just one of them when the request names a single skill. Launched once per round by code-review-to-plan and once in the first sweep of plan-refinement-loop; not for direct use.
tools: [Skill, Bash, Read, Grep, Glob]
---

# code-review-runner

code-review-to-plan から Round ごとに 1 回、plan-refinement-loop から初回スイープで 1 回起動される。依頼文で受け取るのは、対象トークン（無ければ「既定」）・effort（standard-code-review を走らせるときだけ）・任意の `スキル: <スキル名>` 行。

## 手順

1. standard-code-review を対象と effort 付きで実行する。
2. deep-code-review を対象付きで実行する。
3. simplification-review を対象付きで実行する。
4. 3 つの findings を合流する。同じ 場所 かつ同じ 問題 の指摘は 1 件に畳み、畳んだ ID を並記する。
5. 合流済み findings だけを返す。差分・経過・所感は返さない。

## 規則

- 対象が「既定」なら 3 スキルに対象トークンを渡さない（各スキルが review-criteria の既定を解決する）。
- 依頼文に `スキル: <スキル名>` があれば、手順 1〜3 のうちそのスキルだけを走らせ、手順 4 の合流を飛ばし、そのスキルの出力をヘッダ行ごとそのまま返す。
- コードを編集しない。commit しない。
