---
name: simplification-review
description: 'Over-engineering review of a diff, commit range, PR/MR ref, or file — what to delete, what stdlib or the platform already does, speculative abstractions, dead flexibility. Wraps ponytail:ponytail-review and keeps only findings that hold against the real file. Read-only. Args: [target]. Launched only by code-review-runner; not for direct use.'
user-invocable: false
---

# simplification-review

## 引数

- 対象: `~/.claude/references/review-criteria.md` の レビュー対象引数。

## 手順

1. `~/.claude/references/review-criteria.md` を読む。対象を解決する。
2. `Skill` で `ponytail:ponytail-review` を対象付きで呼ぶ。
3. 返った各行を実ファイルの該当箇所に当て、噛み合わない行を捨てる。
   - 対象違い — 差分外、存在しない場所、すでにそうなっている。
   - 仮説 — 実ファイルで成立を確認できない。
4. 残った行を review-criteria の 指摘の形 に整える。重大度は原則 Minor、振る舞いが変わるものだけ Major。
5. 出力する。

## 出力（日本語）

- 1 行目: `対象: <トークンか既定>`
- 2 行目: `捨てた: 対象違い <a> / 仮説 <b>`
- 指摘ごとに `SR-<n>` で 1 ブロック。
- 指摘がゼロなら `指摘なし`。
