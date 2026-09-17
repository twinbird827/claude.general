# WebFetch ルーティングの実測記録

## 計測条件

- 計測日: 2026-08-04
- 長文検証: https://www.rfc-editor.org/rfc/rfc7231.txt （RFC 7231）
- JS 検証: https://todomvc.com/examples/react/dist/ （TodoMVC React）
- 出典: MR !36 の commit「fix: route web fetching away from WebFetch based on measurements」（当時 `5bb864b`）のメッセージ本文。以下の本文・数値・表はすべてそこからの逐語転記。
- 本ファイルのうち**計測日・URL・見出しは commit 由来ではない**（commit 本文にはいずれも含まれない）。

## WebFetch の 2 つの失敗

WebFetch は取得内容を小型モデルに要約させて返すため、二つの失敗が起きる。実測で確認した。

1. 長文の切り捨て RFC 7231（235,053 bytes）を取得させたところ 101 ページ中 39 ページで切断。このときは "truncated" と自己申告した。

2. JS 未実行の空シェルを申告せず返す TodoMVC React（素の HTML は 645 bytes、本文は JS 実行後にのみ出現）に対し「空なら EMPTY BODY と答えよ」と明示しても、静的な footer 3 行だけを完成した回答の体裁で返した。todos 見出し、フィルタ、件数表示は全て欠落。

## 同一 URL に対する 4 ツール比較

同じ URL に対する各ツールの実測:

| ツール | 結果 |
|---|---|
| WebFetch | footer 3 行のみ。欠落の申告なし |
| web_url_read | footer 3 行のみ。生テキストなので薄さが目で見える |
| firecrawl_scrape | 完全にレンダリング（todos / 0 items left! / All-Active-Completed） |
| Playwright | 完全にレンダリング（navigate + evaluate の 2 コール） |

## 分岐条件の結論

「JS ページなら firecrawl」というルールは成立しない。JS かどうかは取得前に判定できず、WebFetch の失敗は無申告のため取得後にも気付けない。分岐条件を「取れた内容が不自然に薄いか」という取得後に観測可能なものへ置き換える。

## 検索側（searxng_web_search vs WebSearch）

検索側は実測で差がなかった。同一の日本語クエリで searxng_web_search と WebSearch の上位 3 件が一致したため、優劣を定めず併記に留める。
