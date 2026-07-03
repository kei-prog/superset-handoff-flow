# Setup Instructions (for AI agents)

この repo を渡された Codex / AI agent は、以下をそのまま実行すればセットアップが完了する。

## 0. Prerequisites

`install.sh` が MISSING を報告した command は、公式手順に従って agent がインストール・認証まで行う。この repo 独自のインストール手順は持たない。常に公式を正とする。

| command | 公式 | 補足 |
|---|---|---|
| `codex` | https://github.com/openai/codex | インストール後、公式手順に従い認証する |
| `superset` | https://superset.sh | インストール後、認証し `superset status` が通ることを確認する |
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
2. `superset --version` と `superset status` が通る（未認証なら手順 0 に戻って認証する）
3. `~/.codex/skills/codex-review/scripts/codex-review --help` が usage を表示する

## 3. Report

セットアップ報告には次を含める:

- install.sh の exit code と SKIPPED / FAILED の有無
- 前提 command のうち MISSING だったもの
- Verify 3 項目の結果

## Notes

- skill 内の `<org>/<repo>`、`<your-clones-root>`、`pnpm ci:check` は placeholder。対象 repo に合わせて読み替える。
- update 時は repo を `git pull` するだけでよい（symlink なので反映は即時）。
