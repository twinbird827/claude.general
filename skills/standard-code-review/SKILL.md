---
name: standard-code-review
description: 'Standard correctness review of a code diff — high-confidence bugs and CLAUDE.md compliance. Read-only, never fixes, never posts comments. Args: [target] [effort medium|high] (default medium). Used standalone and by code-review-runner. For spread / root-cause / design-ripple / silent-failure lenses use deep-code-review.'
when_to_use: '"コードレビューして", "PR を見て", "この差分を確認", "code review"'
---

# standard-code-review

差分の正確性レビュー。修正しない。コメントも投稿しない。

## 引数

- 対象: `~/.claude/references/review-criteria.md` の レビュー対象引数。
- effort: `medium`（既定）または `high`。

## 手順

1. `~/.claude/references/review-criteria.md` を読む。
2. 対象を差分に解決する。
3. lens を順に当てる。同じセッション内で逐次に行い、subagent へ分けない。
   - A. Bug scan — 変更 hunk だけを読み、変更自体の大きなバグを走査する。nitpick と偽陽性になりそうなものは無視し、変更の外へ読みに行かない。
   - B. CLAUDE.md compliance — 該当 CLAUDE.md（repo root と、diff が触るディレクトリのもの）に照らす。CLAUDE.md が明示する項目だけを挙げる。
   - C. History（`high` のみ）— 変更されたコードの blame / log。履歴文脈でだけ見えるバグ。
   - D. In-code guidance（`high` のみ）— 変更されたファイル内のコメントが書く指針に変更が従っているか。
4. 各候補を review-criteria の 重大度 と クラス で採点する。
5. 出力する。

## 報告しないもの

- 既存の不具合（差分が持ち込んだのでないもの）。
- linter・CI が捕るもの。
- CLAUDE.md が明示しない一般的な品質要望。
- Nit。CLAUDE.md が明示する項目は例外。
- 意図的な挙動変更。
- コード内で明示的に黙らせた CLAUDE.md 項目。
- Minor / Nit で、未確認の前提が 1 つでも残るもの（読んだだけの推測、成立条件が未確認、決め手が一次証拠でない）。Critical / Major は残す。

## 出力（日本語）

- 1 行目: `対象: <トークンか既定> / effort: <値>`
- 指摘ごとに `SC-<n>` で 1 ブロック（review-criteria の 指摘の形）。
- 指摘がゼロなら `指摘なし`。
