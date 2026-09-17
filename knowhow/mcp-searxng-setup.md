# SearXNG 用 MCP を `mcp-searxng` に移行/セットアップする手順（別PC共通）

このドキュメントは、各クライアントPCの **Claude Code** が共有 SearXNG を Web 検索に使えるようにするための MCP サーバー設定手順です。旧 `searxng-simple-mcp`（Python/pipx）から、保守の活発な `ihor-sokoliuk/mcp-searxng`（Node/npx）へ移行（または新規セットアップ）します。

- **人間の手作業**でも、**別PCの Claude Code に丸ごと依頼**しても実行できるよう、コマンドと根拠を自己完結で記載しています。
- サーバー側（WSL2 上の Firecrawl + SearXNG コンテナ）の構築は別ドキュメント [firecrawl-searxng-setup.md](firecrawl-searxng-setup.md) を参照。本書は **クライアント側の MCP 設定のみ**を扱います。

> ✅ 検証済み（2026-06-02）: `npx -y mcp-searxng` v1.0.5 が Windows 11 で起動し、`http://a11132-1:8888` を指して `searxng_web_search` が実結果を返すことをエンドツーエンドで確認済み。

---

## 0. AIエージェント（別PCの Claude Code）向け実行指示

別PCの Claude Code に作業させる場合は、以下の制約を厳守させること（このPCの運用ルールと同じ）。

- **MCP サーバー登録は必ず `claude mcp add --scope user` を使う。`settings.json` の `mcpServers` は Windows では無視されるため編集しない**（`~/.claude.json` に書かれる）。
- ファイル操作は専用ツール（Read/Edit/Write/Grep/Glob）を使い、Bash の cat/sed 等は使わない。
- 既存の `searxng` 登録があれば削除してから新規登録する（名前を `searxng` のまま引き継ぐ）。
- 登録後、`CLAUDE.md` 内のツール名参照 `mcp__searxng__web_search` を `mcp__searxng__searxng_web_search` に更新する。
- 変更後は MCP サーバーとツールがロードされるよう **Claude Code セッションを再起動**してから動作確認する。

コピペ用プロンプト例:

```
knowhow/mcp-searxng-setup.md の手順に従って、このPCの SearXNG MCP を
mcp-searxng に移行して。SEARXNG_URL は http://a11132-1:8888。
MCP登録は claude mcp add --scope user を使い、settings.json は触らないこと。
完了後 claude mcp list で接続確認し、CLAUDE.md のツール名も更新して。
```

---

## 1. 背景（なぜ移行するか）

| 項目 | 旧: `Sacode/searxng-simple-mcp` | 新: `ihor-sokoliuk/mcp-searxng` |
|---|---|---|
| 実装 | Python (pipx) | Node.js (npx) |
| 既知の問題 | FastMCP 3.x 非互換で起動失敗 → `server.py` を手動パッチして運用、上流PRは未マージ | なし（標準的・活発に保守） |
| 起動方法 | `pipx install` 済みバイナリ直指定（`pipx run` はキャッシュ未パッチで失敗） | `npx -y mcp-searxng`（依存は自動取得） |
| env 変数 | `SEARXNG_MCP_SEARXNG_URL` | `SEARXNG_URL` |
| 公開ツール | `web_search` のみ | `searxng_web_search`, `web_url_read`, `searxng_search_suggestions`, `searxng_instance_info`（版により増減） |
| 既存の npx 運用との一貫性 | なし | `firecrawl-mcp` と同じ npx パターンで統一 |

**移行の利点:** pipx / FastMCP / 手動パッチが不要になり、保守の脆さ（個人開発・PR未マージのバス係数1状態）を解消。加えて `web_url_read`（URL→本文取得）も使える（取得の既定手段。`~/.claude/CLAUDE.md`「### Web 取得」参照）。

> ⚠️ 検索結果にスパムらしき行が混ざるのは SearXNG 側のエンジン品質の問題で、MCP の選択とは無関係（旧でも同じ）。気になる場合はサーバー側 `settings.yml` のエンジン設定で対処する。

