---
name: simplification-review
description: 'Over-engineering review of a diff, commit range, PR/MR ref, or file — what to delete, what stdlib or the platform already does, speculative abstractions, dead flexibility. Wraps ponytail:ponytail-review and keeps only findings that hold against the real file, plus comments that break the ## コードコメント rule in ~/.claude/CLAUDE.md. Read-only. Args: [target]. Launched only by code-review-runner; not for direct use.'
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
4. 対象に含まれるコメント（差分なら追加・変更された行、ファイルパスならファイル全体）を `~/.claude/CLAUDE.md` の `## コードコメント` 節に照らし、反するものを指摘候補に足す。候補は該当行を実ファイルで読んで確かめたものだけにし、確かめられず捨てた候補は 仮説 に数える。
5. 残った行と手順 4 の候補を review-criteria の 指摘の形 に整える。重大度は原則 Minor、振る舞いが変わるものだけ Major。
6. 出力する。

## 出力（日本語）

- 1 行目: `対象: <トークンか既定>`
- 2 行目: `捨てた: 対象違い <a> / 仮説 <b>`
- 指摘ごとに `SR-<n>` で 1 ブロック。
- 指摘がゼロなら `指摘なし`。
