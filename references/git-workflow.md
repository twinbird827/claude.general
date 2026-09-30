# Git 操作の手順（branch / commit / MR / issue）

GitHub の PR も本文書では MR と呼ぶ。「止まる」は、以降を実行せずユーザーへ報告して止まること。

- コマンドと state の値は `git-hosting/<hosting>.md` の表から引き、本文書は表の 操作 列の名前を「MR を見る」のように書く。
- 本文書のコマンドは Bash tool（Git Bash）で実行する — どちらの hosting の表も MR 作成で `git push -u origin HEAD && …` の `&&` 連結を使い、PowerShell 5.1 は `&&` を解釈しない。
- GitLab Free は MR 本文に版履歴が無く上書きが不可逆なので、本文を書き換える手順は原本保存と突合を省かない。
- 追跡ファイルに未コミットの変更が残っているなら（未追跡ファイルは問わない）、実装直後 節・規則 節・起票 節 以外のどの節にも進まず止まる。

## 規則

- **hosting は `git remote -v` の URL ホスト名で決める**（`gitlab` を含む → `gitlab`、`github` を含む → `github`）。表の無い hosting と本文書の停止条件では報告して止まり、代替を発明しない。
- **base ブランチへ直接 commit しない。必ず branch + PR を経由する。**
- **ブランチ基点は機械的に判定**: 対象ファイルが base に存在 → base から分岐し base へ PR。current にしか無い → current から分岐し current へ PR。
- **分岐元の解決**:
  - base は remote の default branch。`git symbolic-ref refs/remotes/origin/HEAD` の出力から `refs/remotes/origin/` を除いた名前。引けなければ止まる。
  - current branch が base でないとき、「MR を見る」で current branch の MR が引け、その target が base でなければ target が親ブランチ（current 基点）。
  - MR が引けなければ base 基点。
- **混在時は PR 分割**: base 存在ファイルの変更は base 基点で base へ、current 専用ファイルの変更は current 基点で current へ。base 存在ファイルを current 向け PR で変更しない。
- **base は current に依存しない**: base に存在するファイルへ current 専用資産への参照を持ち込まない。必要なら base 側に汎用の拡張点を base PR で追加し、current 側で接続する。
- **依存順**: current 側変更が base 側変更を前提とする場合、base PR マージ → current を base で更新 → current 側 PR の順。
- **PR 本文に調査・計画・実装内容を含める**。
- **Issue に紐づく修正は自動クローズ条件を揃える**: PR 本文に closing keyword（`Fixes #N` / `Closes #N` / `Resolves #N`）を明記（「Issue #N:」は参照のみで閉じない）。条件が揃えられない場合（default branch 宛でないマージ・別リポジトリの issue 等）は、マージ後に手動クローズが必要な旨をユーザーへ明示する。
- **MR 作成依頼・実装完了・マージ指示が来たら、「〜しますか？」と聞いてターンを終えず該当手順を実行する**（permission prompt が出るのは構わない）。指示を待つのはマージ本体だけ。
- issue / MR の本文はファイル（`.tmp/` 配下）で渡し、argv へ直書きしない。
- プロセス置換 `<(…)` を使わない（allow 掲載済みでも permission 照合から外れ毎回 prompt が出る）。
- プロジェクト固有の例外は各プロジェクトで指定する。

## 起票

1. 「issue 検索」で重複を確かめる。既存があれば起票せず、その番号を報告する。
2. レビュー由来の起票（code-review-to-plan のスコープ外指摘）は finding-verifier の CONFIRMED を経たものだけ起票する。ユーザーが直接依頼した起票にはこの条件を掛けない。
3. 本文を `.tmp/` に書き、「issue 作成」に title と本文ファイルを渡す。成功したら本文ファイルを消す。
4. レビュー由来の起票は、issue 番号をプランの 決定記録 の 事実 へ 1 行で記録する。

## 実装直後

1. 規則 節 の ブランチ基点 判定で分岐元を決める。current branch がその分岐元そのものなら branch を切り、分岐元から分かれた既存のブランチにいるなら切らずそのまま続ける（無条件に切ると、open MR のあるブランチで実装した回に 2 本目の MR が立つ）。
2. commit する。
3. 手順 1 で branch を切ったなら MR 作成 節 へ、切らずに続けたなら 既存 MR のブランチで実装を終えたとき 節 へ。