---

## 2. 前提条件

| 項目 | 要件 | 確認コマンド（PowerShell） |
|---|---|---|
| Claude Code | インストール済み | `claude --version` |
| Node.js / npx | インストール済み（`mcp-searxng` は npx 起動） | `node --version` / `npx --version` |
| SearXNG への到達性 | このPCから SearXNG エンドポイントに HTTP 到達できること | 下記 3-1 で確認 |

**SEARXNG_URL の決め方:**
- 同一LANのクライアントPC（通常）: `http://a11132-1:8888`
- Docker ホストPC自身で動かす場合: `http://localhost:8888`
- ホスト名 `a11132-1` が名前解決できない場合: Docker ホストPCの **IPアドレス**を使う（例 `http://192.168.x.x:8888`）

> Node.js が未インストールなら先に導入する（例: `winget install OpenJS.NodeJS.LTS`）。導入後 PowerShell を開き直す。

---

## 3. 手順（人間向け）

以降の例では `SEARXNG_URL = http://a11132-1:8888` とする。自分の環境に合わせて読み替えること。

### 3-1. SearXNG エンドポイントの到達確認

```powershell
$base = 'http://a11132-1:8888'
$r = Invoke-RestMethod -Uri "$base/search?q=test&format=json" -TimeoutSec 20
"results=" + $r.results.Count
```

`results=` に1以上の数が表示されれば OK。失敗する場合は SearXNG 側（コンテナ稼働・`settings.yml` の `formats` に `json`・ポート 8888・ファイアウォール/portproxy）を [firecrawl-searxng-setup.md](firecrawl-searxng-setup.md) のトラブルシューティングで確認。

### 3-2. Node.js / npx の確認

```powershell
node --version
npx --version
```

### 3-3. 旧 `searxng` 登録の削除（あれば）

```powershell
claude mcp list
# 一覧に searxng があれば削除（無ければスキップ）
claude mcp remove searxng -s user
```

（任意）pipx の旧パッケージも掃除する場合:

```powershell
pipx uninstall searxng-simple-mcp
```

### 3-4. `mcp-searxng` を登録

```powershell
claude mcp add searxng -s user --env SEARXNG_URL=http://a11132-1:8888 -- npx -y mcp-searxng
```

- 登録名は `searxng` のままにする（既存の運用・CLAUDE.md の `mcp__searxng__*` 名前空間を踏襲するため）。
- `-s user`（=`--scope user`）で `~/.claude.json` のグローバル `mcpServers` に書かれる。**`settings.json` は使わない**（Windows では無視される）。
- 認証付き SearXNG の場合のみ `--env AUTH_USERNAME=... --env AUTH_PASSWORD=...` を追加（このプロジェクトの SearXNG は認証なしなので不要）。

### 3-5. 接続確認

```powershell
claude mcp list
```

`searxng` が接続成功（✓ / Connected）と表示されれば登録 OK。

### 3-6. `CLAUDE.md` のツール名を更新

`mcp-searxng` が公開するツール名は旧サーバーと異なるため、グローバル `CLAUDE.md`（`~/.claude/CLAUDE.md`）内の参照を更新する。

- 置換前: `mcp__searxng__web_search`
- 置換後: `mcp__searxng__searxng_web_search`

> Claude Code に依頼する場合は Grep で `mcp__searxng__web_search` を検索 → Edit で全置換させる。`mcp__searxng__*` のワイルドカード表記があればそのままで可。

### 3-7. 動作確認（実利用）

1. **Claude Code セッションを再起動**（新しい MCP サーバーとツールは起動時にロードされるため）。
2. セッションで「web 検索して」と依頼し、`mcp__searxng__searxng_web_search` が呼ばれて結果が返ることを確認。

---

## 4. （任意）詳細エンドツーエンド検証

