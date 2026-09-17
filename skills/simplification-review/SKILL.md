---
name: simplification-review
description: 'Over-engineering review of a diff, commit range, PR/MR ref, or file: what to delete, what the stdlib or platform already does, speculative abstractions, dead flexibility. Read-only: never fixes, never posts comments. Accepts 修正案なし to omit the per-finding fix. Used as the over-engineering stream inside code-review-plan-loop and plan-refinement-loop.'
---

# simplification-review — 過剰実装レビュー

**First output line: echo the parsed args** — `対象: <target> / 修正案: <あり|省略（呼び出し元指定）>`。**All user-facing output in Japanese.**

## Target

- 引数のどこかに `修正案なし` トークンがあれば、指摘ごとの 修正案 を出さない（呼び出し元が解法の生成を止める指定）。位置は問わない。
- 対象引数の規約は `~/.claude/references/review-target.md`。

## Procedure

1. **`ponytail:ponytail-review` を Skill tool で呼ぶ** — 対象を引数で渡す。lens 規則（ラダー・タグ・出力形式）は plugin が正本で、ここには再掲しない。
2. **対象違いを捨てる** — 返った各行の 場所（`L<line>` / `L<from>-<to>`、多ファイル差分では `<file>:` 接頭辞付き）を当該ファイルの当該行へ当て、その行の内容が `<what>` の記述と噛み合わない指摘を捨てる。`finding-criteria.md` の 重大度 節「仮説だけの指摘は成立しない」に当たる外部ツール挙動の仮説も、ここで捨てる。捨てた行数は `捨てた: 対象違い <a> / 仮説 <b>` の 1 行にして、経路を問わず echo 行の直後に返す（0 件でも `0 / 0`）。全件噛み合わなければ全件捨て、その行に続けて `対象違い: plugin が渡した対象を読んでいない` の1行を返して止まる。
3. **生き残った1行を指摘へ起こす**:
   - **ID と重大度** — `~/.claude/references/finding-criteria.md` を Read し、ID 接頭辞は 共通フィールド 節、重大度は 重大度 節 の ponytail-review 段落に従う。
   - **場所** — 手順 2 で当てた行の逐語アンカー。範囲ならその指摘が名指しする構造の始まりの1行を取る。
   - **問題** — `<what>` をそのまま使う。
   - **根拠** — 1行から起こせないものは「ponytail-review の指摘（対象のみ、追加検証なし）」と明示する。
   - **クラス** — `finding-criteria.md` の クラス 節 のゲートを当てる。
   - **修正案** — `<replacement>`。`修正案なし` のときは行ごと省略する。
4. **`Lean already. Ship.` は指摘ゼロ** — 「指摘なし（過剰実装の観点で確認）」を返す。末尾の `net: -<N> lines possible.` は指摘ではない。

## Rails

- **Read-only: no fixes, no commits, no PR/MR comments.** 指摘は呼び出し元へ返すだけ。
