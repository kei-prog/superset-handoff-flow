---
name: kei-superset-implementation-handoff
description: 完成した Implementation Brief を kei-handoff で implementation agent 向け Agent Prompt に変換し、Superset workspace、agent、または Codex CLI terminal を起動して実行開始まで確認する。ユーザーが「Superset で実装を渡して」「Superset 経由で Codex に依頼」「kei-superset-implementation-handoff」と依頼した時に使う。Brief がなければ起動せず、先に kei-prepare-implementation-brief を使うよう案内する。
---

# Kei Superset Implementation Handoff

完成した Implementation Brief を Agent Prompt に変換し、Superset で起動して、Codex が実際に開始した証拠まで確認する。

標準のユーザー操作は `$kei-prepare-implementation-brief` → `$kei-superset-implementation-handoff`。内部フローは Brief → `$kei-handoff` → Agent Prompt → Superset launch。

この skill が所有するのは、起動許可、launch 直前の再確認、mode 選択、reasoning 設定、安全な command 実行、起動証拠、親 thread への報告だけ。実装判断は `$kei-prepare-implementation-brief`、子 agent への指示内容は `$kei-handoff` を正とし、この skill では再定義しない。

## Safety

- Superset workspace、agent、terminal の作成は外部状態変更として扱い、ユーザーが Superset handoff を明示的に依頼した場合だけ実行する。
- Superset 起動の許可を、push、PR 作成、deploy、production 変更、external service write の許可へ広げない。それらはユーザーが個別に明示した場合だけ Agent Prompt に含める。
- Brief または Agent Prompt に未解決の product decision、明示制約との衝突、secret、破壊的操作、資格情報不足がある場合は起動しない。
- 親 repo の uncommitted changes に依存する Brief を、それらが存在しない isolated worktree へ渡さない。
- Superset の auth、host、project、workspace、agent 設定が不足している場合は、広い setup 変更を行わず、正確な blocker と最小の next action を返す。
- JSON が利用できる Superset command では JSON を使う。

## Workflow

### 1. Require The Implementation Brief

現在の thread に `$kei-prepare-implementation-brief` が作成した ready な Brief がある場合は、その判断内容を変えずに使う。

Brief がない、または実装開始に必要な判断が未確定の場合は、`$kei-prepare-implementation-brief` を先に使う必要があると返し、Superset を起動せず停止する。この skill から repo 調査や Brief 作成を実行しない。

この skill では Brief schema を再掲せず、調査や実装方針の補完もしない。launch 直前に repo 状態が変わって Brief が stale になった場合は、`$kei-prepare-implementation-brief` に戻す。

### 2. Build The Agent Prompt

`../kei-handoff/SKILL.md` を完全に読み、完成済み Brief から implementation Agent Prompt を作る。

- Brief の判断、scope、検証、停止条件を変更しない。
- この skill 独自の prompt template を追加しない。
- `$kei-handoff` が作成した Agent Prompt を initial prompt としてそのまま使う。
- 複数 repository の場合は、`$kei-handoff` の分割結果に従い、repository ごとに workspace と Agent Prompt を分ける。
- Agent Prompt に未許可の external write が含まれていないことだけ launch 前に確認する。不備があれば独自修正せず、`$kei-handoff` を適用し直す。

### 3. Revalidate Launch State

Brief の repo 調査は繰り返さず、launch 固有の状態だけ確認する。

- target repository、current branch、HEAD、`git status --short`
- Brief 作成後に base または対象状態が変わっていないか
- dirty files が user-owned か、Brief がその uncommitted state に依存するか
- `superset --version`、`superset status`
- 必要な project、workspace、host の ID
- `superset agents list --local --json` または `superset agents list --host <id> --json`
- reasoning effort `medium` を保証できる Codex preset または HostAgentConfig の有無

Brief が親 repo の dirty changes に依存し、新しい Superset worktree にその変更が入らない場合は起動しない。無関係な dirty changes だけなら、上書きしないことを確認して続行する。

