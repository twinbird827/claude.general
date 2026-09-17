# Windows 11 (WSL2) で Firecrawl + SearXNG をセルフホストする手順

## 前提条件

| 項目 | 要件 |
|---|---|
| OS | Windows 11（WSL2 有効化済み） |
| RAM | 最低 4GB（推奨 8GB 以上） |
| ストレージ | 10GB 以上の空き容量 |
| Git | インストール済み |
| Node.js | LTS（Windows 側。§4 の MCP サーバーを npx で起動するため） |

---

## 1. WSL2 + Docker Engine のインストール

Docker Desktop は使用せず、WSL2 内に直接 Docker Engine をインストールする。これにより `0.0.0.0` バインドが可能になり、LAN 内の他 PC からのアクセスが容易になる。

### 1-1. WSL2 (Ubuntu) のインストール

管理者 PowerShell で実行：

```powershell
wsl --install -d Ubuntu
```

インストール後、Ubuntu が起動するのでユーザー名・パスワードを設定する。

> ⚠️ 既に WSL2 + Ubuntu がインストール済みの場合はスキップ。
> ⚠️ WSL2 のアップデートが必要と言われた場合は `wsl --update` を実行。

### 1-2. Docker Engine のインストール（WSL2 内）

以降のコマンドは **WSL2 (Ubuntu) 内** で実行する。

```bash
# 古いバージョンを削除（あれば）
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null

# 依存パッケージのインストール
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# Docker 公式 GPG キーを追加
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Docker リポジトリを追加
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker Engine + Compose プラグインをインストール
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 現在のユーザーを docker グループに追加（sudo なしで実行可能にする）
sudo usermod -aG docker $USER
```

**グループ変更を反映するため、一度 WSL2 を終了して再起動する：**

```powershell
# PowerShell で実行
wsl --shutdown
wsl
```

### 1-3. Docker デーモンの自動起動設定

WSL2 の systemd を有効にして、Docker が自動起動するようにする。

```bash
# systemd が有効か確認
cat /etc/wsl.conf
```

`[boot]` セクションに `systemd=true` がなければ追加：

```bash
sudo tee -a /etc/wsl.conf > /dev/null <<'EOF'
[boot]
systemd=true
EOF
```

WSL2 を再起動して反映：

```powershell
# PowerShell で実行
wsl --shutdown
wsl
```

Docker デーモンの自動起動を有効化：

```bash
sudo systemctl enable docker
```

### 1-4. 起動確認

```bash
docker --version
docker compose version
docker run --rm hello-world
```

すべて正常に動作すれば OK。

---

## 2. Firecrawl のセットアップ

以降のコマンドは **WSL2 (Ubuntu) 内** で実行する。

### 2-1. リポジトリのクローン

```bash
mkdir -p ~/Projects
git clone https://github.com/mendableai/firecrawl.git ~/Projects/firecrawl
```

> ⚠️ パスに日本語・スペースが含まれる場所は避けること。

### 2-2. `.env` ファイルの作成

リポジトリ内にテンプレートが用意されているのでコピーして使う：

```bash
cp ~/Projects/firecrawl/apps/api/.env.example ~/Projects/firecrawl/.env
```

次にコピーした `.env` を開いて必要箇所を編集：

```bash
nano ~/Projects/firecrawl/.env
```

> Windows 側のエディタで編集したい場合は `\\wsl$\Ubuntu\home\<ユーザー名>\Projects\firecrawl\.env` をエクスプローラーで開く。

**変更が必要な箇所：**

| 行 | 変更前 | 変更後 | 理由 |
|---|---|---|---|
| `USE_DB_AUTHENTICATION` | `true` | `false` | Supabase なしで動かすため |
| `TEST_API_KEY` | 空欄 | 任意の文字列 | API キー認証を有効にするため |
| `X402_ENABLED` | `true` | `false` | 暗号通貨決済機能を無効にするため |

**追加が必要な行（ファイル末尾に追加）：**

