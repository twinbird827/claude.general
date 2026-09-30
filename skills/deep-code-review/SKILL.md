---
name: deep-code-review
description: 'Supplementary review of the layers standard-code-review structurally misses — codebase-wide spread of the same bug, root cause vs symptomatic fix, design ripple, silent failures, regression tests — with per-language failure-mode packs (C#/VB6/VBS/PowerShell/Python). Read-only. Args: [target]. Used standalone and by code-review-runner.'
when_to_use: '"コードレビューして", "深くレビューして", "横展開を見て", "PR を見て"'
---

# deep-code-review

standard-code-review が構造的に見ない層だけを担当する。修正しない。

## 担当外

- 差分内の正確性（null・例外・境界値）と CLAUDE.md 準拠 — standard-code-review。
- 削除・簡素化 — simplification-review。
- 命名の nit。

## 手順

1. `~/.claude/references/review-criteria.md` を読む。対象を差分に解決する。
2. 差分が触るファイルの言語を拡張子で判定し、該当する言語パック `${CLAUDE_SKILL_DIR}/references/{csharp,vb6,vbs,powershell,python}.md` だけを読む。
3. 5 つの層を順に当てる。
   - 横展開 — 差分が直したのと同型の箇所を repo 全体から grep で探す。grep は自分で打ち、subagent へ委譲しない。
   - 根本原因 — 修正が症状だけを塞いでいないか。
   - 設計波及 — 呼び出し側・契約・他モジュールへの影響。差分が新設した処理と同等の既存資産を repo から grep で探す。
   - 静かな失敗 — 握り潰された例外、空の catch、無視された戻り値。
   - 再発防止 — 直したバグを固定する回帰テストの有無。
4. 各候補を review-criteria の 重大度 と クラス で採点する。
5. 出力する。

## 出力（日本語）

- 1 行目: `対象: <トークンか既定>`
- 指摘ごとに `DC-<n>` で 1 ブロック（review-criteria の 指摘の形）。
- 指摘がゼロなら `指摘なし`。