### 4. Select The Launch Mode

| # | Mode | Use when |
|---:|---|---|
| 1 | New workspace + Codex agent | 新しい isolated workspace が必要で、reasoning `medium` の Codex preset/config を確認できる |
| 2 | Existing workspace + Codex agent | 対象 workspace が既にあり、reasoning `medium` の Codex preset/config を確認できる |
| 3 | New/existing local workspace + interactive Codex CLI | interactive CLI を求められた、または preset/config で reasoning `medium` を確認できない |

Mode 1 を新規実装の default とし、workspace ID が指定された場合は Mode 2 を優先する。reasoning `medium` を preset/config で確認できない場合は Mode 3 を使う。

Reasoning は launch configuration で保証し、Agent Prompt へ `Reasoning:` section を追加しない。Superset command へ未対応の reasoning flag も追加しない。

Mode 3 では通常の interactive `codex` を使う。ユーザーが non-interactive または background exec を明示しない限り、`codex exec` は使わない。

### 5. Launch

medium Codex preset/config を使う場合:

```bash
superset workspaces create --local --project <project-id> --name <workspace-name> --branch <branch-name> --agent <medium-codex-preset-or-config> --prompt <agent-prompt> --json
```

```bash
superset agents create --workspace <workspace-id> --agent <medium-codex-preset-or-config> --prompt <agent-prompt> --json
```

Mode 3 では、親側で Agent Prompt を一時 file へ保存する。path は space や quote を含まない絶対 path にし、local same-host workspace から読めることを確認する。prompt 本文を `--command` へ inline しない。

interactive command value は次を使う。

```bash
'codex -c '\''model_reasoning_effort="medium"'\'' --dangerously-bypass-approvals-and-sandbox -- "$(cat <prompt-file-path>)"; rm -f <prompt-file-path>; exec $SHELL'
```

新規 local workspace:

```bash
superset workspaces create --local --project <project-id> --name <workspace-name> --branch <branch-name> --command <interactive-command> --json
```

既存 local workspace:

```bash
superset terminals create --workspace <workspace-id> --cwd <worktree-path> --command <interactive-command> --json
```

`--dangerously-bypass-approvals-and-sandbox` は isolated Superset worktree 内の Mode 3 だけで使う。これは push、PR、deploy、external service write、破壊的操作、user-owned changes の上書きを許可するものではない。

Mode 3 は prompt file を共有できる local same-host workspace に限定する。remote workspace で reasoning `medium` の preset/config を確認できない場合は起動せず blocker を返す。

### 6. Verify Real Startup

command success や workspace、agent、terminal ID の発行だけを、実行開始の証拠にしない。

JSON 結果から ID、branch、worktree path を記録した後、次のいずれかを read-only で確認する。

- 対象 workspace に紐づく Codex process または agent が live である。
- terminal history または表示上、Codex が起動して initial prompt を受け取っている。
- 子 agent による task 関連の worktree activity が観測できる。

ID しか確認できない場合は「launch request 作成済み・Codex 起動未確認」と報告し、成功扱いにしない。失敗時に workspace や session を自動削除しない。

この skill は起動確認までで停止する。実装完了の監視は、ユーザーが明示的に依頼した場合だけ続ける。

### 7. Parent Report

起動を確認できた場合だけ、次の形式で返す。

```markdown
Superset 経由で implementation agent を起動し、Codex の実行開始まで確認しました。

| # | repository | workspace / session | branch / worktree | reasoning | startup proof |
|---:|---|---|---|---|---|
| 1 | <owner/repo> | <ids> | <branch and path> | medium via <preset/config/CLI> | <observed evidence> |
```

起動できない、または起動確認できない場合は成功表現を使わない。

```markdown
Superset handoff は完了していません。

| # | state | confirmed evidence | smallest next action |
|---:|---|---|---|
| 1 | <not launched / startup unconfirmed> | <observed evidence> | <next check or decision> |
```
