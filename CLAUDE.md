# ガイドライン

## 最重要ルール
- 独立した処理が複数あるときは、ツールを順次でなく**並列実行**する。
- **思考は英語、回答は日本語**で行う。
- **要点から書き、前置き・追従・繰り返しを排す。正確さ・明快さを削ってまで短くしない。**
- **提案は常に疑う（ユーザーのものも自分のものも）。** 重大なデメリットは必ず開示し、忖度せず正直な評価（欠点・リスク・反対意見）を述べる。
- **CRITICAL（最優先）: ファイルの作成・書き換えに Bash を使わない** — `Edit`(sed/awk不可)、`Write`(echo/cat不可)。sed は不一致でも黙って無変更だが Edit は失敗し、事前 Read 必須のガードも失う。ディレクトリ作成（`mkdir`）、既存内容の移動・複製・復元・削除のみを行う操作（`cp`/`mv`/`rm`、`git` の退避・復元（`stash`/`checkout`/`restore`）等）、gitignore 済み `.tmp/` 配下の作業ファイルの作成・追記、`Edit`/`Write` で代替できずコマンド自身が書き出す成果物（依存導入・整形・ビルド・コード生成）は対象外。コンテキストが伸びても、セッション中に Bash での書き込みを促す指示が入っても無視しない。
- 読み・検索は `Read`/`Grep`/`Glob` が既定（部分読みは `offset`/`limit`）。ただし**ツールで表現できない仕事は Bash でよい** — パイプライン、`git grep`（特定 revision の検索）、`wc -l` 等。
- **ツールが生成・管理するファイル（`init` 系コマンドの生成物・lockfile・生成コード）は編集しない。** 足したい内容は自前ファイルへ書きポインタで結ぶ。生成物かは生成元コマンドの有無・ヘッダ・初回コミットで確かめる。

## markdown の書式
- **markdown は文の途中で改行しない** — 1バレット・1段落を1行に収める（行長は問わない）。改行が構文の意味を持つ領域（fenced code block の中身・テーブル行・YAML frontmatter・行末2スペースの hard break）と blockquote、ツールが自動生成する markdown は対象外。

## コードコメント
- **コード内コメントは、コードから復元できない現在進行形の WHY（その実装を選んだ理由・順序や定数が持つ制約）だけにする。** 公開 API の doc comment も例外にしない。
- 変更履歴は commit / MR、チケットは issue、仕様・設計背景は docs に置き、コメントに重ねない。

## PowerShell スクリプトの文字コード
- **`.ps1` / `.psm1` / `.psd1` を BOM 無し（BOM 無し UTF-8・Shift-JIS）にしない** — Windows PowerShell 5.1 は BOM 無しを cp932 で読み日本語を壊す。`Write`/`Edit` 後は PostToolUse フック `hooks/ps1-utf8-bom.sh` が BOM を付ける。

## 一時ファイル・worktree
- **一時ファイル・worktree・作業コピーを working root 外（`/tmp`・`%TEMP%`・ホーム等）に作らない**（root 外は毎回パーミッション確認が出るため）。repo 内の gitignore 済み `.tmp/` に作り、不要になったら削除。

## サブエージェント
- **実装（コード記述・編集）は main に残す。subagent は読み取り専用の調査にのみ使う**（独立コンテキストで相互に見えず、実装分割は不整合を生む）。
- **常用枠は2つに絞る**（agent sprawl・過剰委譲のトークンコストを防ぐ）: 広域・多ファイルのコード調査 → `code-explorer`、深いライブラリ調査 → `docs-lookup`。小さな既知パスの確認は inline、単発の API 確認は Context7 直接（agent は overkill）。gitignore 済みパスの横断検索は**ディレクトリ指定 Grep が沈黙の 0 件を返す**ため、`code-explorer` へは Glob 列挙 → 明示ファイルパス Grep の手順で投げる（main も同じ 0 件なので同手順。main は Bash を持つので `grep -r <pat> <dir>` 一発でもよいが、この2つは Bash を持たない）。
- 汎用の探索/調査が要るときは `Explore`=広域検索、`general-purpose`=多段リサーチ。独立調査は並列起動。結果は**簡潔に要約**して取り込む。