```env
# SearXNG（自己ホスト検索エンジン）
SEARXNG_ENDPOINT=http://searxng:8080
```

**編集例（変更後の主要箇所）：**

```env
USE_DB_AUTHENTICATION=false
TEST_API_KEY=your-secret-api-key
X402_ENABLED=false
SEARXNG_ENDPOINT=http://searxng:8080
```

### 2-3. docker-compose.yaml に SearXNG を追加・自動起動設定

```bash
nano ~/Projects/firecrawl/docker-compose.yaml
```

**① 既存サービスに `restart: always` を追加**

既存の各サービス（`api`、`playwright-service`、`redis`、`rabbitmq`、`nuq-postgres`）に `restart: always` が付いているか確認する。付いていない場合は各サービスに追加：

```yaml
services:
  api:
    restart: always   # ← なければ追加
    ...

  playwright-service:
    restart: always   # ← なければ追加
    ...

  redis:
    restart: always   # ← なければ追加
    ...
```

> ✅ `restart: always` が設定されていれば、WSL2 起動時に Docker デーモンがコンテナを自動復帰する。

**② SearXNG サービスを末尾に追加**

`services:` セクションの末尾（`networks:` の直前）に以下を追加：

```yaml
  searxng:
    restart: always
    image: searxng/searxng:latest
    networks:
      - backend
    ports:
      - "0.0.0.0:8888:8080"
    volumes:
      - ./searxng:/etc/searxng
    environment:
      - BASE_URL=http://localhost:8888
      - INSTANCE_NAME=local
```

> ✅ WSL2 内の Docker Engine では、ports のバインドアドレス省略時はデフォルトで `0.0.0.0` になる。
> Firecrawl の `api` サービスは `"${PORT:-3002}:${INTERNAL_PORT:-3002}"` のままで LAN 内の他 PC からもアクセス可能。

### 2-4. Docker Compose で起動

```bash
docker compose -f ~/Projects/firecrawl/docker-compose.yaml up -d
```

初回はイメージのダウンロードで数分かかる。

### 2-5. 起動確認

```bash
docker compose -f ~/Projects/firecrawl/docker-compose.yaml ps
```

全コンテナが `running` になっていることを確認：

```
firecrawl-api-1                running
firecrawl-playwright-service-1 running
firecrawl-searxng-1            running
firecrawl-nuq-postgres-1       running
firecrawl-redis-1              running
firecrawl-rabbitmq-1           running
```

### 2-6. Firecrawl の動作テスト

```bash
curl -X POST http://localhost:3002/v1/scrape \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-secret-api-key" \
  -d '{"url": "https://example.com", "formats": ["markdown"]}'
```

`"success":true` と `markdown` の内容が返れば成功。

---

## 3. SearXNG の設定

### 3-1. settings.yml を取得

```bash
docker cp firecrawl-searxng-1:/etc/searxng/settings.yml /tmp/settings.yml
nano /tmp/settings.yml
```

### 3-2. JSON 形式を有効化

77〜78 行目付近の `formats` を編集：

```yaml
# 修正前
formats:
  - html

# 修正後
formats:
  - html
  - json    # ← 追加
```

### 3-3. バインドアドレスを変更

83 行目付近：

```yaml
# 修正前
bind_address: "127.0.0.1"

# 修正後
bind_address: "0.0.0.0"
```

### 3-4. 設定ファイルを反映

```bash
docker cp /tmp/settings.yml firecrawl-searxng-1:/etc/searxng/settings.yml
docker restart firecrawl-searxng-1
```

### 3-5. SearXNG の動作テスト

```bash
curl "http://localhost:8888/search?q=test&format=json"
```

JSON が返れば成功。ブラウザで `http://localhost:8888` を開いても確認できる。

### 3-6. 低品質エンジン（qwant など）の無効化

SearXNG は複数の検索エンジンの結果を束ねるため、**特定エンジンのコネクタが壊れる／ブロックされる**と、その結果（意味不明なタイトル＋ `.vi`/`.tc` などの捨てドメインのスパム）が全体に混入することがある。

