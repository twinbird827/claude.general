# Playwright MCP セットアップ手順

Microsoft公式の [Playwright MCP](https://github.com/microsoft/playwright-mcp) サーバーを Claude Code に導入する手順。

---

## 前提条件

| 項目 | 要件 |
|------|------|
| Node.js | 18 以上（LTS推奨） |
| Claude Code | インストール済み |
| npx | Node.js に同梱 |

---

## Step 1: ブラウザバイナリのインストール

**`@playwright/mcp` 同梱の playwright-core にインストールさせる。** Playwright CLI 単体で入れたブラウザは、リビジョンが一致しない限り MCPサーバーからは「未インストール」に見える（理由は後述）。

### インストール方法

```powershell
npx @playwright/mcp@latest install-browser chrome-for-testing
```

> ℹ️ Chromium 以外を使う場合は `chrome-for-testing` の代わりに `firefox` / `webkit` を指定する（その場合は Step 2 の `--browser` も同じ名前にする）。`msedge` はダウンロード対象ではなく OS 側の Edge を入れるインストールスクリプト扱いなので、挙動が異なる。

**`@playwright/mcp` が同梱する playwright-core** にインストールを実行させるため、MCPサーバーが起動時に探すリビジョンと一致する（事前インストールも MCP 登録もどちらも `@playwright/mcp@latest` なので、両者の解決先バージョンが同じである限り）。`cli.js` は `install-browser` を `install` に置換して**同梱**の playwright-core に渡すだけで、Playwright CLI 単体との違いは**どの `browsers.json` が読まれるか**しかない。

- 初回はバイナリダウンロード（chromium 本体と headless shell の両方）が発生する。
- このサブコマンドは、どのリンクからも参照されなくなった `chromium-*` を整理するため、既存の `chromium-*` が消えることがある。

> ℹ️ 旧 `@playwright/mcp` の `--install-browser` **フラグ**は廃止されたが、v0.0.78 では `install-browser <name>` **サブコマンド**として存在する。

### ⚠️ `npx playwright install chromium` はリビジョンが一致するときしか使えない

Playwright CLI が入れるリビジョンが、MCPサーバー同梱 playwright-core の要求リビジョンと一致すれば動く。一致しなければ、chromium が存在していても「未インストール」と判定される。

`@playwright/mcp` 0.0.78 が同梱する playwright-core（`1.62.0-alpha-1783623505000`）は chromium **revision 1232** を要求し、`playwright` CLI 1.62.1 は **1234** を要求する。

不一致。`@playwright/mcp@latest` は依存を alpha 版（`playwright(-core)` `1.62.0-alpha-1783623505000`）に pin するため、CLI 安定版とは構造的にズレやすい。**確認法: 該当 playwright-core の `browsers.json` を見る**。`npx playwright --version` ではなく、MCP が実際に読む側のリビジョンで判定すること。

不一致のときは `browser_navigate` を呼んだ時点でこう出る：

```
Error: Browser "chrome-for-testing" is not installed
```

`chrome-for-testing` は chromium の**エイリアス**であって別のブラウザではない。インストール先ディレクトリも実行ファイルも `chromium-<rev>` と同一（エイリアスを指定すると `chromium` と `chromium_headless_shell` の両方が入る）。Playwright が内部の `Executable doesn't exist at <path>` を `Browser "${channel}" is not installed` に包み直す際、`channel` としてエイリアス名がそのまま表示されるため紛らわしいだけで、原因はリビジョン不一致。

実際、MCP 登録を `--headless --isolated --browser=chromium` と**正しく指定していても**このエラーは出る。発生時（**2026-08-04 実測**、`@playwright/mcp` 0.0.78 / `playwright` CLI 1.62.1）に `%LOCALAPPDATA%\ms-playwright\` へ置かれていたのは `chromium-1208` / `chromium-1212` / `chromium_headless_shell-*` で、要求リビジョン 1232 がいずれとも一致していなかった。`--headless` 運用では実際に起動されるのは `chromium_headless_shell-<rev>` 側なので、こちらのリビジョンも揃っている必要がある。

**対処: 上記「インストール方法」で入れ直す。**

---

## Step 2: Playwright MCP サーバーを登録

```powershell
claude mcp add --scope user playwright -- npx @playwright/mcp@latest --headless --isolated --browser=chromium
```

| オプション | 説明 |
|-----------|------|
| `--scope user` | グローバル登録（全プロジェクトで有効）。`~/.claude.json` の `mcpServers` に保存される |
| `--headless` | ヘッドレスモード。ブラウザ画面を表示したい場合は省略する |
| `--browser=chromium` | 使用ブラウザ。`firefox`, `webkit`, `msedge` も選択可 |

> ⚠️ `settings.json` の `mcpServers` に記載する方法は Windows 環境では動作しない。必ず CLI で登録すること。

---

## Step 3: 動作確認

Claude Code を再起動し、以下で接続を確認する：

```
/mcp
```

`playwright` が `connected` と表示されればOK。

---

## Step 4: パーミッション設定

`settings.json` (および `settings.template.json`) の `permissions.allow` に以下を追加する。

サーバー名のみで全ツールが許可される（[公式ドキュメント](https://code.claude.com/docs/en/permissions#mcp)）：

```json
"mcp__playwright"
```

> ℹ️ オプション機能（vision, pdf, devtools, network, storage, testing, config）を有効にするには、MCP登録時に `--caps=vision,pdf,devtools` のように指定する。

---

## `~/.claude.json` に直接記載する場合

CLI を使わずに手動で設定する場合は、`~/.claude.json` の `mcpServers` セクションに以下を追加する：

```json
{
  "mcpServers": {
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "@playwright/mcp@latest",
        "--headless",
        "--browser=chromium"
      ],
      "env": {}
    }
  }
}
```

---

## アンインストール

```powershell
# MCP サーバーの登録解除
claude mcp remove --scope user playwright

# ブラウザバイナリの削除（任意）
# ※ ブラウザは %LOCALAPPDATA%\ms-playwright\.links\ の参照カウントで管理される。
#   CLI 単体で消せるのは CLI 自身が入れた分だけで、MCP 同梱版のリンクが残る限り
#   chromium-1232 は残る。インストール元を問わず全部消すには --all を使う。
# ⚠️ --all は .links\ の全リンクを無条件に消すため、このマシンの他プロジェクトの Playwright が
#   入れたブラウザも一緒に消える。MCP 同梱版のリンクだけを狙って消すコマンドは無い。
#   狙い撃ちするなら .links\ の該当リンクファイルを手で削除してから playwright install を回すと、
#   参照が切れたブラウザだけが GC で消える。
npx playwright uninstall --all
```

---

## 参考

- [microsoft/playwright-mcp](https://github.com/microsoft/playwright-mcp) — 公式リポジトリ
- [Playwright MCP ツール一覧](https://github.com/microsoft/playwright-mcp#tools) — 全ツールの詳細パラメータ