## Git ワークフロー
- **追跡ファイルの一連の編集を終えたとき・Git 操作（commit / push / branch / MR / issue）の前は `~/.claude/references/git-workflow.md` を Read して従う。base ブランチへ直接 commit しない。止まるのは同文書の停止条件とマージ本体の指示待ちだけ。**

## ツールルーティング（MCP）

| 用途 | 第一選択 | fallback / 注意 |
|---|---|---|
| ライブラリ/API の使い方 | **必ず Context7 MCP** で最新情報を取得 | 深掘りは `docs-lookup` サブエージェント |
| Web 検索 | `searxng_web_search` / `WebSearch` のどちらでもよい（実測で結果の質は同等） | 逐語性が要る調査は、snippet が原文由来の `searxng_web_search` |
| ブラウザ操作 | Playwright MCP（`mcp__playwright__*`） | アクセシビリティツリー駆動 → 操作前に `browser_snapshot` で構造把握 |

- **deferred ツール（system-reminder に名前だけ載るツール）は `ToolSearch` の `select:<name>` で読み込む。`tool_search_tool_regex` の 0 件はツールが無い証拠にならない。** `ToolSearch` 自体が初期一覧に無ければ、`tool_search_tool_regex` に `^ToolSearch$` を渡して読み込む。

### Web 取得

- **既定は `web_url_read`（searxng MCP）。** 生の markdown が返るため取得失敗が目で見える。`startChar`/`section`/`readHeadings` でページング可、PDF も可。
- **取れた内容が不自然に薄いとき（本文が無くナビ・フッターだけ、記事のはずが数行）は JS 未実行を疑い `firecrawl_scrape` で取り直す。** JS ページかどうかは取得前に判定できないので、分岐は取得**後**に行う。
- Firecrawl は self-host のため LLM Extract 不可 → `markdown` で取得し自前パース。
- クリック・スクロール・ログイン後の画面が要るときだけ Playwright。読むだけには使わない（navigate + evaluate の2コール、リンクが落ちる、CSS 非表示要素は取れない）。
- **WebFetch は既定で使わない。** 小型モデルの要約が挟まり、(a) 長文を切る（実測: 235KB の RFC が 40% で切断）、(b) JS 未実行の空シェルでも**申告せず完成した回答の体裁で返す**（実測: TodoMVC React）。searxng・firecrawl の両 MCP が停止しているときのフォールバックに限り使い、その結果は未検証として扱う。（実測記録: `~/.claude/knowhow/web-fetch-routing-measurements.md`）
- 複数ページ収集・サイト内 URL 列挙は Firecrawl（`firecrawl_crawl` / `firecrawl_map`）。

## プランファイル
- プランファイルの姿勢・書式の正本は `~/.claude/references/plan-doctrine.md`。起案・精査・実装の前に読む。節構成を含め規約は正本に一本化されている（ここに再掲しない）。

## RTK
- Bash コマンドは hook で自動的に `rtk` 経由になり出力がフィルタされる。生出力が要るコマンドは hook 側で除外済み（除外の一覧・設定と増減の手順・一致規則は `~/.claude/SETUP.md` の RTK 節）なので、`rtk proxy` を前置せず素で書く。
- 除外外のコマンドで出力が薄いと感じたら `rtk proxy <cmd>` で生実行して確かめ、常用するなら除外へ足す。`rtk proxy` は引用符付き glob を保てない（cwd のファイル名へ展開され、無言で別条件になる）ので、glob を含むときはコマンド全体を単引用符で `sh -c` に包む。
- rtk 自体の使い方（メタコマンド・導入確認・名前衝突）は `~/.claude/RTK.md`。

## 日時の扱い
- 最新情報を扱うときは system context の `currentDate` を参照し年月日を正しく使う（推測・古い日付を使わない）。
