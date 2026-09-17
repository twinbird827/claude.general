# Claude Code 開発環境の構築手順（Windows）

新 PC にこのリポジトリ（`~/.claude`）を扱う環境を作る手順。本ファイルだけを手元に置き、上から順に実行する。`knowhow/` `RTK.md` `README.md` への参照は、Step 3 の clone 後にリポジトリ内で読む（リポジトリの説明と使い方は `README.md`）。

> ⚠️ 本手順はクリーンな PC での通し実行が未検証。次の新 PC で上から順に通し、ずれた箇所を直す。

---

## 📋 前提条件

| 項目 | 要件 |
|------|------|
| OS | Windows 10 (Build 19041以上) / Windows 11 |
| Claude.ai | Pro / Max サブスクリプション（認証に必要） |
| Node.js | LTS版 |
| Git | Git for Windows（Git Bash 含む） |
| Python / uv | Python 3.10 以上（3.13 推奨）と uv。Headroom 用（Step 6 で導入） |
| SearXNG | 共有 SearXNG `http://a11132-1:8888` へ HTTP 到達できること（Step 11 の mcp-searxng 用。無ければ オプション のセルフホスト） |
| Firecrawl | 共有 Firecrawl `http://a11132-1:3002` へ HTTP 到達でき、`.env` の `TEST_API_KEY` をサーバ管理者から受け取れること（Step 11 の firecrawl-mcp 用） |

---

## 🚀 セットアップ手順

### Step 1: Git for Windows のインストール