`claude mcp list` の接続確認だけでなく、MCP の JSON-RPC を直接叩いて「実際に検索結果が返るか」まで確認したい場合に使う。一時ファイルとして作成し、確認後に削除する。

`drive-mcp.js` を任意の一時フォルダに作成:

```javascript
// Minimal MCP stdio client to verify mcp-searxng end-to-end against a real SearXNG.
const { spawn } = require('child_process');
const SEARXNG_URL = process.env.SEARXNG_TEST_URL || 'http://a11132-1:8888';
const child = spawn('npx', ['-y', 'mcp-searxng'], { shell: true, env: { ...process.env, SEARXNG_URL } });

let buf = '', searchToolName = null, finished = false;
const send = (o) => child.stdin.write(JSON.stringify(o) + '\n');
const done = (c, m) => { if (finished) return; finished = true; if (m) console.log(m); try { child.kill(); } catch (e) {} process.exit(c); };
const timer = setTimeout(() => done(1, 'TIMEOUT'), 240000);

child.stdout.on('data', (d) => {
  buf += d.toString(); let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i).trim(); buf = buf.slice(i + 1);
    if (!line) continue;
    let m; try { m = JSON.parse(line); } catch (e) { continue; }
    if (m.id === 1) {
      const sv = m.result && m.result.serverInfo;
      console.log('INIT_OK server=' + (sv ? sv.name + '@' + sv.version : '?'));
      send({ jsonrpc: '2.0', method: 'notifications/initialized' });
      send({ jsonrpc: '2.0', id: 2, method: 'tools/list' });
    } else if (m.id === 2) {
      const tools = (m.result && m.result.tools) || [];
      console.log('TOOLS=' + tools.map((t) => t.name).join(', '));
      const s = tools.find((t) => /search/i.test(t.name));
      if (!s) return done(1, 'NO_SEARCH_TOOL');
      searchToolName = s.name;
      send({ jsonrpc: '2.0', id: 3, method: 'tools/call', params: { name: s.name, arguments: { query: 'anthropic claude' } } });
    } else if (m.id === 3) {
      if (m.error) return done(1, 'TOOL_CALL_ERROR: ' + JSON.stringify(m.error));
      const text = ((m.result && m.result.content) || []).map((c) => c.text || '').join('\n');
      console.log('TOOL_CALL_OK isError=' + !!(m.result && m.result.isError) + ' chars=' + text.length);
      console.log(text.slice(0, 400));
      done(text.length > 0 && !(m.result && m.result.isError) ? 0 : 1);
    }
  }
});
child.stderr.on('data', (d) => process.stderr.write('[stderr] ' + d));
child.on('error', (e) => done(1, 'SPAWN_ERROR: ' + e.message));
child.on('exit', (c) => { if (!finished) done(1, 'CHILD_EXITED code=' + c); });
send({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'verify', version: '1.0.0' } } });
```

実行:

```powershell
node .\drive-mcp.js
```

期待出力（要点）:

```
INIT_OK server=ihor-sokoliuk/mcp-searxng@1.0.5
TOOLS=searxng_web_search, web_url_read
TOOL_CALL_OK isError=false chars=10000前後
```

`TOOLS=` の並びはサーバー版により増減する（上は v1.0.5 実測。一覧は §1）。

確認後、一時ファイルは削除する。

---

## 5. ロールバック手順

問題が出たら旧構成へ戻す。

```powershell
claude mcp remove searxng -s user
# 旧バイナリのパスとenv名に注意（SEARXNG_MCP_SEARXNG_URL）
claude mcp add searxng -s user --env SEARXNG_MCP_SEARXNG_URL=http://a11132-1:8888 --env FASTMCP_LOG_LEVEL=ERROR -- "C:\Users\<ユーザー名>\.local\bin\searxng-simple-mcp.EXE"
```

文書側も旧構成へ戻す。戻す箇所は次の grep で洗い出す（この 1 本だけ Bash tool（Git Bash）で、`rtk proxy sh -c` 包みのまま実行する。この形を覆う allow は元から無いので permission プロンプトが出るが、許可して続行する）。

