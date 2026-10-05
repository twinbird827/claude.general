# Claude Code グローバル設定

Claude Code のグローバル設定ディレクトリ（`~/.claude`）を複数 PC で共有するリポジトリ。新 PC の環境構築は [SETUP.md](SETUP.md)。

---

## 📁 リポジトリ構成

```
.claude/
├── CLAUDE.md                   # 全 PC 共通のグローバル指示
├── README.md                   # 本書（repo の説明と使い方）
├── SETUP.md                    # 新 PC の環境構築手順
├── RTK.md                      # rtk のメタコマンドと導入確認
├── settings.template.json      # チーム共有の設定テンプレート（git 管理対象）
├── settings.json               # 【各 PC 個別】実際に使われる設定（gitignore 対象）
├── .gitignore                  # 全無視 + 許可リスト方式
├── agents/                     # subagent 定義。frontmatter の description が正本
│   ├── code-explorer.md
│   ├── code-review-runner.md
│   ├── docs-lookup.md
│   ├── finding-verifier.md
│   └── plan-investigator.md
├── skills/                     # skill 定義。SKILL.md の frontmatter が正本
│   ├── code-review-to-plan/
│   ├── codebase-docgen/
│   ├── codebase-docsync/
│   ├── deep-code-review/
│   ├── plan-refinement-loop/
│   ├── plan-writing/
│   ├── simplification-review/
│   └── standard-code-review/
├── references/                 # skill・agent が共有する正本文書
│   ├── git-workflow.md             # branch / commit / MR / issue の操作手順
│   ├── plan-doctrine.md            # プランファイルの姿勢・書式（決定記録 節を含む）
│   ├── review-criteria.md          # 指摘の形・重大度・クラス・Measurement・票勘定・対象引数
│   └── git-hosting/                # gitlab.md / github.md のコマンド表
├── hooks/
│   ├── permission-extension.ps1        # PreToolUse: .tmp/ 配下の rm を自動承認し glab api は書き込み形だけ通す。ask の項目は auto 以外でだけ ask、`glab mr merge` / `gh pr merge` で始まる段は全モードで ask
│   ├── permission-extension.tests.ps1  # 上の self-check
│   ├── notify.ps1                      # Stop / Notification: 前景が VSCode でなければ MessageBox
│   └── lf-to-crlf.sh                   # PostToolUse: LF → CRLF 正規化（現在は未登録）
├── knowhow/                    # 導入手順と実測記録
│   ├── headroom-setup.md               # Headroom（コンテキスト圧縮 proxy）の導入
│   ├── mcp-searxng-setup.md            # SearXNG 用 MCP（mcp-searxng）の導入
│   ├── firecrawl-searxng-setup.md      # Firecrawl + SearXNG のセルフホスト（WSL2）
│   ├── firecrawl-searxng-setup.ps1     # 上のログオン時自動設定スクリプト
│   ├── playwright-mcp-setup.md         # Playwright MCP の導入
│   ├── plugin-update.sh                # plugin 日次更新（Task Scheduler から起動）
│   ├── pipe-stage-hook-removal.md      # パイプ自動承認 hook を撤去した記録
│   ├── web-fetch-routing-measurements.md  # WebFetch ルーティングの実測
│   └── deep-research-prompt.txt        # ディープリサーチ用プロンプト
├── .tmp/                       # 作業ファイル（gitignore 対象。MR / issue 本文の一時ファイル）
└── docs/plans/                 # プランファイル（gitignore 対象。settings の plansDirectory）
```

---

## 🧭 使い方

### 基本フロー（issue → プラン → 実装 → レビュー）

1. issue を起点に「プランを書いて」— `plan-writing` が `docs/plans/<name>.md` を書く
2. 「プランを徹底調査して」— `plan-refinement-loop` が Critical / Major の指摘が出なくなるまで精査と修正を繰り返す
3. 新しいセッションでプランを実装する。実装後の branch・commit・MR は [references/git-workflow.md](references/git-workflow.md) に従う
4. 「実装後レビュー」— `code-review-to-plan` が差分をレビューし、確認済みの指摘を次の実装プラン `docs/plans/cr-fixes-<branch>-r<N>.md` に畳む。Critical / Major があれば 2 へ戻る

### スキル