[https://git-scm.com/download/win](https://git-scm.com/download/win) からインストーラーをダウンロードして実行。

インストール時のオプションは基本デフォルトでOK。以下のみ確認：
- ✅ Git Bash Here（コンテキストメニュー）
- ✅ Git from the command line and also from 3rd-party software

インストール確認（PowerShellで）：
```powershell
git --version
# git version 2.x.x.windows.x
```

---

### Step 2: GitLab CLI（glab）のセットアップ

```powershell
winget install -e --id GLab.GLab
```

> ⚠️ winget でインストールしても PATH が自動で通らない既知の問題がある。  
> PowerShellを再起動後に確認し、通っていなければ手動で追加する。

```powershell
# 確認
glab --version

# コマンドが見つからない場合は以下でPATHを追加
$glabPath = "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
[System.Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";$glabPath", "User")
$env:PATH += ";$glabPath"

# 再確認
glab --version
```

GitLabアカウントで認証する：

#### 1. Personal Access Token の作成

ブラウザで以下のURLにアクセスする：  
**https://gitlab.able-biott.jp/-/user_settings/personal_access_tokens**

以下の設定でトークンを作成する：

| 項目 | 設定値 |
|------|--------|
| Token name | `glab-cli`（任意） |
| Expiration date | 任意（空欄で無期限） |
| Scopes | ✅ `api`　✅ `write_repository` |

「Create personal access token」をクリックし、表示されたトークン（`glpat-xxxx...`）を**必ずコピーしておく**（ページを離れると二度と表示されない）。

> ℹ️ このトークンは `glab` CLI で使用する。

#### 2. glab ログイン実行

```powershell
glab auth login --hostname gitlab.able-biott.jp
```

対話形式で以下の質問が表示される：

```
? What GitLab instance do you want to log into?
→ GitLab Self-hosted Instance を選択

? GitLab hostname:
→ gitlab.able-biott.jp （自動入力されていればそのままEnter）

? API hostname:
→ gitlab.able-biott.jp （そのままEnter）

? How would you like to login?
→ Token を選択

? Paste your authentication token:
→ 手順1でコピーしたトークンを貼り付け

? What domains does this host use for the container registry and image dependency proxy?
→ そのままEnter（デフォルトでOK）

? Choose default git protocol:
→ HTTPS を選択

? Authenticate Git with your GitLab credentials?
→ Yes を選択

? Choose host API protocol:
→ HTTPS を選択
```

#### 3. 認証確認

```powershell
glab auth status
```

以下のように `gitlab.able-biott.jp` がすべて `✓` であればOK：

```
gitlab.able-biott.jp
  ✓ Logged in to gitlab.able-biott.jp as yourname (C:\Users\yourname\AppData\Local\glab-cli\config.yml)
  ✓ Git operations for gitlab.able-biott.jp configured to use https protocol.
  ✓ API calls for gitlab.able-biott.jp are made over https protocol.
  ✓ REST API Endpoint: https://gitlab.able-biott.jp/api/v4/
  ✓ GraphQL Endpoint: https://gitlab.able-biott.jp/api/graphql/
  ✓ Token found: **************************
```

> ⚠️ **トークンの変更だけなら** `glab auth login --hostname gitlab.able-biott.jp` を再実行すればOK。既存のホストブロックが上書き更新される。

> ⚠️ `gitlab.com` のエントリが残っていてエラーになる場合は config.yml を直接編集して削除する：
> ```powershell
> notepad "$env:LOCALAPPDATA\glab-cli\config.yml"
> ```
> `gitlab.com:` のブロックを丸ごと削除して保存する。`gitlab.able-biott.jp` のブロックは残す。

> ⚠️ config.yml のホストブロックを手動で削除して `hosts:` が空になってしまった場合、再ログインしてもブロックが生成されないことがある。その場合は **config.yml ごと削除してからやり直す**：
> ```powershell
> Remove-Item "$env:LOCALAPPDATA\glab-cli\config.yml"
> glab auth login --hostname gitlab.able-biott.jp
> ```
> なお、削除後の再ログインで `gitlab.com` のエントリが復活することがあるので、上記の手順で再度削除する。

---

### Step 3: このリポジトリをクローン

> ⚠️ 既に `%USERPROFILE%\.claude` が存在する場合は先に退避する

```powershell
# 既存の .claude を確認
Test-Path "$env:USERPROFILE\.claude"

# 存在する場合は退避
Rename-Item "$env:USERPROFILE\.claude" "$env:USERPROFILE\.claude.bak"

# クローン
git clone https://gitlab.able-biott.jp/manifacture/claude-general.git "$env:USERPROFILE\.claude"
```

退避した `.claude.bak` の内容を確認し、必要なファイルがあれば `settings.template.json` 等に移行後、削除してOK。

---

### Step 4: Node.js のインストール

[https://nodejs.org/](https://nodejs.org/) から **LTS版** をダウンロードしてインストール。

インストール確認（PowerShellを**再起動**してから）：
```powershell
node --version
npm --version
```

> ⚠️ Node.js インストール後は必ずPowerShellを**一度閉じて再起動**すること（PATHを反映させるため）

> ⚠️ `npm` コマンドでセキュリティエラーが出る場合は [トラブルシューティング: npm がセキュリティエラーで実行できない](#npm-がセキュリティエラーで実行できない) を参照

---

### Step 5: Claude Code のインストール

```powershell
irm https://claude.ai/install.ps1 | iex
```

インストール確認（PowerShell を再起動してから）：
```powershell
claude --version
```

> ℹ️ native installer は `%USERPROFILE%\.local\bin\claude.exe` に置き、以後はバックグラウンドで自動更新される。`npm install -g @anthropic-ai/claude-code` は使わない（Node.js 22 以上を要求し、npm グローバルが書き込み不可だと自動更新が止まる）。Node.js（Step 4）は MCP サーバーの `npx` 起動に使う。

---

### Step 6: Python と uv のインストール

Headroom（Step 8）が Python 3.10 以上と uv を要求する。

```powershell
winget install -e --id Python.Python.3.13
winget install -e --id astral-sh.uv
```

> ⚠️ winget ではマイナーバージョンまでの指定が必要。新しいバージョンがリリースされた場合は `winget search Python.Python` で確認すること。

インストール確認（PowerShellを再起動してから）：
```powershell
python --version   # Python 3.x.x
uv --version
```

---

### Step 7: RTK 節 — インストールと hook 除外設定

`settings.template.json` の `PreToolUse` hook（`rtk hook claude`）が Bash tool のコマンドを `rtk <cmd>` へ書き換え、出力を圧縮する。

#### 1. rtk バイナリの配置

[rtk の releases](https://github.com/rtk-ai/rtk/releases) から `rtk-x86_64-pc-windows-msvc.zip` を取得し、`rtk.exe` を PATH の通った場所（例: `%USERPROFILE%\.local\bin`）へ置く。

> ℹ️ 導入確認（`rtk --version` / `rtk gain`）と同名 crate との見分け方は `RTK.md` の Installation Verification 節にある。`rtk init -g` は不要。

#### 2. 生出力が要るコマンドを hook の書き換えから除外する

rtk は生出力が要るコマンドの出力を無警告で落とす・整形するため、hook 側で除外する。設定ファイルはリポジトリ外の `%APPDATA%\rtk\config.toml` にあり、PC ごとに反映が要る。

> ⚠️ `rtk config --create` は既存の config.toml を確認なしで既定値に上書きする（0.43.0 で実測。`APPDATA` 環境変数の差し替えも無視して実パスへ書く）。次の `Test-Path` が `True` を返したら `--create` は実行せず、そのまま編集へ進む。

```powershell
Test-Path "$env:APPDATA\rtk\config.toml"
```

`False` のときだけ、設定ファイルを作る：

```powershell
rtk config --create
```

編集：

```powershell
notepad "$env:APPDATA\rtk\config.toml"
```

`[hooks]` の `exclude_commands` を次にする：

```toml
[hooks]
exclude_commands = ["ls", "find", "git diff", "git log", "git show", "glab mr diff", "gh pr diff"]
```

確認：

```powershell
Get-Content "$env:APPDATA\rtk\config.toml"   # 上の exclude_commands 行と一致すること
rtk hook check "git diff HEAD~1"   # No rewrite for: git diff HEAD~1
rtk hook check "git status"        # rtk git status
```

**一致規則と permission の関係:**
- 一致は単語単位の前方一致（除外語の直後は行末か空白で、語の途中では一致しない）
- `&&` / `||` / `;` は各段に個別に効く（`ls && git status` は `ls && rtk git status`）。パイプは先頭段だけが判定され、先頭段が除外なら行全体が書き換わらない（`ls | rg foo` は無書き換え）
- hook が無出力になる行は通常の `permissions` 判定に戻るので `settings.json` の allow が要る（上の一致規則で書き換えが起きない行、rtk がラッパを持たないコマンド、コマンド置換・ファイルへのリダイレクト（`/dev/null` と `2>&1` は除く）・heredoc を含む行などが該当。`ls -la` と `findstr x` がその例）。書き換えを返す行でも、書き換え前の各段すべてが allow 規則に一致しない限り自動承認は付かない
- 上の `rtk hook check` は書き換え可否だけを見るので、この無出力条件の確認には使えない — ファイルへのリダイレクトを含む行を「書き換えあり」と答える（0.43.0 で実測）
- 除外の一覧は上の `exclude_commands` ブロックが正本。増減するときは正本のブロックを先に直し、そのうえで各PCの config.toml を更新する。allow は除外の有無と独立に要る（除外を外しても消さない）ので、`settings.template.json` と各PCの `settings.json` を同じ内容に保つ（permission 判定に実際に使われるのは `settings.json` 側）

---

### Step 8: Headroom（コンテキスト圧縮 proxy）の導入と常駐化

`settings.template.json` の `env.ANTHROPIC_BASE_URL` が `http://127.0.0.1:8787` を指すため、Step 9 でテンプレートをコピーした瞬間から全セッションが proxy 前提になる。**Step 9 より前に**本 Step で proxy を常駐化しておく。トレードオフ・トラブルシューティング・撤去手順は `knowhow/headroom-setup.md`。

1. インストール — `knowhow/headroom-setup.md` の §2 を実行する（`uv tool install` と constraints。`headroom --version` が出れば OK）
2. 常駐化 — 同 §4-1（VBS ランチャー作成）→ §4-2（`Register-ScheduledTask`）→ §4-3（`Start-ScheduledTask`）を実行する
3. 確認：

```powershell
headroom doctor
```

`proxy ✓` であれば OK。`claude routed` はこの時点では `settings.json` が無いため fail のままでよい（Step 11 の末尾で 0 failure を確認する）。

> ℹ️ 同 §3-3（`headroom mcp install`）は Step 11 で行う。§3-0（proxy の手動起動）は常駐タスクが落ちたときの復旧用で、ここでは要らない。

---

### Step 9: テンプレートから settings.json を作る

クローン直後は `settings.json` が存在しないため、テンプレートをコピーして初期化する：

```powershell
Copy-Item "$env:USERPROFILE\.claude\settings.template.json" "$env:USERPROFILE\.claude\settings.json"
```

> ⚠️ このコピーで `PreToolUse` hook（`rtk hook claude`）と `env.ANTHROPIC_BASE_URL`（Headroom proxy）が有効になる。Step 7・8 を飛ばしていると、最初の Bash tool 呼び出しで hook が失敗し、次の起動で `API Error: Unable to connect to API (ConnectionRefused)` になる。

> ℹ️ 以降、テンプレートが更新された場合（`git pull` 後）は差分を確認してマージする：
> ```powershell
> # 差分を確認
> diff (Get-Content "$env:USERPROFILE\.claude\settings.template.json") (Get-Content "$env:USERPROFILE\.claude\settings.json")
>
> # テンプレートで上書き（CLI自動追記分は消えるので注意）
> Copy-Item "$env:USERPROFILE\.claude\settings.template.json" "$env:USERPROFILE\.claude\settings.json"
> ```

---

### Step 10: Claude Code の初回認証

```powershell
claude
```

初回起動時にブラウザが開き、Claude.ai へのログインとアカウント連携を求められる。  
Claude.ai にサインインして認証を完了させる。

認証確認（Claude Code内で）：
```
/status
```

`Logged in as: yourname@example.com` と表示されればOK。

---

### Step 11: MCP サーバーの登録

`--scope user`（`-s user`）で `~/.claude.json` に登録する。`settings.json` の `mcpServers` は Windows 環境では動作しないため使わない。

```powershell
claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp@latest
claude mcp add searxng -s user --env SEARXNG_URL=http://a11132-1:8888 -- npx -y mcp-searxng
claude mcp add firecrawl-mcp -s user --env FIRECRAWL_API_KEY=<TEST_API_KEY> --env FIRECRAWL_API_URL=http://a11132-1:3002 -- npx -y firecrawl-mcp
headroom mcp install
```

- `context7` — ライブラリドキュメント参照用。プロンプトに `use context7` を添えると最新ドキュメントを参照する
- `searxng` — Web 検索と URL 本文取得。`SEARXNG_URL` の決め方と到達確認は `knowhow/mcp-searxng-setup.md` の §2・§3-1（同一 LAN なら `http://a11132-1:8888`）
- `firecrawl-mcp` — JS ページの取り直しと複数ページ収集。`<TEST_API_KEY>` は共有 Firecrawl サーバの `.env` の `TEST_API_KEY` と同じ値で、サーバ管理者から受け取る（`knowhow/firecrawl-searxng-setup.md` §2-2）
- `headroom` — 圧縮マーカーの原文取り戻し用 `headroom_retrieve`（`knowhow/headroom-setup.md` §3-3）

確認：

```powershell
claude mcp list      # context7 / searxng / firecrawl-mcp / headroom が ✔ Connected
headroom doctor      # 0 failure（claude routed ✓）
```

> ℹ️ 初回は npx のダウンロードに時間がかかる。Failed のときは少し待って `claude mcp list` を再実行する。

---

### Step 12: plugin の導入と日次更新

`settings.template.json` の `extraKnownMarketplaces` は Step 10 の初回起動で marketplace を自動登録する。しかし `enabledPlugins` に挙げた plugin は外部ソース（GitHub）のため自動では**インストールされない**（Claude Code 2.1.195 以降。未導入のまま起動すると「not installed」と `claude plugin install` の案内が出る）。手で入れる：

```powershell
# enabledPlugins が正本（キー = <plugin>@<marketplace>）。件数も一覧もここだけで管理する。
$tpl = Get-Content "$HOME\.claude\settings.template.json" -Raw | ConvertFrom-Json
$tpl.enabledPlugins.PSObject.Properties | Where-Object { $_.Value } | ForEach-Object { claude plugin install $_.Name }
claude plugin list   # settings.template.json の enabledPlugins と同じものが出ること
```

> ⚠️ `claude plugin install` が marketplace を知らないと言うときは、Step 10 の `claude` 起動を挟んでいない。`claude plugin marketplace add DietrichGebert/ponytail` のように `settings.template.json` の `extraKnownMarketplaces` の `repo` を渡して手で登録する。

`knowhow/plugin-update.sh`（marketplace の更新と全 plugin の更新）を毎日 07:00 に走らせるタスクを登録する（非昇格で可）：

```powershell
$action = New-ScheduledTaskAction -Execute 'C:\Program Files\Git\bin\bash.exe' -Argument '-lc "$HOME/.claude/knowhow/plugin-update.sh"'
$trigger = New-ScheduledTaskTrigger -Daily -At 07:00
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName 'claude-plugin-update' -Action $action -Trigger $trigger -Principal $principal -Force
```

確認：

```powershell
Start-ScheduledTask -TaskName 'claude-plugin-update'
Get-ScheduledTaskInfo -TaskName 'claude-plugin-update'   # 実行が終わったら LastTaskResult が 0
```

---

## 🔧 オプション

- [Firecrawl + SearXNG のセルフホスト](knowhow/firecrawl-searxng-setup.md) — WSL2 上に Firecrawl と SearXNG のコンテナを立てる。Step 11 が指す共有サーバ（`a11132-1`）が使えるなら不要
- [Playwright MCP](knowhow/playwright-mcp-setup.md) — ブラウザ操作（クリック・ログイン後の画面が要るときだけ）

---

## ⚠️ トラブルシューティング

### `claude` コマンドが見つからない
```powershell
# 実体を確認（native installer の配置先）
Test-Path "$env:USERPROFILE\.local\bin\claude.exe"

# True なのに見つからないなら User PATH に追加し、PowerShell（VS Code も）を再起動する
$currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
[Environment]::SetEnvironmentVariable('PATH', "$currentPath;$env:USERPROFILE\.local\bin", 'User')
```

### Git for Windows のパスが検出されない

**方法A：環境変数に追加（推奨）**
```powershell
[System.Environment]::SetEnvironmentVariable("BASH_PATH", "C:\Program Files\Git\bin\bash.exe", "User")
```
PowerShellを再起動して反映させる。

**方法B：`settings.template.json` に追加（git管理）**
```json
{
  "env": {
    "BASH_PATH": "C:\\Program Files\\Git\\bin\\bash.exe"
  }
}
```
> ⚠️ 全PCで同じパスであればこの方法でOK。PCごとに異なる場合は方法Aを使用する。

### npm がセキュリティエラーで実行できない

PowerShell の実行ポリシーがデフォルト（`Restricted`）のままだと、`npm.ps1` スクリプトがブロックされる。
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
実行後、PowerShell を再起動して `npm --version` が通ることを確認する。

### 認証エラー（`/status` で未認証と表示される）
```powershell
claude auth logout
claude auth login
```