本環境では **`qwant` が 100% スパムを返していた**ため無効化した（`google`/`duckduckgo`/`brave` は正常）。Qwant 自体は正規のエンジンだが、この SearXNG ではコネクタが壊れてゴミだけ拾っていた状態。

**① 原因エンジンの特定**（どのエンジンがゴミを返しているか。ホスト・クライアントどちらからでも可）:

```bash
curl -s "http://localhost:8888/search?q=anthropic+claude&format=json" \
  | python3 -c "import sys,json;d=json.load(sys.stdin);[print(r.get('engine'),'|',r.get('url'),'|',(r.get('title') or '')[:50]) for r in d['results']]"
```

スパム行（ランダム文字列タイトル＋怪しいドメイン）の `engine` 名を確認する。

**② 無効化**（`settings.yml` は SearXNG コンテナが root として書き出すため **root 所有**。一般ユーザーで直接編集すると `Permission denied` になるので `docker cp` 経由で編集する）:

```bash
docker cp firecrawl-searxng-1:/etc/searxng/settings.yml /tmp/settings.yml
cp /tmp/settings.yml /tmp/settings.yml.bak
nano /tmp/settings.yml
```

`engines:` セクションに、無効化したいエンジンをリスト項目で追記:

```yaml
engines:
  - name: qwant
    disabled: true
```

> SearXNG はエンジンを `name` で照合してマージするため、この記述で該当エンジンだけが無効化される（他はそのまま）。
> `engines:` が既に存在する場合はその配下に `- name: ... / disabled: true` を1項目として追加（キーを二重に書かない）。無ければブロックごと先頭カラムで追加。

```bash
docker cp /tmp/settings.yml firecrawl-searxng-1:/etc/searxng/settings.yml
docker restart firecrawl-searxng-1
```

**③ 確認**（無効化したエンジンが消えていれば成功）:

```bash
curl -s "http://localhost:8888/search?q=test&format=json" \
  | python3 -c "import sys,json,collections as c;d=json.load(sys.stdin);print(c.Counter(r.get('engine') for r in d['results']))"
```

Counter に該当エンジンが出なくなれば OK。

> ⚠️ ロールバック: `docker cp /tmp/settings.yml.bak firecrawl-searxng-1:/etc/searxng/settings.yml` → `docker restart firecrawl-searxng-1`。
> 将来 SearXNG イメージを更新してコネクタが修正されたら、`disabled: true` を外せば再び使える。

---

## 4. Claude Desktop への MCP 設定

Claude Desktop から SearXNG（検索・URL 本文取得）と Firecrawl を使えるようにする。**Claude Code 側（設定先は `~/.claude.json`）は本節でなく [mcp-searxng-setup.md](mcp-searxng-setup.md) で登録する。**

> ✅ NAT モードでも `localhost` で Windows 側からアクセスできる（WSL2 が localhost 転送を行うため）。

### 4-1. Claude Desktop の設定ファイルを編集

```powershell
notepad "$env:APPDATA\Claude\claude_desktop_config.json"
```

```json
{
  "mcpServers": {
    "searxng": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-searxng"
      ],
      "env": {
        "SEARXNG_URL": "http://localhost:8888"
      }
    },
    "firecrawl-mcp": {
      "command": "npx",
      "args": [
        "-y",
        "firecrawl-mcp"
      ],
      "env": {
        "FIRECRAWL_API_KEY": "your-secret-api-key",
        "FIRECRAWL_API_URL": "http://localhost:3002"
      }
    }
  }
}
```

> ⚠️ `FIRECRAWL_API_KEY` は `.env` の `TEST_API_KEY` に設定した値と同じものを入力すること。
> 他 PC の Claude Desktop から使う場合は `localhost` を Docker ホスト PC のホスト名または IP に読み替える（§6）。

### 4-2. Claude Desktop を再起動

```powershell
taskkill /F /IM "Claude.exe"
```

