# Setup Instructions (for AI agents)

この repo を渡された Codex / AI agent は、以下をそのまま実行すればセットアップが完了する。

## 0. Prerequisites

`install.sh` が MISSING を報告した command は、公式手順に従って agent がインストール・認証まで行う。この repo 独自のインストール手順は持たない。常に公式を正とする。

| command | 公式 | 補足 |
|---|---|---|
| `codex` | https://github.com/openai/codex | インストール後、公式手順に従い認証する |
| `superset` | https://superset.sh | インストール後、認証し `superset status` が通ること、Experience v2 mode が有効であることを確認する |
| `gh` | https://cli.github.com | `kei-create-pr` を使う場合のみ。`gh auth status` で認証確認 |

インストール・認証が済んだら `./install.sh` を再実行して MISSING が消えたことを確認する。

## 1. Install

```bash
git clone https://github.com/kei-prog/superset-handoff-flow.git
cd superset-handoff-flow
./install.sh
```

`install.sh` は冪等で、次を行う:

- 前提 command の確認: `git`（必須）、`codex`、`superset`、`gh`（`kei-create-pr` を使う場合のみ）
- `skills/*` を `~/.codex/skills/` に個別 symlink（既存の実体ディレクトリがある場合は上書きせず SKIPPED と報告）
- 導入検証: 各 skill の `SKILL.md` が symlink 経由で読めること、`codex-review` helper が実行できること

exit code `0` で全 skill 導入済み。非 0 の場合は SKIPPED / FAILED / MISSING 行を報告し、勝手に既存 skill を上書きしない。

## 2. Verify

新しい Codex セッションで次を確認する:

1. `$kei-superset-implementation-handoff` を呼び、skill が読み込まれる
2. 内部依存の `$kei-handoff` が読み込める
3. Codex では skill が `$skill名` の形で候補表示・発動されることがあるため、上記の `$skill名` 形式でも確認する
4. `superset --version` と `superset status` が通る（未認証なら手順 0 に戻って認証する）
5. Superset の Experience v2 mode が有効である（確認できない場合は、ユーザーに Superset app で有効化してもらう）
6. `~/.codex/skills/codex-review/scripts/codex-review --help` が usage を表示する

## 3. 試用

ユーザーが「試しに利用してみるまで」と依頼した場合は、セットアップだけで止めず、次まで案内する:

1. push / PR / deploy をしないことを明示する。
2. 原則として disposable な local git repo を作る。作れない場合だけ、ユーザーに試用対象 repo を 1 つ選ばせる。
3. READMEに1行を追加する程度の小さいリポジトリ単位のタスクについて、問題、期待結果、成功条件、制約、対象外を会話で明確にし、実装を止める未確定事項が0件であることを確認する。
4. `$kei-superset-implementation-handoff`を使う。引継ぎ準備の判定と実装指示への変換は内部で`$kei-handoff`が行う。
5. 表示された実装指示全文、モデル、推論レベル、起動方式を確認し、問題なければOKと明示する。OK前はworkspace（作業領域）、agent（エージェント）、terminal（ターミナル）が作成されないことを確認する。
6. 既定モデルが実際に起動するCodex CLIの`codex debug models`にない場合は黙って変更せず、CLI更新または利用可能な代替モデルをユーザーに選ばせる。
7. SupersetのExperience v2 mode、project、workspace、agent設定が足りない場合は推測で進めず、ユーザーが次に行う操作を1つずつ具体的に指示する。
8. OK後、子エージェントのworkspace / worktree、使用モデル / 推論レベル、渡したタスク、変更ファイルを確認して報告する。

## 4. 報告

セットアップ報告には次を含める:

- install.sh の exit code と SKIPPED / FAILED の有無
- 前提 command のうち MISSING だったもの
- Verify 6 項目の結果
- 試用を実施した場合はworkspace / worktree、承認したモデル / 推論レベル、渡したタスク、変更ファイル、push / PR / deployをしていないこと

## Notes

- skill 内の `<org>/<repo>`、`<your-clones-root>`、`pnpm ci:check` は placeholder。対象 repo に合わせて読み替える。
- update 時は repo を `git pull` するだけでよい（symlink なので反映は即時）。