## MR 作成

1. 本文を repo 内の gitignore 済み `.tmp/` に書く。載せる内容（調査・計画・実装内容、closing keyword）は 規則 節。
2. 宛先は 規則 節 の ブランチ基点 判定で決め、「MR 作成」に title・本文ファイル・宛先を渡す。push は「MR 作成」の行が含む。
3. 「MR 作成」が成功したら（MR の URL か番号が返る）、手順 1 の本文ファイルを消す。失敗したら消さず止まる（本文を作り直させない）。

## 既存 MR のブランチで実装を終えたとき

1. push する。「MR を見る」が current branch の MR を引けなければ、この節でなく MR 作成 節。
2. 「MR を見る」で番号・state・head sha を取る。state が 開いている の値でなければ止まる。head sha がローカルの HEAD の sha と一致しなければ、push が届いていないか MR が別の内容を指しているので止まる。
3. 本文の上書き 節の手順で実装内容を追記する。

## マージ指示を受けたとき

手元で作業していない MR（source branch のローカル ref が無い）では手順 2 の sha 突合を飛ばす。

1. 「MR を見る」で番号・state・target・source・head sha を取る（current branch が対象でなければ「MR 一覧」で番号を確かめ、番号を渡して見る）。state が 開いている の値でなければ止まる。
2. ローカルの `<source>` の sha が手順 1 の head sha と一致しなければ、未 push のコミットがあるか MR が別の commit を指しているので止まる。
3. 「MR をマージ」。
4. 手順 1 の番号を渡して「MR を見る」。state が マージ済み の値でなければ止まる（引数なしで引かない — マージでローカル branch が消える hosting では current branch から解決できない）。
5. `<target>` へ切り替え、fast-forward だけを許す pull と prune。ローカルに `<source>` が残っていれば、マージ済みでなければ拒否される削除で消す。拒否されたら `-D` へ上げず止まる。

## 本文の上書き

1. 原本取得: 「MR 本文を取得」の出力を `.tmp/mr-<N>-orig.md` へ書き、非空かつ `null` でないことを確かめる。
2. 編集: `.tmp/mr-<N>-new.md` へコピーして `Edit` で反映する。
3. 事前突合:
   - `diff --strip-trailing-cr .tmp/mr-<N>-orig.md .tmp/mr-<N>-new.md` で差分が意図した箇所だけであること（`--strip-trailing-cr` が要る理由は `git-hosting/gitlab.md` の「MR 本文を置換」行の 注意 — GitLab 固有の実測だが hosting を問わず付ける。手順 5 も同じ）。
   - `grep -oiE "(closes|fixes|resolves) #[0-9]+" .tmp/mr-<N>-orig.md > .tmp/mr-<N>-keys.txt` を書いてから、`grep -oiE "(closes|fixes|resolves) #[0-9]+" .tmp/mr-<N>-new.md | diff .tmp/mr-<N>-keys.txt -` が空であること。件数比較でなく番号の一覧で突合する — 差し替えを見逃すと自動クローズが沈黙で壊れる。
   - 差分が出ても、意図して増減させたときと、番号の集合が同じで並びだけ入れ替わったときは進んでよい。closing keyword が 1 つも無い MR では 1 本目の `grep` が終了コード 1 を返すが、`-keys.txt` が空なら正常で止まらない。
   - `| sort` を挟まない（allow 未掲載）。
4. 反映: 「MR 本文を置換」に `.tmp/mr-<N>-new.md` を渡す。
5. 事後突合: 「MR 本文を取得」で `.tmp/mr-<N>-after.md` へ再取得し、`diff --strip-trailing-cr .tmp/mr-<N>-new.md .tmp/mr-<N>-after.md` が差分なし（末尾改行の有無のみ許容）であることを確認する。切り詰めやメタ行混入は突合しない限り沈黙する。
6. 復元: 手順 5 の突合が通るまで `-orig.md` を消さず、壊れていたらそれで戻す。通ったら `-orig.md` / `-new.md` / `-after.md` / `-keys.txt` の 4 本を消す。
