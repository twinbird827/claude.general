# パイプ自動承認 Hook（pipe-stage-permissions.sh）撤去の記録

撤去日: 2026-08-19 / 対象バージョン: Claude Code 2.1.234（VS Code 拡張同梱）

## 何を撤去したか

- `hooks/pipe-stage-permissions.sh`（PreToolUse / matcher: Bash）
- `settings.template.json` の `hooks.PreToolUse` から上記の定義（`rtk hook claude` は残す）
- `knowhow/PRETOOLUSE_HOOK.md`（導入手順書）

導入理由は「パイプ付きコマンドは各ステージが `permissions.allow` に載っていても ask になる」（[Issue #29967](https://github.com/anthropics/claude-code/issues/29967)）。この前提が本体側で解消された。

## 撤去の根拠（実測）

Hook を `settings.json` から外した状態で、**default モード**（auto モードでは deny 以外が全部自動承認されるため判定不能）で実行:

| コマンド | 結果 |
|---|---|
| `ls \| head -3` | プロンプト無しで実行 |
| `git status \| head -5` | プロンプト無しで実行 |
| `cat CLAUDE.md \| grep RTK \| head -3` | プロンプト無しで実行 |
| `rtk proxy ls -la \| head -3` | プロンプト無しで実行 |
| `ls && git status` | プロンプト無しで実行 |
| `foobarbaz-not-allowed \| head -3` | **プロンプトが出た**（ゲートが生きている対照） |
| `ls \| dd --version` | deny（エラーが `dd --version` と2段目のみを名指し = セグメント単位の判定） |
| `ls && dd --version` | deny（エラーは全体を名指しするが、段ごとに判定される点は同じ — 末尾の追測） |

> ℹ️ 表の `rtk proxy ls -la | head -3` 行の「プロンプト無し」は当時存在した `Bash(rtk proxy ls:*)` allow が前提。その allow は撤去済みのため、再測定時は素形（`ls -la | head -3`）で測るか、allow を一時的に戻して測る。

バイナリ側にも、パイプ区間ごとに permission を評価して集約する実装がある:

```js
// 1つでも deny → 短絡 deny、全部 allow → allow、それ以外 → ask
if (every(D => D.behavior === "allow"))
    return { behavior: "allow", decisionReason: { type: "subcommandResults", ... } };
```

## 撤去時に判明した hook 自体の欠陥

`split_stages()` の `((i++))` は i=0 のとき exit status 1 を返し、`set -euo pipefail` により最初の1文字を処理した時点でサブシェルが即死していた。結果 `STAGES` が空 → `all_match=true` のまま **無条件 allow**。

つまりこの hook は導入当初から判定が動いておらず、`deny` / `ask` に置いたガードもパイプや `&&` を挟めば素通りする状態だった。「プロンプトが消えた」のは判定が効いたからではなく全許可していたため。撤去する以上この修正は不要（MR !46 はクローズ）。

## 他PCでの手動作業

`settings.json` は gitignore 対象なので pull では変わらない。各PCで以下を手で消す:

```json
{
  "matcher": "Bash",
  "hooks": [
    { "type": "command", "command": "bash ~/.claude/hooks/pipe-stage-permissions.sh", "timeout": 5 }
  ]
}
```

削除後は Claude Code の再起動が必要（hook はセッション開始時にスナップショットされる）。

## 再導入を検討する場合

本体の挙動が退行したら、上の表と同じ手順で **default モード**で再測定すること。auto モードは deny 以外を自動承認するため、プロンプトの有無で allow を観測できない。

## `&` と改行も段として割られる（2026-09-15 追測）

対象バージョン: Claude Code 2.1.238。`Bash(dd:*)` deny をプローブに auto モードで実測（deny は auto モードでも自動承認されないため、モードを切り替えずに観測できる）。`ls` 段だけなら通る形へ `dd --version` を後続させ、deny が出れば permission リストがその区切りで段を割っている。

| コマンド | 結果 |
|---|---|
| `ls & dd --version` | deny |
| `ls` ＋改行＋ `dd --version` | deny |

段を割っていなければ、`ls & dd --version` 全体は deny 規則 `Bash(dd:*)`（前方一致は `dd` まで）に一致せず deny にならない。deny が出た以上、`&` と改行も撤去の根拠の表にある `|` `&&` と同じく段として割られている。