| スキル | 用途 | 呼び方 |
|---|---|---|
| `plan-writing` | 会話で固めた要件・調査・確認事項を、別セッションが単独で実装できるプランファイルに書く | 「プランを書いて」「実装計画を立てて」 |
| `plan-refinement-loop` | プランファイルを `plan-investigator` と `finding-verifier` で精査し、Critical / Major が出なくなるまで直す | 「プランを徹底調査して」「プランを精査して指摘を反映」 |
| `code-review-to-plan` | 差分を下の 3 つのレビュー skill（`code-review-runner` が直列実行）で見て、CONFIRMED の指摘を 1 つの変更セットにまとめた実装プランを書く（その場では直さない）。スコープ外の指摘は issue に起票する | 「指摘をプラン化して」「実装後レビュー」 |
| `standard-code-review` | 差分の正確性レビュー（確度の高いバグ・`CLAUDE.md` 準拠）。読むだけで直さない | 「コードレビューして」。`code-review-runner` からも呼ばれる |
| `deep-code-review` | standard が構造的に見ない層（同型の横展開・根本原因・設計の波及・沈黙する失敗・回帰テスト）。C# / VB6 / VBS / PowerShell / Python | 「コードレビューして」。`code-review-runner` からも呼ばれる |
| `simplification-review` | 過剰実装レビュー（削れるもの・stdlib で足りるもの・使われない柔軟性）。`ponytail:ponytail-review` を包む | `code-review-runner` からだけ呼ばれる（`/` 補完なし） |
| `codebase-docgen` | ドキュメントの無い repo に日本語ドキュメント一式（CODEMAPS / README / ONBOARDING）を生成する | 「このコードベースのドキュメントを作って」 |
| `codebase-docsync` | 既存ドキュメントをコードに合わせて最小差分で同期する。作り直さない | 「ドキュメントをコードに合わせて更新して」 |

### エージェント

いずれも読み取り専用で、編集はしない。

| エージェント | 役割 | 呼び手 |
|---|---|---|
| `code-explorer` | 広域・多ファイルのコード調査。入口・経路・依存を要約して返す | main（`CLAUDE.md` の サブエージェント 節） |
| `code-review-runner` | standard / deep / simplification の 3 レビューを直列に実行し、合流済みの指摘だけを返す。単一スキル指定で 1 レビューだけも走らせる | `code-review-to-plan` / `plan-refinement-loop` |
| `docs-lookup` | ライブラリ docs の深掘り。Context7 の長い出力を自分のコンテキストに隔離する | main（単発の API 確認は Context7 を直接呼ぶ） |
| `finding-verifier` | 指摘の 根拠 を独立に事実確認し、CONFIRMED / REFUTED / UNVERIFIABLE を返す | `code-review-to-plan` / `plan-refinement-loop` |
| `plan-investigator` | プランを実コードと外部事実に突き合わせ、指摘を挙げる | `plan-refinement-loop` |

---

## 🔄 設定変更の運用

`main` へ直接 commit しない。branch を切り MR を経る — 手順は [references/git-workflow.md](references/git-workflow.md)。template の更新を各 PC の `settings.json` へ反映する手順は [SETUP.md](SETUP.md) の Step 9。

---

## 🔗 PreToolUse Hook

現行の登録は `rtk hook claude`（導入と除外設定は [SETUP.md](SETUP.md) の RTK 節）と `permission-extension.ps1`（下記の節）。以下は同じ `PreToolUse` に入れていた別 hook の撤去記録。