Claude Desktop を起動し、チャット画面に 🔧 アイコンが表示されれば設定完了。`searxng` が公開するツールの一覧は [mcp-searxng-setup.md](mcp-searxng-setup.md) §1 の比較表「公開ツール」行が正本。

---

## 5. 日常的な操作

### 起動（PC 再起動後など）

systemd + `restart: always` を設定済みであれば、WSL2 起動時に自動でコンテナが立ち上がる。手動で起動する場合：

```bash
docker compose -f ~/Projects/firecrawl/docker-compose.yaml up -d
```

Windows 側から WSL2 を起動するには：

```powershell
wsl
```

### 停止

```bash
docker compose -f ~/Projects/firecrawl/docker-compose.yaml down
```

### ログ確認

```bash
docker compose -f ~/Projects/firecrawl/docker-compose.yaml logs -f
# 特定サービスのみ
docker compose -f ~/Projects/firecrawl/docker-compose.yaml logs -f api
```

### WSL2 の自動起動設定

PC ログイン時に WSL2 を自動起動するには、Windows のタスクスケジューラまたはスタートアップに以下を登録：

```
wsl -d Ubuntu -- bash -c "sleep 1"
```

> ✅ WSL2 が起動すれば systemd → Docker デーモン → コンテナ（`restart: always`）の順に自動復帰する。

---

## 6. 他 PC からのアクセス設定

WSL2 の NAT モードでは、コンテナのポートは `127.0.0.1` にしかバインドされないため、Windows 側で **portproxy** を設定して `0.0.0.0` に転送する必要がある。

### 6-1. .wslconfig の設定

WSL2 のネットワークモードを NAT に設定する：

```powershell
notepad $env:USERPROFILE\.wslconfig
```

```ini
[wsl2]
networkingMode=NAT
```

> ⚠️ Mirrored モードでは portproxy が正常に機能しないため、NAT モードを使用する。

### 6-2. portproxy の設定

> ⚠️ **`connectaddress=127.0.0.1` は使用しない。** WSL2 NAT モードでは portproxy が `0.0.0.0` でポートを掴むと WSL2 のネイティブ localhost 転送と競合し、接続が失敗する。必ず WSL2 の実際の IP を指定すること。また、WSL2 の IP は再起動のたびに変わるため、手動設定ではなく自動設定スクリプトを使用する。

