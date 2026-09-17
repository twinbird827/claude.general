# 生成テンプレート

プレースホルダ `[...]` は実コードから埋める。

以下の各ブロックは書式の例示であって、生成するファイルをフェンスで囲む指定ではない。

---

## A. CODEBASE/CODEMAPS/INDEX.md（全エリア概要）

```markdown
# アーキテクチャ地図：INDEX

- **最終更新:** YYYY-MM-DD
- **対象:** [リポジトリ名]
- **主言語 / FW:** [例：C# / .NET Framework 4.8、Python 3.11 / FastAPI]

## システム全体像

[コンポーネント関係の ASCII 図。例：]

    [UI/入口] --> [アプリ/サービス] --> [ドメイン] --> [データ/DB]
                        |
                        +--> [外部連携: 決済 / メール / 他システム]

## エリア一覧

| エリア | 説明 | ドキュメント |
|---|---|---|
| 概要 | 全体構成と主要ディレクトリ | [overview.md](overview.md) |
| バックエンド | サービス/API/処理 | [backend.md](backend.md) |
| フロントエンド | 画面/UI | [frontend.md](frontend.md) |
| データ | DB スキーマ/モデル | [database.md](database.md) |
| 外部連携 | 外部サービス | [integrations.md](integrations.md) |
| ジョブ | 常駐/バッチ | [jobs.md](jobs.md) |

（存在しないエリアの行は作らない）

## 主要エントリポイント

- `[path/to/entry]` — [起動/役割]

## 未確認・要確認事項

- [人間の確認が必要な点]
```

---

## B. エリア別 CODEMAP（backend.md 等・共通形）

```markdown
# [エリア名] アーキテクチャ

- **最終更新:** YYYY-MM-DD
- **ランタイム/FW:** [例：ASP.NET Core / Windows Service]
- **エントリポイント:** [主要ファイルのリスト]

## 構造

[このエリアのディレクトリツリー（主要のみ）]

    src/[area]/
    ├── [dir]/        # 役割
    └── [dir]/        # 役割

## 主要モジュール

| モジュール | 目的 | 公開API/エクスポート | 依存 |
|---|---|---|---|
| [file:line] | [責務] | [公開関数/クラス] | [依存先] |

## データフロー

[入口 → 処理 → 出口 の流れを 1〜3 行で。例：]

    リクエスト → [Controller] → [Service] → [Repository] → DB → レスポンス

## 外部依存

- [パッケージ/サービス名] — 目的（バージョンは判明時のみ）

## 関連エリア

- [database.md](database.md) 等、相互作用する map へのリンク
```

（API/ルートが主体のエリアは「主要モジュール」表の代わりに以下を使う）

```markdown
## エンドポイント / ルート

| ルート | メソッド | ハンドラ (file:line) | 目的 |
|---|---|---|---|
| /api/... | GET | [file:line] | [説明] |
```

---

## C. README.md（新規生成。既存があれば README.generated.md）

```markdown
# [プロジェクト名]

[1〜3 行の説明。何をするシステムか]

## 必要環境

- [言語/ランタイム バージョン]
- [DB / 外部サービス]

## セットアップ

（マニフェスト/スクリプトに**実在するコマンドのみ**記載。言語別の例：）

    # .NET
    dotnet restore
    dotnet build
    dotnet run --project [path]

    # Python
    pip install -r requirements.txt   # または: uv sync / poetry install
    python [entry].py

    # Node
    npm install
    npm run [script]

    # PowerShell モジュール
    Import-Module ./[module].psd1

## 設定

`.env.example`（または appsettings/config）を複製し、以下を設定：

| キー | 用途 |
|---|---|
| [KEY] | [用途] |

（※ 値・シークレットは記載しない。キーと用途のみ）

## ディレクトリ構成

- `[dir]/` — [役割]

## 主要機能

- [機能] — [説明]（該当 `file:line`）

## ドキュメント

- [アーキテクチャ地図](CODEBASE/CODEMAPS/INDEX.md)
- [オンボーディング](CODEBASE/ONBOARDING.md)
```

---

## D. CODEBASE/ONBOARDING.md（新規参加者向け）

```markdown
# オンボーディングガイド

- **最終更新:** YYYY-MM-DD

このシステムを初めて触る人が、最短で全体像を掴み、動かし、変更できるようになるための道案内。

## 1. これは何か

[システムの目的・利用者・解く課題を 3〜5 行]

## 2. まず読む順路

1. [README.md](../README.md) — セットアップと概要
2. [CODEBASE/CODEMAPS/INDEX.md](CODEMAPS/INDEX.md) — 全体構造
3. エントリポイント `[path]` — 実行がここから始まる

## 3. 主要な実行フロー（1本の筋を追う）

[代表的な1ユースケースを、入口から出口まで file:line で辿る]

    [入口 file:line] → [処理 file:line] → [データ file:line] → [結果]

## 4. 規約・お作法

- [命名/レイヤ/エラー処理などコードから読み取れる規約]
- [ビルド/テスト/実行コマンド]

## 5. よく触る場所と注意点

- [機能追加時に触るファイル群]
- [壊しやすい不変条件・落とし穴（コードから確認できたもの）]

## 6. 未確認・要確認

- [ドキュメント化にあたり判断できず、人の確認が要る点]
```

---

## 品質ルール（全テンプレ共通）

- 各 CODEMAP は 500 行未満。
- 表の各行は実在する `file:line` に接地。
- 言及するファイルパスはすべて実在する（Glob/Read で確認）。
- 内部リンクは有効（相対パスが正しい）。存在しない・古い参照を残さない。
- コマンドはマニフェスト/スクリプトに実在するものだけ。
- ASCII 図は実際の構造と一致する。
- `最終更新:` を持つ文書（`- **最終更新:**` 形を含む）はその値を system context の currentDate にする。
- シークレット/実値は書かない（キー名と用途のみ）。
- 確認できないことは「未確認」。埋め合わせの推測をしない。