パイプ付きコマンドが `permissions.allow` にマッチしない問題（[GitHub Issue #29967](https://github.com/anthropics/claude-code/issues/29967)）の回避Hookを導入していたが、**Claude Code 本体がパイプ／`&&` をセグメント単位で判定するようになったため撤去した**。

撤去の根拠と実測手順は **[knowhow/pipe-stage-hook-removal.md](knowhow/pipe-stage-hook-removal.md)** を参照。既存PCで `settings.json` に `pipe-stage-permissions.sh` の定義が残っている場合は手動で削除する。

---

## 🔗 PreToolUse Hook（permission リストの拡張 — `.tmp/` 配下の rm を自動承認、`glab api` は書き込み形だけ通す、ask の項目をモード別に扱う）

rm 側は auto モードの無確認範囲を `.tmp/` 配下の `rm` だけに絞る。settings の `permissions.ask` は rtk が書き換えた呼び出しでは効かないため（下の モード別の実測）、`Bash(rm:*)` を掲載していた変更前は、rtk が書き換えた段を含む連結呼び出しの中の `rm` 段が deny の 2 件を除いて無確認だった（`rm` 単体は rtk に書き換えられず prompt が出ていた）。その掲載を外し、`.tmp/` 配下だけを hook の `allow` で通す。代償として、連結呼び出しの中の `.tmp/` 外の `rm` 段にも auto モードで prompt が出るようになる。許容される形から外れた形が `ask` に落ちるのは許容する（手順が作る一時ファイルは ASCII の `rm .tmp/<path>` 形に収まるため）。

同じ script が `glab api` の呼び出しも判定する。ask の項目の `glab api` は auto モードでは classifier に任せるが、この規則の `ask` はモードによらず prompt を出す（下の モード別の実測）。permission 規則で閉じない理由は issue #105 — 引数順・表記のバリエーションを規則で網羅できず、docs も引数を縛る Bash 規則は security boundary でないと注記している。

ask の項目（`git push`・`glab api`・`curl` など 25 件）も同じ script が持ち、settings の `permissions.ask` は空にしてある。狙いは「auto モードでは確認無しで classifier が判定し、それ以外のモードでは確認が出る」。settings の ask ではこれを書けない — rtk が書き換えた呼び出しでは効かず classifier へ回り、書き換えが無い呼び出しでは auto モードでも prompt を出す（下の モード別の実測）。hook は auto 以外（`permission_mode` が読めないときを含む）でだけ `ask` を返し、auto では無出力にする。

**スクリプト:** [hooks/permission-extension.ps1](hooks/permission-extension.ps1)
- 判定仕様（段の分け方、`allow` / `ask` / 無出力 の 3 分岐とその条件・理由）は `hooks/permission-extension.ps1`（冒頭コメントと `[regex]::Split` の分割パターン）が正本。無出力の経路は下の `permissions.allow` のバレットが受ける
- handler は `if` 無しで登録し、全 Bash 呼び出しで script を回す。`if` と settings の permission 規則は前方一致で、`rtk proxy glab api …` のような wrapper 前置形を拾えない（docs の wrapper 剥がしは固定リストで `rtk proxy` を含まない）。代償は呼び出しごとの powershell.exe 起動と、`ask` へ落ちる段が増えること（`git rm`、`glab mr create --description "see api docs"`、それらの語を含む自由文を argv に載せる MR タイトル・commit メッセージのような形）。stdin/JSON が読めないときに `ask` へ倒す fail-closed も、`if` があった頃の `rm` 呼び出し限定から全 Bash 呼び出しへ射程が広がっている
- `permissions.ask` は空にしてある — 評価順は deny → ask → allow で、ask に残すと hook の allow も prompt に負ける（docs: Extend permissions with hooks）。項目の一覧は `hooks/permission-extension.ps1` の `$askPrefixes` と `$alwaysAskPrefixes` が正本
- MR のマージ（`glab mr merge` / `gh pr merge`）は、auto モードで classifier が既定ルール `Merge Without Review` で block し、ask へのフォールバックが無い（!98 で実測、`autoMode.allow` の例外を置いても非決定的に block された）。そのため `$alwaysAskPrefixes` に分け、モードによらず `ask` を返して block の代わりに prompt を出す
- マージ後の後処理（base への切り替え・ff-only の pull・マージ済み branch の削除）は auto モードでは classifier が判定し、`Merge Without Review` で block されうる（!97 で実測）。`settings.json` の `autoMode.allow` に `"$defaults"` と、リポジトリを限らない例外の 1 文を置いて塞ぐ。マージは git-workflow のマージ手順でユーザーの指示を受けてだけ行い、MR のレビューは会話の中で行うため。例外の文はマージ本体も含む。`glab mr merge` / `gh pr merge` で始まる段には hook の `ask` が先に効き、例外が効くのはサブコマンドの前にフラグや環境変数を置く形（`glab -R a/b mr merge`）のような前方一致に当たらない形だけで、その形は auto モードで確認なしに通りうる。`autoMode` はユーザー設定からしか読まれない
- 代わりに `permissions.allow` へ `Bash(rm .tmp/*.md)` / `Bash(cd:*)` を掲載してある。リスト照合は段ごとに効くので、連結した呼び出しで hook が無出力に倒したときここが受ける（`cd <dir> && rm .tmp/<file>` の `cd` 段も同じで、規則が無いと段判定が揃わず classifier 送りになる。`cd` 自体は cwd を変えるだけ）。ワイルドカードは `.*` に展開され `..` も他ディレクトリも止めないが、その形は hook が先に `ask` を返す

**注意点:**
- PowerShell で書くのは、本 repo が `core.autocrlf=true` で checkout が CRLF になり、bash スクリプトだと変数値に `\r` が混ざって正規表現が壊れるため
- stdin の読み方（`-WindowStyle Hidden` では `[Console]::In` が空なので raw handle で読む）・ASCII 縛り・fail closed の理由は `hooks/permission-extension.ps1` の冒頭コメント

**モード別の実測**（2026-09-09、hook 起動後の新セッションで確認）:

| モード | `rm .tmp/probe-c`（hook が `allow`） | `rm .tmp/probe-d ../probe-d`（hook が `ask`） |
|---|---|---|
| auto | prompt 無しで実行 | prompt が出る |
| Manual（`permission_mode: "default"`） | **prompt が出る**（hook は起動し `allow` を返しているのに勝てない） | prompt が出る |

- 2026-09-15 実測（auto モード）: `permissions.ask` に `Bash(glab api:*)` を掲載したままでも、hook が `ask` を返す `glab api --method DELETE --help` で prompt が出る（`--help` は cobra が RunE の前に処理するので DELETE リクエストは飛ばない）
- hook が返す `ask` は auto モードでも prompt を出す
- 2026-09-24 実測（auto モード、2.1.281）: settings の `permissions.ask` は、rtk が書き換えた呼び出し（`git stash list && echo PROBE4`）では prompt を出さず classifier が判定する（docs の "explicit ask rules … still block or prompt" と食い違う）。書き換えの無い呼び出し（`git switch main` 単体）では prompt が出る。hook の `ask` は rtk の書き換えがあっても prompt を出す
- 2026-09-28 実測: hook の stdin の `permission_mode` は auto モードで `"auto"`（hook に stdin を `.tmp/` へ書き出させて確認）

---

## 🔗 PostToolUse Hook（改行コードをCRLFに正規化）

Claude Codeの `Write` / `Edit` は改行コードに LF を使う傾向があるため、Windows環境では CRLF に揃えたいケースがある。`PostToolUse` フックで `Write` / `Edit` / `MultiEdit` / `NotebookEdit` 実行後に対象ファイルを LF → CRLF へ正規化する。

**対象ファイル:** 拡張子ベースでテキストファイル全般を判定（`.md` / `.txt` / `.json` / `.yml` / `.cs` / `.csproj` / `.ts` / `.js` / `.py` / `.html` / `.css` / `.sh` / `.ps1` / `Dockerfile` / `Makefile` など）。バイナリや対象外拡張子はスキップ。

**スクリプト:** [hooks/lf-to-crlf.sh](hooks/lf-to-crlf.sh)
- `tool_input.file_path` / `tool_input.notebook_path` から対象ファイルを取得
- 既存の `\r` を一度剥がしてから全行に `\r` を付与するため、LF/CRLF 混在ファイルでも CRLF に統一される

**前提:**
- `jq` が必要
- **現在このHookは `settings.template.json` に登録していない**（Git for Windows の `core.autocrlf=true` が追跡ファイルの改行を CRLF にするため）。使う場合は `hooks.PostToolUse` に自分で追加する

> ⚠️ `.gitattributes` で `text eol=lf` を強制しているプロジェクトでは git 側と衝突する可能性があるため、除外が必要な場合は `lf-to-crlf.sh` の拡張子リストから外すこと。

---

## 🔗 Stop / Notification Hook（待ちになったらポップアップ通知）

Claude Code の応答が終わって指示待ちになったとき（`Stop`）と、承認待ち・入力待ちになったとき（`Notification`）に Windows のメッセージボックスを表示する。

**スクリプト:** [hooks/notify.ps1](hooks/notify.ps1)
- `GetForegroundWindow` で前景ウィンドウのプロセスを取得し、VSCode（`Code` / `Code - Insiders` / `Code - OSS`）なら通知せず終了する（見えている画面に出しても意味がないため）
- それ以外のときだけ `MessageBox` を表示する
- `-Message` で本文を差し替える。`Stop` と `Notification` で同じスクリプトを使い回す

**注意点:**
- **`-File` は `~` を解決しない**（`-File パラメーターの引数 '~\...' は存在しません` で失敗する）。`-Command ". '~\...'"` で PowerShell 側にパスを解決させること
- `MessageBoxOptions.DefaultDesktopOnly` は `Show()` の**第6引数**。第5引数は `MessageBoxDefaultButton` なので、`'Button1'` を省くと型変換エラーで落ちる
- `MessageBox::Show` はボタンが押されるまでブロックする。Hook がタイムアウトするまで次のターンが始まらない
- **auto モードでは ask の項目のコマンドも確認なしで実行される**（`hooks/permission-extension.ps1` が auto では無出力にし、classifier が判定する）ため、承認プロンプト自体が出ず `Notification` も発火しない。承認待ちの通知が欲しい場合は auto モードを使わないこと（例外: hook が返す `ask` は auto モードでも prompt を出すので、`.tmp/` 外の `rm`、書き込み形でない `glab api`、`glab mr merge` / `gh pr merge` で始まる段では auto でも `Notification` が発火する）

---

## 📝 備考

- `settings.template.json` はgit管理対象。チーム共有の設定テンプレートとして管理する
- `settings.json` はClaude Code CLIが自動管理するファイルのため、git管理対象外
- hook スクリプトを改名・撤去したときは、各 PC の `settings.json` の該当行も手で直す。旧パスのまま残ると hook は非 block のエラー（`exit 1`）で終わり、ガードが黙って無効になる
- Claude Codeのアップデートは自動で行われる（バックグラウンド）
