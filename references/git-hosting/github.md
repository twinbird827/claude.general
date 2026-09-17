# GitHub（gh）のコマンド表

`git remote -v` の URL ホスト名に `github` を含むときの表。gh 2.76.2 で確認。本文はすべて `-F <file>` で渡す。state の値: 開いている = `OPEN`、マージ済み = `MERGED`。

| 操作 | コマンド | 注意 |
|---|---|---|
| MR を見る | `gh pr view [<N>] --json number,state,baseRefName,headRefName,headRefOid --jq '.number, .state, .baseRefName, .headRefName, .headRefOid'` | 引数なしは current branch の PR を state 問わず引く（OPEN 優先）。push 直後の 1 回目は `headRefOid` が push 前の sha を返すことがある（実測で再現）ので、sha 不一致を停止条件にする前にもう 1 回引く |
| MR 本文を取得 | `gh pr view <N> --json body --jq .body` | |
| MR 差分 | `gh pr diff <N>` | 本文は取らない（レビューは差分に対して行う） |
| MR 一覧 | `gh pr list` | |
| MR 作成 | `git push -u origin HEAD && gh pr create -B <target> -t "<title>" -F .tmp/<file>` | push を分けるのは gh の自動 push 判定に依存しないため。`-t` と `-F` を両方渡す（欠くと対話モードに落ちる） |
| MR 本文を置換 | `gh pr edit <N> -F .tmp/<file>` | |
| MR をマージ | `gh pr merge <N> --merge --delete-branch` | `--delete-branch` は remote と**ローカル**の branch を消す。head branch を checkout 中のときだけ PR の base branch へ切り替える。`--auto` は付けない（既定は同期マージ） |
| issue を見る | `gh issue view <N> && gh issue view <N> --comments` | `--comments` 単体は非 TTY で本文を落としコメントだけを返す（コメント 0 件なら出力も空）ので 2 回に分ける |
| issue 検索 | `gh issue list --search "<keyword>"` | |
| issue 作成 | `gh issue create -t "<title>" -F .tmp/<file>` | |
| issue へ追記 | `gh issue comment <N> -F .tmp/<file>` | `gh issue edit` は本文を置換するので追記に使わない |
| issue を閉じる | `gh issue close <N>` | closing keyword で閉じられないときの手動クローズ（`~/.claude/references/mr-workflow.md` の 規則 節） |
