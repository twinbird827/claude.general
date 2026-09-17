# Review Target（レビュー対象引数の規約）

差分レビュー3スキル（standard-code-review / deep-code-review / simplification-review）が対象引数を解釈する規約の正本。呼び出し元（code-review-plan-loop / plan-refinement-loop）もこの既定を前提にする。各スキルの SKILL.md はここを参照し、値を再掲しない。

- **対象トークン** — commit range・PR/MR ref・ファイルパスのいずれか1つ。スキル固有の引数（`effort` / `修正案なし` 等）を除いた残りの先頭トークンを対象とする。
- **既定**（対象トークンが無いとき）— ローカルの未コミット+staged 差分（`git diff` と `git diff --staged` の和）。
- **PR/MR ref** — 差分のみを取得し、説明本文は取らない。取得コマンドは `~/.claude/references/git-hosting/<hosting>.md` の「MR 差分」、hosting の決め方は `~/.claude/references/mr-workflow.md` の 規則 節。
