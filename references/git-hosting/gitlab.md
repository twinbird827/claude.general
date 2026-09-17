# GitLab（glab）のコマンド表

`git remote -v` の URL ホスト名に `gitlab` を含むときの表。glab 1.86.0 で確認。本文を argv へ載せるコマンドは、長い本文では Windows の引数長上限で `Argument list too long` になるため、本文は `glab api` の `--field <name>=@<file>` でファイルから読ませる（`@` はファイル読みなので上限に載らない）。`"$(cat …)"` のコマンド置換は permission 照合を外すので使わない。本文以外の文字列値は `--raw-field` で渡す（`--field` は `123` のような値を数値へ変換する）。番号と URL が要る作成系は `jq -r '.iid, .web_url'` で番号と URL だけ残し、本文の要らない応答は `> /dev/null` へ捨てる。API エラー時は `iid` / `web_url` が `null` で出て終了コードは `jq` のもの（0）になるので、`null` を失敗として扱う。state の値: 開いている = `opened`、マージ済み = `merged`。

| 操作 | コマンド | 注意 |
|---|---|---|
| MR を見る | `glab mr view [<N>] -F json \| jq -r '.iid, .state, .target_branch, .source_branch, .sha'` | 引数なしは current branch の MR を state 問わず引く |
| MR 本文を取得 | `glab mr view <N> -F json \| jq -r .description` | 既定の text 出力はタイトル・state 等のメタ行を含み本文を汚染する |
| MR 差分 | `glab mr diff <N>` | 本文は取らない（レビューは差分に対して行う） |
| MR 一覧 | `glab mr list` | |
| MR 作成 | `git push -u origin HEAD && glab api projects/:fullpath/merge_requests --method POST --raw-field source_branch=<source> --raw-field target_branch=<target> --raw-field title="<title>" --field description=@.tmp/<file> \| jq -r '.iid, .web_url'` | `glab mr create` は本文を argv に載せる `--description` しか持たない（1.86.0 に `--description-file` は無い）。`<source>` は current branch 名を直書きする（`$(git branch --show-current)` は表冒頭のとおり使わない）。push を先に分けるのは `github.md` と同じ形（未 push の branch では API が失敗する） |
| MR 本文を置換 | `glab api projects/:fullpath/merge_requests/<N> --method PUT --field description=@.tmp/<file> > /dev/null` | `glab mr update -d "$(cat …)"` は表冒頭の引数長上限に掛かる（2026-09-10 に MR !89 の本文 32.5KB で実測）。応答は 30KB 級になる。GitLab は本文を CRLF へ正規化して返す（CE 17.10.4）。突合の diff には `--strip-trailing-cr` が要る |
| MR をマージ | `glab mr merge <N> -d -y --auto-merge=false` | `--auto-merge` の既定は true で、pipeline のある project では予約だけして `opened` のまま戻る。`-d` は remote の source branch を削除する。ローカル branch は残る |
| issue を見る | `glab issue view <N> --comments` | 本文に続けて `comments/notes:` 以下にコメントを出す。system note（`changed the description` 等）は出ない |
| issue 検索 | `glab issue list --search "<keyword>"` | |
| issue 作成 | `glab api projects/:fullpath/issues --method POST --raw-field title="<title>" --field description=@.tmp/<file> \| jq -r '.iid, .web_url'` | `glab issue create` は本文を argv に載せる `-d` しか持たない（1.86.0 に本文をファイルから読むフラグは無い） |
| issue へ追記 | `glab api projects/:fullpath/issues/<N>/notes --method POST --field body=@.tmp/<file> > /dev/null` | `glab issue note` は本文を argv に載せる `-m` しか持たない（1.86.0）。`glab issue update -d` は本文を置換するので追記に使わない |
| issue を閉じる | `glab issue close <N>` | closing keyword で閉じられないときの手動クローズ（`~/.claude/references/mr-workflow.md` の 規則 節） |