```bash
rtk proxy sh -c 'grep -rn "mcp-searxng\|web_url_read\|searxng_web_search\|SEARXNG_URL\|Node" ~/.claude --include="*.md" --include="*.txt" --exclude-dir=.git --exclude-dir=docs --exclude-dir=plugins --exclude-dir=projects --exclude-dir=.tmp --exclude-dir=backups --exclude-dir=cache'
```

各ヒットを次のとおり戻す:

- ツール名: `searxng_web_search` → 旧名 `web_search`。公開ツールの記述「検索・URL 本文取得」→「検索」。
- URL 本文取得: 旧構成に `web_url_read` は無いため、既定を `firecrawl_scrape` へ戻し、`tools:` の `mcp__searxng__web_url_read` を外す。
- MCP 登録の記述: 旧 `searxng-simple-mcp` 構成（`command` にバイナリ直指定、`env` は `SEARXNG_MCP_SEARXNG_URL` と `FASTMCP_LOG_LEVEL`）へ。
- 前提条件（本書 §2 の表）: ``| Python / pipx | Windows 側。`searxng-simple-mcp` を `pipx install` するため | `pipx --version` |`` の行を足し、`Node.js / npx` 行の要件を `インストール済み（context7 / playwright が npx 起動）` へ書き替える（旧構成の searxng は npx を使わないが、他の MCP でなお必要）。
- 前提条件（`firecrawl-searxng-setup.md` の表）: ``| Python / pipx | Windows 側。`searxng-simple-mcp` を `pipx install` するため |`` の行を足す。`Node.js` の行は `firecrawl-mcp` の `npx` 起動用なので残す。

> ⚠️ 旧バイナリは `pipx install searxng-simple-mcp` 後に `server.py` の `log_level=` 行を手動削除したものが必要（`pipx run` 経路は未パッチで起動失敗）。パッチ箇所は https://github.com/Sacode/searxng-simple-mcp の `server.py`（`FastMCP(...)` の `log_level=` 引数）。

---

## 6. トラブルシューティング

| 症状 | 対処 |
|---|---|
| `claude mcp list` で searxng が Failed | (1) `node`/`npx` が PATH にあるか確認 (2) `SEARXNG_URL` の到達性を 3-1 で確認 (3) 初回は npx のダウンロードに時間がかかる。少し待って再確認 |
| `Invoke-RestMethod` が失敗 | SearXNG コンテナ未起動 / `settings.yml` の `formats` に `json` 無し / ポート 8888 不通。サーバー側を確認 |
| `a11132-1` が名前解決できない | Docker ホストPCの IP を `SEARXNG_URL` に使う |
| ツールが呼ばれない / 古いツール名のまま | セッション未再起動。Claude Code を再起動。`CLAUDE.md` のツール名更新漏れも確認 |
| `settings.json` に書いても効かない | Windows では `settings.json` の `mcpServers` は無視される。必ず `claude mcp add --scope user`（`~/.claude.json`）を使う |
| 403 / Forbidden | SearXNG の limiter 設定。サーバー側 `settings.yml` を確認 |

---

## 7. 変更点サマリ（旧→新）

```
登録コマンド:  pipx バイナリ直指定        →  npx -y mcp-searxng
env 変数:      SEARXNG_MCP_SEARXNG_URL    →  SEARXNG_URL
ツール名:      mcp__searxng__web_search   →  mcp__searxng__searxng_web_search
追加ツール:    （なし）                   →  web_url_read ほか（§1）
登録先:        ~/.claude.json（claude mcp add --scope user）※ settings.json は不可
```

## 参考リンク

- mcp-searxng（本書で採用）: https://github.com/ihor-sokoliuk/mcp-searxng
- 旧 searxng-simple-mcp: https://github.com/Sacode/searxng-simple-mcp
- サーバー側構築手順: [firecrawl-searxng-setup.md](firecrawl-searxng-setup.md)
