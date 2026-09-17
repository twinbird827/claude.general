# keep-turn — スキル実行中のターン継続ガード

marker `<cwd>/.tmp/keep-turn` が存在する間、Stop hook がターン終了を拒否する。機構・登録・導入経緯は `README.md` の Stop Hook 節、marker の契約は本文書。使うスキルは entry で本文書を Read し、以下を再掲せず参照する。

- **作る**: スキルの entry で `Write` により作る。内容は任意の 1 行でよい。`Write` が親ディレクトリを作るので `mkdir` は要らない。
- **消す**: ターンを終えるすべての地点で、出力の直前に `cd <cwd> && rm .tmp/keep-turn` の形で実行する（`<cwd>` は marker と同じセッションの cwd）。フルパス形 `rm <cwd>/.tmp/keep-turn` は `permissions.allow` の `Bash(rm .tmp/keep-turn)` に一致せず毎回 prompt が出る。照合は段ごとで、`cd` 段は `Bash(cd:*)` が受ける。残すと hook が終了を拒み、ハーネスの上限（連続 8 回）まで block が続く。どこがその地点かは各スキルが自分で列挙する。
- **作り直す**: ユーザーの回答を受けて entry を通らずに続きを実行するときは、再開後の最初のツール呼び出しで作り直す。
- **前景で回す**: marker が有効な間に起動する subagent は `run_in_background: false` にする（Agent tool の既定は背景）。背景起動は待つためにターンを終えようとし、Stop hook の block が上限までループする。同一メッセージ内の複数 tool call は前景のまま並行実行されるので、並列起動は失われない。
