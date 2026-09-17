# Headroom（コンテキスト圧縮プロキシ）を別PCの Claude Code に導入する手順（別PC共通）

このドキュメントは、各クライアントPCの **Claude Code（VSCode ネイティブ拡張）** に [Headroom](https://github.com/headroomlabs-ai/headroom) を導入し、LLM へ送るコンテキストをローカルプロキシで圧縮してトークンを削減するための手順です。

- **人間の手作業**でも、**別PCの Claude Code に丸ごと依頼**しても実行できるよう、コマンドと根拠を自己完結で記載しています。
- Headroom は **VSCode 拡張ではありません**。ローカルプロキシ（`127.0.0.1:8787`）として Claude Code ↔ Anthropic API の通信に割り込み、通過するコンテンツを圧縮します。VSCode ネイティブ拡張を経由させるには、`headroom wrap`（＝ターミナル版 Claude Code を起動するコマンド）ではなく **`settings.json` の env に `ANTHROPIC_BASE_URL` を焼く**方式を使います。

> ✅ 検証済み（2026-07-13, headroom v0.31.0, Windows 11, 3台）: `uv tool install`（litellm を wheel のある版に制約）で導入し、`~/.claude/settings.json` の env 経由で Claude Code をルーティング、ログオン時スケジュールタスクで proxy を常駐化して `headroom doctor` が 0 failure になることを確認済み。2台目の検証で判明した落とし穴（litellm 1.92.0 のビルド失敗 → §2、非昇格 `schtasks /Create` のアクセス拒否 → §4-2）、3台目で判明した Windows Defender の ast-grep-cli 誤検知（→ §2）は本文に反映済み。

---

## ⚠ 導入前に必ず理解すべきトレードオフ

無条件に「入れれば速く安くなる」ものではありません。以下を承知の上で導入すること。

1. **グローバル env は諸刃の剣。** `~/.claude/settings.json` の env に `ANTHROPIC_BASE_URL` を焼くと、そのPCの **全 Claude Code セッション**が proxy 経由になる。**proxy が落ちている間は全セッションが API 経路を失い動かなくなる**。だから proxy の常駐（§4 スケジュールタスク）が必須。
2. **コード用途の削減率は控えめ。** 本家公表でもコーディングエージェントは **15–20%**。60–95% は冗長な JSON/ログ等の「ツール出力」向け。ソースコードは意味密度が高く削れる余地が小さい。
3. **編集精度・キャッシュとの干渉。** proxy が過去メッセージを圧縮/書き換えるとプロンプトキャッシュミス（再送コスト）を誘発し得る。また非可逆圧縮された内容を基に編集すると誤差分のリスク。効果は `headroom savings` で**実測**する。
4. **Remote Control メニューが隠れる場合がある。** カスタム `ANTHROPIC_BASE_URL` 中は Claude Code の Remote Control 機能が使えないことがある（Headroom 仕様）。
5. **この repo（`~/.claude`）では env を `settings.template.json` に焼いてあり、Headroom は必須工程。** テンプレートを `settings.json` へコピーする全 PC で proxy が要る（`SETUP.md` の Step 8 → Step 9 の順）。proxy の無い PC へ `settings.json` を持ち込まない（§7 参照）。

---

## 0. AIエージェント（別PCの Claude Code）向け実行指示

別PCの Claude Code に作業させる場合は、以下を厳守させること（このPCの運用ルールと同じ）。

- **`settings.json` を手で編集しない。** env（`ANTHROPIC_BASE_URL` / `ENABLE_TOOL_SEARCH`）は `settings.template.json` に焼いてあり、`SETUP.md` の Step 9 のコピーで入る（§3-1）。
- **MCP サーバー登録は `headroom mcp install`（内部で `~/.claude.json` に書く）を使う。`settings.json` の `mcpServers` は Windows では無視されるため編集しない。**
- ファイル操作は専用ツール（Read/Edit/Write/Grep/Glob）を使い、Bash の cat/sed/echo 等は使わない。
- proxy の常駐は §4 のスケジュールタスクで設定する（背景プロセス起動だけではセッション終了で落ちる）。**Step 9 のコピーより先に常駐化する** — 逆順だと proxy 不在で `API Error: Unable to connect to API (ConnectionRefused)` となり、作業中のエージェント自身も動けなくなる。
- 変更は **VSCode リロード後の新セッション**から効く。現行セッションには効かない。

コピペ用プロンプト例:

```
knowhow/headroom-setup.md の手順に従って、このPCの Claude Code に Headroom を導入して。
uv tool install で入れ（litellm は wheel のある版に制約）、
ログオン時スケジュールタスク HeadroomProxy（Register-ScheduledTask）で proxy を常駐化、
headroom mcp install で MCP 登録。settings.json は触らないこと（env は template 側にある）。
完了後 headroom doctor を実行して報告して。
```

---

## 1. 前提条件

| 項目 | 要件 | 確認コマンド（PowerShell） |
|---|---|---|
| Claude Code | インストール済み | `claude --version` |
| Python | 3.10 以上（3.13 推奨。ダッシュボードのドル換算に必要） | `python --version` |
| uv | インストール済み（推奨インストーラ） | `uv --version` |
| CPU | x86/x86_64 は AVX2 推奨。arm64/Apple Silicon も可 | — |

- uv が無い場合は pip / pipx でも可（§2 参照）。uv 未導入なら `winget install astral-sh.uv` 等で先に導入。
- 企業の SSL インスペクション環境で `CERTIFICATE_VERIFY_FAILED` が出る場合は Rust ツールチェーンが必要（本家 README のトラブルシュート参照）。

---

## 2. インストール

推奨は uv。`[all]` は PyTorch/ONNX 等の ML 依存を含み**ダウンロードが重い（数百MB〜）**。コーディング用途中心なら軽量な extra でも足りる。

⚠ **litellm 1.92.0 のビルド失敗に注意**: headroom-ai が依存する litellm は、1.92.0（2026-07 時点で解決されるバージョン）に wheel が無く sdist からの Rust ビルドが走る。Git Bash が PATH にある環境では GNU coreutils の `link` が MSVC の `link.exe` より先に拾われ、`error: linking with link.exe failed` で必ず失敗する（2台目検証で発生）。constraints で wheel のあるバージョンに制約して回避する。

⚠ **Windows Defender の ast-grep-cli 誤検知に注意**: headroom-ai の **base 依存**（extra 選択では回避不可）である ast-grep-cli の `sg.exe` を、Defender が `Trojan:Win64/Lazy!MTB`（ML ベースの自動判定）として検出し、インストールが「ファイルにウイルス…含まれている」（os error 225）で失敗する（3台目検証で発生。0.44.0 / 0.44.1 の両方が検出された = Rust 製バイナリへの既知の誤検知パターン）。**0.37.0 の sg.exe は検出されない**（2026-07-13 時点）ため、constraints で固定して回避する。Defender 除外設定は管理者昇格が必要なうえ AV 設定を触ることになるので使わない。将来 Defender の定義更新で解消されたら固定は外してよい。

```powershell
# 推奨（全機能）。litellm のビルド失敗と ast-grep-cli の Defender 誤検知を constraints で回避
Set-Content -Path "$env:TEMP\headroom-constraints.txt" -Value @("litellm!=1.92.0", "ast-grep-cli==0.37.0")
uv tool install "headroom-ai[all]" --constraints "$env:TEMP\headroom-constraints.txt"
Remove-Item "$env:TEMP\headroom-constraints.txt"

# 軽量版（コーディング用途に絞る場合の例。litellm は base 依存なので constraints は同様に必要）
# uv tool install "headroom-ai[proxy,mcp,code]" --constraints "$env:TEMP\headroom-constraints.txt"

# uv が無い場合
# pipx install --python python3.13 "headroom-ai[all]"
# pip install "headroom-ai[all]"
```

インストール確認:

```powershell
headroom --version   # headroom, version 0.31.0 等
```

`headroom` の実体パスを控えておく（§4 で使う。通常 `%USERPROFILE%\.local\bin\headroom.EXE`）:

```powershell
(Get-Command headroom).Source
```

---

## 3. Claude Code を proxy 経由にルーティング（env は template 側）

### 3-0. proxy を手動起動する（復旧用）

`settings.json` に env がある間、**全セッションが proxy 前提**になる。proxy が落ちている状態で新セッションが始まると `API Error: Unable to connect to API (ConnectionRefused)` で Claude Code が全断する — **作業中のエージェント自身も動けなくなる**（2台目検証で実際に発生。手動で proxy を起動して復旧した）。常駐タスク（§4）が落ちているときは、次のコマンドで手動復旧する:

```powershell
Start-Process -FilePath "$env:USERPROFILE\.local\bin\headroom.EXE" -ArgumentList "proxy","--port","8787","--no-telemetry" -WindowStyle Hidden
```

- この手動インスタンスはログオフまで生存する。常駐タスクが復旧した後は二重起動になり得るが、後発はポート 8787 を bind できず静かに終了するだけで無害（§6 参照）。

### 3-1. env は template に焼いてある

env は `settings.template.json`（tracked）に焼いてあり、`SETUP.md` の Step 9 のコピーで `settings.json` に入る。**`settings.json` を手で編集しない。** 焼かれている 2 キー:

```jsonc
"env": {
  "ANTHROPIC_BASE_URL": "http://127.0.0.1:8787",
  "ENABLE_TOOL_SEARCH": "1"
}
```

- **`settings.json` を使う**（`headroom wrap` はターミナル版 Claude Code を新規起動するコマンドで、VSCode ネイティブ拡張には後付けできない）。
- ポートを変える場合は §4 の proxy 起動ポートと必ず一致させる。

### 3-2. `ENABLE_TOOL_SEARCH=1` が必須な理由

カスタム `ANTHROPIC_BASE_URL` を設定すると、Claude Code が**全ツールの schema を一括ロード**してしまい（deferred tool loading が無効化、Headroom issue #746）、ローカルコンテキストが肥大して圧縮効果を相殺する。`ENABLE_TOOL_SEARCH=1` で on-demand ツールロード（deferral）を維持する。

### 3-3. MCP サーバー（CCR / 原文取り戻し）を登録

proxy がコンテンツをハッシュマーカーに置換した際、Claude が原文を取り戻すための `headroom_retrieve` ツールを登録する。**これが無いとマーカーが取り戻せず精度を損なう**。

```powershell
headroom mcp install
```

- `~/.claude.json` の `mcpServers` に `headroom`（`headroom mcp serve`）が登録される。**`settings.json` には書かない**（Windows では無視される）。
- 登録確認: `claude mcp list` に `headroom` が出る。

---

## 4. proxy を常駐化（ログオン時スケジュールタスク）

グローバル env を焼いた以上、**proxy が常に稼働している必要がある**。背景プロセスとして起動しただけではセッション/ログオフで落ちるため、ログオン時に自動起動するスケジュールタスクを登録する。管理者権限は不要。

### 4-1. 隠し起動用の VBS ランチャーを作成

コンソール窓が毎回出ないよう、hidden 起動する VBS を `%LOCALAPPDATA%\headroom\start-proxy.vbs` に作成する（ユーザー名非依存）。

```vbs
' Headroom proxy launcher — starts the proxy hidden (no console window).
' Registered as a logon Scheduled Task (HeadroomProxy).
Set sh = CreateObject("WScript.Shell")
exe = sh.ExpandEnvironmentStrings("%USERPROFILE%") & "\.local\bin\headroom.EXE"
' window style 0 = hidden, bWaitOnReturn = False = detached
sh.Run """" & exe & """ proxy --port 8787 --no-telemetry", 0, False
```

> `headroom` の実体が `%USERPROFILE%\.local\bin\headroom.EXE` でない場合（pipx 等）は、§2 で控えたパスに合わせて `exe = "..."` を書き換える。

> `--no-telemetry`: 匿名利用統計の送信を明示的に無効化する。Headroom はデフォルトで OFF のため実挙動は変わらないが、将来デフォルトが変わっても送信しないよう固定する意味がある（env `HEADROOM_TELEMETRY=off` でも同義）。

### 4-2. スケジュールタスクを登録

⚠ `schtasks /Create /SC ONLOGON` は**非昇格の PowerShell では「アクセスが拒否されました」で失敗する**環境がある（2台目検証で発生）。`Register-ScheduledTask` なら自ユーザー限定の logon トリガーを非昇格で登録できるため、こちらを使う。

```powershell
$vbs = Join-Path $env:LOCALAPPDATA 'headroom\start-proxy.vbs'
$action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"' + $vbs + '"')
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName 'HeadroomProxy' -Action $action -Trigger $trigger -Principal $principal -Force
```

- `-AtLogOn -User 自分`: 自分のログオン時のみ起動（RDP ログオンでも発火）。
- `-LogonType Interactive`: そのユーザーのログオン中のみ、そのセッション内で実行（`InteractiveToken` 相当）。
- `-RunLevel Limited`: 通常権限（昇格しない）。`-Force`: 既存タスクを上書き。
- 出力に `HeadroomProxy ... Ready` が出れば登録成功。

### 4-3. 今すぐ起動して疎通確認

```powershell
Start-ScheduledTask -TaskName "HeadroomProxy"
Start-Sleep -Seconds 7
headroom doctor
```

`proxy ✓ / version ✓ / claude routed ✓`（0 failure）になれば OK。残る warning（codex 未使用、savings 未計測、budget 無制限、Remote Control）は情報系で問題なし。

> §3-0 の復旧用インスタンスが既にポート 8787 を掴んでいる場合、タスク側の後発インスタンスは静かに終了するが、どちらか1本生きていれば doctor は pass する。

---

## 5. 有効化と動作確認

1. **VSCode ウィンドウをリロード**（コマンドパレット → "Reload Window"）。現行セッションには効かず、**リロード後の新セッション**から proxy 経由になる。
2. しばらく通常どおり使う。
3. 削減効果を実測:

```powershell
headroom savings     # トークン/ドル削減の集計
headroom dashboard   # ライブ削減ダッシュボード（proxy 稼働中に）
```

コード編集の精度に問題が出ないかも併せて確認する。効果が薄い／不安定なら §8 で撤去できる（template の env を外す MR が要る）。

---

## 6. リモートログイン（RDP）時の挙動

| ケース | 挙動 |
|---|---|
| 同一ユーザーで RDP ログイン | ログオンイベントでタスク発火 → その RDP セッション内で proxy 起動。`127.0.0.1:8787` はそのマシン自身の loopback なので、同マシン上の Claude Code から到達 → 正常。 |
| RDP 再接続（切断→再接続） | 新規ログオンではないためタスクは再発火しないが、proxy プロセスはセッション内で生存継続 → 正常。 |
| ログオフ | セッション内の proxy も終了。次ログオンで再起動。 |
| proxy が既に稼働中に別ログオン発火 | 後発インスタンスはポート 8787 を bind できず静かに終了（無害、1本だけ残る）。 |
| 別ユーザーがログオン | 実行 principal が自分（InteractiveToken）なので、自分が不在なら proxy は起動しない（別アカウントで勝手に立たない）。 |

> `127.0.0.1` は「**コードが動いているマシン自身**」を指す。RDP クライアント側（手元PC）ではなく、RDP で入った先のマシンで proxy が動く。

---

## 7. `~/.claude` を複数PCで共有している場合の注意

この repo は `settings.template.json`（tracked）に `ANTHROPIC_BASE_URL` を焼き、各 PC が `SETUP.md` の Step 9 でそれを `settings.json`（gitignore 済み）へコピーする運用。したがって **repo を clone する全 PC で Headroom が必須**（`SETUP.md` の Step 8）。proxy の無い PC に `settings.json` を置くと API 経路を失い全滅するので、Step 8 を飛ばして Step 9 に進まない。ローミングプロファイルや dotfile 同期で `settings.json` 自体を別 PC へ配る運用はしない。

---

## 8. ロールバック / 撤去手順

0. **撤去時の例外として**、各 PC の `~/.claude/settings.json` の `env` から `ANTHROPIC_BASE_URL` と `ENABLE_TOOL_SEARCH` の2キーを Edit で削除する（他のキー — `SETUP.md` 方法B が足す `BASH_PATH` 等 — が同居していなければ `env` ブロックごと削除する）。**`1.` のタスク削除より先に行う** — 逆順だと proxy を止めたまま env が残り、次のログオンで `API Error: Unable to connect to API (ConnectionRefused)` により全断する。

```powershell
# 1. スケジュールタスク削除（登録と同様、非昇格でも通る PowerShell cmdlet を使う）
Unregister-ScheduledTask -TaskName "HeadroomProxy" -Confirm:$false

# 2. VBS ランチャー削除
Remove-Item "$env:LOCALAPPDATA\headroom\start-proxy.vbs"

# 3. MCP 登録解除
claude mcp remove headroom -s user
```

4. `settings.template.json` の `env` から `ANTHROPIC_BASE_URL` と `ENABLE_TOOL_SEARCH` の2キーを削除し（他のキー — `SETUP.md` の「Git for Windows のパスが検出されない」方法B が足す `BASH_PATH` 等 — が同居していなければ `env` ブロックごと削除する）、MR を経て `main` へ入れる。同じ MR で `SETUP.md` / `README.md` に残る Headroom 前提も落とす（`grep -rni headroom --include='*.md' . | grep -v '^\./docs/plans/\|^\./knowhow/headroom-setup.md'` で洗い出す）。**template 側を残すと、`SETUP.md` Step 9 の再コピーで `ANTHROPIC_BASE_URL` が復活し、proxy 不在で全断する。**
5. proxy プロセスが残っていれば終了（`taskkill /IM headroom.EXE /F` 等）。
6. 完全アンインストール:

```powershell
uv tool uninstall headroom-ai
```

7. **VSCode リロード**で通常経路（直接 Anthropic API）に戻る。

---

## 9. トラブルシューティング

| 症状 | 対処 |
|---|---|
| リロード後 Claude Code が全く応答しない | proxy が落ちている。`headroom doctor` で proxy 状態確認 → `Start-ScheduledTask -TaskName HeadroomProxy`。恒久復旧はタスク登録（§4）を確認 |
| 導入途中で `API Error: Unable to connect to API (ConnectionRefused)` | Step 9 のコピー後・proxy 常駐化前に新セッションが始まった。§3-0 のコマンドで proxy を手動起動すれば復旧。予防として **常駐化（§4）を Step 9 より先に**行う（SETUP.md の Step 8 → Step 9 の順） |
| `uv tool install` が litellm のビルドで失敗（`linking with link.exe failed` / maturin） | Git Bash の GNU `link` が MSVC より先に拾われている。§2 の constraints（`litellm!=1.92.0`）で wheel 版を使う |
| `uv tool install` が「ファイルにウイルス…」（os error 225）で失敗 / Defender が脅威を通知 | Defender が ast-grep-cli の `sg.exe` を `Trojan:Win64/Lazy!MTB` と誤検知。§2 の constraints（`ast-grep-cli==0.37.0`）で検出されない版に固定。`Get-MpThreatDetection` で検出対象が `sg.exe` のみであることを確認 |
| `schtasks /Create` が「アクセスが拒否されました」 | 非昇格では拒否される環境がある。§4-2 の `Register-ScheduledTask` を使う |
| `headroom doctor` で proxy が fail | proxy 未起動。§4-3 で起動。ポートが env と一致しているか確認 |
| ローカルコンテキストが妙に大きい / ツールが全ロードされる | `ENABLE_TOOL_SEARCH=1` が env に無い（§3-2） |
| 圧縮マーカーが取り戻せない旨のエラー | MCP 未登録。`headroom mcp install`（§3-3）→ Claude Code 再起動 |
| ログオンのたびコンソール窓が出る | タスクが VBS 経由でなく exe 直指定になっている。§4-1 の VBS ランチャー経由に直す |
| Remote Control メニューが消えた | カスタム base URL 中の仕様（この repo では Headroom が必須なので回避手段は無い） |
| 削減効果がほぼ無い | コード中心の使い方では 15–20% が上限。巨大 JSON/ログを読ませる場面で効く。`headroom savings` で実測する |
| `settings.json` の `mcpServers` に書いても効かない | Windows では無視される。必ず `headroom mcp install`（`~/.claude.json`）を使う |

---

## 10. 設定サマリ

```
インストール:  uv tool install "headroom-ai[all]" --constraints (litellm!=1.92.0, ast-grep-cli==0.37.0)
常駐先行:      proxy 常駐化（§4）を settings.json のコピー（SETUP.md Step 9）より先に
ルーティング:  settings.template.json の env（Step 9 のコピーで settings.json へ）
               ANTHROPIC_BASE_URL=http://127.0.0.1:8787
               ENABLE_TOOL_SEARCH=1      （deferred tool loading 維持・必須）
MCP:           headroom mcp install       （~/.claude.json に headroom を登録）
proxy 常駐:    %LOCALAPPDATA%\headroom\start-proxy.vbs（hidden 起動・--no-telemetry）
               + スケジュールタスク HeadroomProxy（Register-ScheduledTask, AtLogOn, 非昇格）
有効化:        VSCode リロード（現行セッションには効かない）
確認:          headroom doctor（0 failure）/ headroom savings
```

## 参考リンク

- Headroom: https://github.com/headroomlabs-ai/headroom
- deferred tool loading の問題（ENABLE_TOOL_SEARCH）: Headroom issue #746