**自動設定（推奨）:** タスクスケジューラに登録済みの `firecrawl-searxng-setup.ps1` がログオン時に自動実行される。手動実行する場合は管理者 PowerShell で：

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\Users\horie\.claude\knowhow\firecrawl-searxng-setup.ps1"
```

**手動設定の場合:**

```bash
# WSL2 の IP を確認
wsl.exe bash -c "hostname -I"
```

```powershell
# 確認した IP を指定（例: 172.25.84.11）
netsh interface portproxy add v4tov4 listenport=3002 listenaddress=0.0.0.0 connectport=3002 connectaddress=<WSLのIP>
netsh interface portproxy add v4tov4 listenport=8888 listenaddress=0.0.0.0 connectport=8888 connectaddress=<WSLのIP>
```

確認：

```powershell
netsh interface portproxy show all
netstat -ano | findstr "LISTENING" | findstr "3002 8888"
```

`0.0.0.0:3002` と `0.0.0.0:8888` で LISTENING が表示されれば OK。

削除する場合：

```powershell
netsh interface portproxy reset
```

### 6-3. Windows ファイアウォールの設定

管理者 PowerShell で受信ルールを追加：

```powershell
netsh advfirewall firewall add rule name="Firecrawl API (3002)" dir=in action=allow protocol=TCP localport=3002 profile=any
netsh advfirewall firewall add rule name="SearXNG (8888)" dir=in action=allow protocol=TCP localport=8888 profile=any
```

> ⚠️ **ドメイン参加 PC の場合**: GPO で `LocalFirewallRules` が `N/A (GPO ストアのみ)` に設定されていると、ローカルで追加したルールはすべて無視される。この場合はドメイン管理者に **サーバー上の GPMC** から GPO の受信規則にルールを追加してもらう必要がある（対象 PC 上でのローカル追加では効かない）。確認方法: `netsh advfirewall show allprofiles | findstr LocalFirewallRules`

### 6-4. アクセス確認

他 PC から以下にアクセスできれば成功：

```
http://<Docker PC の IP>:3002   → Firecrawl API
http://<Docker PC の IP>:8888   → SearXNG 検索UI
```

---

## 7. トラブルシューティング

| 症状 | 対処法 |
|---|---|
| コンテナが起動しない | `docker compose logs` でエラー確認 |
| Docker デーモンが起動しない | `sudo systemctl status docker` で状態確認、`sudo systemctl start docker` で手動起動 |
| Redis 接続エラー | `.env` の `REDIS_URL` が `redis://redis:6379` か確認 |
| ポート 3002 が使えない | `.env` の `PORT` を変更（例：`3003`） |
| SearXNG が Forbidden | `settings.yml` の `formats` に `json` を追加 |
| 検索結果にスパム/意味不明な結果が混ざる | 特定エンジン（本環境では `qwant`）のコネクタ不良。§3-6 で原因エンジンを特定して `disabled: true` にする |
| `settings.yml` が `Permission denied` で編集できない | コンテナが root 所有で書き出すため。`docker cp` 経由で `/tmp` に出して編集→書き戻す（§3-6 参照） |
| Supabase 関連エラー | `USE_DB_AUTHENTICATION=false` なら無視して OK |
| Claude Desktop で MCP サーバーが起動しない | [mcp-searxng-setup.md](mcp-searxng-setup.md) §3-2 の確認を実行。初回は npx のパッケージ取得に時間がかかるので少し待って Claude Desktop を再起動 |
| コンテナ名が違う | `docker ps --format "table {{.Names}}\t{{.Image}}"` で正確な名前を確認 |
| 他 PC からアクセスできない | (1) `netsh interface portproxy show all` で portproxy 設定確認 (2) `netstat -ano \| findstr "LISTENING" \| findstr "3002"` で `0.0.0.0` リッスン確認 (3) ファイアウォールルール確認。ドメイン参加 PC では GPO でローカルルールが無視される場合あり（`netsh advfirewall show allprofiles` で `LocalFirewallRules` を確認） |
| portproxy 設定しても `0.0.0.0` でリッスンしない | `netsh interface portproxy reset` → `net stop iphlpsvc` → `net start iphlpsvc` → 再設定。Mirrored モードでは portproxy が機能しないため NAT モードを使用する |
| WSL2 再起動後にコンテナが起動しない | `/etc/wsl.conf` に `systemd=true` があるか確認 |
| PC 再起動後に localhost:8888 が繋がらない | WSL2 の IP が変わった。`firecrawl-searxng-setup.ps1` を管理者 PowerShell で実行するか、タスクスケジューラの `WSL2-PortProxy-Setup` を確認 |

---

## 8. 構成まとめ

```
http://localhost:3002   → Firecrawl API（ローカル）
http://localhost:8888   → SearXNG 検索UI（ローカル）
http://<IP>:3002        → Firecrawl API（他 PC から）
http://<IP>:8888        → SearXNG 検索UI（他 PC から）
```

### Python からの利用

```python
from firecrawl import FirecrawlApp

app = FirecrawlApp(
    api_key="your-secret-api-key",
    api_url="http://localhost:3002"
)
result = app.scrape_url("https://example.com", formats=["markdown"])
print(result.markdown)
```

---

## 参考リンク

- Firecrawl 公式ドキュメント: https://docs.firecrawl.dev/contributing/self-host
- Firecrawl GitHub: https://github.com/mendableai/firecrawl
- SearXNG GitHub: https://github.com/searxng/searxng
- Docker Engine (Ubuntu) インストール: https://docs.docker.com/engine/install/ubuntu/
