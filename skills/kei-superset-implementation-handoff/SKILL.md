---
name: kei-superset-implementation-handoff
description: 現在の thread で明確になった問題・期待結果・判断・制約を kei-handoff で implementation Agent Prompt に変換し、使用する Codex model と reasoning とともに全文 preview を提示して、ユーザーの明示承認後だけ Superset workspace、agent、または Codex CLI terminal を起動する。ユーザーが「Superset で実装を渡して」「Superset 経由で Codex に依頼」「kei-superset-implementation-handoff」と依頼した時に使う。context に Blocking unknown が残る場合は起動せず、必要な確認を 1 つ返す。
---

# Kei Superset Implementation Handoff

現在の thread の Ready Context を Agent Prompt に変換し、model、reasoning、全文 prompt をユーザーに確認してから Superset で起動し、Codex が実際に開始した証拠まで確認する。

標準のユーザー操作は、問題と要件を会話で明確化した後に `$kei-superset-implementation-handoff` を呼び、表示された preview に明示的に OK すること。内部フローは Ready Context → `$kei-handoff` → Agent Prompt → model/reasoning 選択 → preview → user approval → Superset launch。

この skill が所有するのは、`$kei-handoff` による Ready 判定と prompt 化、model/reasoning と launch mode の選択、全文 preview、明示的な起動承認、launch 直前の再確認、安全な command 実行、起動証拠、親 thread への報告だけ。

## Safety

- 最初の Superset handoff 依頼は preview 作成の許可として扱う。workspace、agent、terminal の作成は外部状態変更であり、preview 表示後の明示的なユーザー承認がある場合だけ実行する。
- preview 前の依頼、過去の承認、曖昧な肯定を launch 承認として扱わない。
- 承認は preview に表示した repository、branch、HEAD、Agent Prompt、model、reasoning、launch mode、external write scope の組にだけ適用する。いずれかが変わった場合は再 preview と再承認を必須にする。
- Superset 起動の許可を、push、PR 作成、deploy、production 変更、external service write の許可へ広げない。それらはユーザーが個別に明示した場合だけ Agent Prompt に含める。
- Ready Context または Agent Prompt に unresolved Blocking unknown、明示制約との衝突、secret、破壊的操作、資格情報不足がある場合は起動しない。
- 親 repo の uncommitted changes に依存する context を、それらが存在しない isolated worktree へ渡さない。
- Superset の auth、host、project、workspace、agent 設定が不足している場合は、広い setup 変更を行わず、正確な blocker と最小の next action を返す。
- JSON が利用できる Superset command では JSON を使う。

## Workflow

### 1. Build And Validate The Agent Prompt

`../kei-handoff/SKILL.md` を完全に読み、現在の thread で確定した context から implementation Agent Prompt を作る。

- `$kei-handoff` の Ready Context 判定を正とし、この skill で別の checklist や prompt template を定義しない。
- `$kei-handoff` が Not ready を返した場合は、focused question をユーザーへ返し、Superset を起動せず停止する。
- `$kei-handoff` が作成した Agent Prompt を initial prompt としてそのまま使う。
- 複数 repository の場合は、`$kei-handoff` の分割結果に従い、repository ごとに workspace と Agent Prompt を分ける。
- Agent Prompt に未許可の external write が含まれていないことだけ launch 前に確認する。不備があれば独自修正せず、`$kei-handoff` を適用し直す。

### 2. Inspect Launch State Read-only

実装調査は子 agent に任せ、preview と launch に必要な状態だけ確認する。

- target repository、current branch、HEAD、`git status --short`
- 要件確定後に target state が変わり、Ready Context が stale になっていないか
- dirty files が user-owned か、context がその uncommitted state に依存するか
- `superset --version`、`superset status`
- 必要な project、workspace、host の ID
- `superset agents list --local --json` または `superset agents list --host <id> --json`
- `command -v codex`、`codex --version`、`codex --help`
- launch に使う同じ executable の `codex debug models` が返す current model catalog

context が親 repo の dirty changes に依存し、新しい Superset worktree にその変更が入らない場合は preview を出さず blocker を返す。無関係な dirty changes だけなら、上書きしないことを明示して続行する。

### 3. Select Model And Reasoning

まず task class から次の default pair を選ぶ。ユーザーが model または reasoning を指定した場合は、対応する field だけを default pair から上書きする。

| # | Task class | Model | Reasoning | Selection intent |
|---:|---|---|---|---|
| 1 | Standard implementation | `gpt-5.6-terra` | `xhigh` | 日常的な repo-scoped 実装を高い推論深度で進める |
| 2 | High-difficulty implementation | `gpt-5.6-sol` | `ultra` | 最難関の実装を自動 task delegation 込みで進める |

`ultra` が正確な reasoning value。`ultracode` という別 value に置き換えない。

automatic task delegation が実質的に役立ち、かつ次のいずれかを含む場合は High-difficulty とする。

- 複数 repository または複数 layer の整合変更
- schema migration、data repair、backfill、互換性維持
- auth、security、billing、permission、production safety
- concurrency、distributed state、cache、offline synchronization
- 広い既存経路にまたがる root cause 調査または大規模 refactor
- 独立した調査・実装・検証 lane への分解が品質を materially 上げる task

単に作業量が多いだけでは High-difficulty にしない。task class、default または user override の別、選択理由を preview に含める。

launch に使う exact Codex executable で `codex debug models` を実行し、その stdout を 1 回の coherent catalog snapshot として扱う。選択した model と reasoning が `.models[]` に含まれるか確認する。desktop app や別 version の Codex が書いた shared cache を CLI launch の根拠にしない。

installed CLI に `codex debug models` がない場合だけ `${CODEX_HOME:-$HOME/.codex}/models_cache.json` を fallback とし、path、`fetched_at`、`client_version` を記録する。

選択した組が snapshot にない場合は、Codex executable path、version、catalog command と不在を確認した field を示す。黙って downgrade せず、CLI update または利用可能な代替案についてユーザー判断を求める。

model と reasoning は launch configuration で保証し、Agent Prompt 本文へ追加しない。

### 4. Select The Launch Mode

| # | Mode | Use when |
|---:|---|---|
| 1 | New workspace + Codex agent | 新しい isolated workspace が必要で、選択した model/reasoning を preset/config で保証できる |
| 2 | Existing workspace + Codex agent | 対象 workspace が既にあり、選択した model/reasoning を preset/config で保証できる |
| 3 | New/existing local workspace + interactive Codex CLI | interactive CLI を求められた、または preset/config で選択した組を保証できない |

新規実装では Mode 1 を優先し、workspace ID が指定された場合は Mode 2 を優先する。ただし選択した model/reasoning を preset/config で証明できない場合は Mode 3 を使う。

Mode 3 では通常の interactive `codex` を使う。ユーザーが non-interactive または background exec を明示しない限り、`codex exec` は使わない。

### 5. Present The Preview And Wait

Superset resource を作る前に、次の形式で model、reasoning、選択理由、launch mode、Agent Prompt 全文を表示する。

````markdown
Superset handoff preview です。まだ workspace、agent、terminal は作成していません。

| # | repository | branch / HEAD | model | reasoning | selection reason | launch mode |
|---:|---|---|---|---|---|---|
| 1 | <owner/repo> | <branch / sha> | <model> | <reasoning> | <one sentence> | <mode> |

External write scope: <allowed writes or none>

Model catalog evidence: <Codex executable, version, catalog command; fallback 時だけ cache metadata>

Agent Prompt:

```text
<$kei-handoff が作成した全文を一度だけ表示>
```

この内容で Superset へ委譲してよければ `OK` と明示してください。変更したい場合は、prompt、model、reasoning、または scope の修正内容を指定してください。
````

preview を表示した turn では起動せず、ユーザー応答を待つ。最初の skill 呼び出し自体を承認として扱わない。

複数 repository の場合は row と Agent Prompt を repository ごとに分ける。ユーザーが「全部 OK」と明示した場合だけ全件を承認し、それ以外は指定された repository だけを承認する。

修正依頼を受けた場合は preview を更新し、再度明示承認を待つ。

### 6. Revalidate The Approved Preview

ユーザーの明示承認後、承認済み Agent Prompt を再生成せず、表示した全文をそのまま launch input として保持する。そのうえで launch 前に次を再確認する。

- repository、branch、HEAD、Agent Prompt、model、reasoning、launch mode、external write scope が承認済み preview と一致する
- `git status --short`、Superset auth、project/workspace/host が現在も有効
- launch に使う exact Codex executable で `codex debug models` を再実行し、承認済み model/reasoning が現在も利用可能
- uncommitted state への依存関係が変わっていない

model catalog が更新されても承認済みの組が引き続き利用可能なら承認を維持する。選択した組、prompt、scope、または他の承認対象が変わった場合は起動せず、更新した全文 preview を表示して再承認を求める。承認を push、PR、deploy、production 変更など未表示の action へ広げない。

### 7. Launch

選択した model/reasoning を保証する Codex preset/config を使う場合:

```bash
superset workspaces create --local --project <project-id> --name <workspace-name> --branch <branch-name> --agent <verified-model-reasoning-preset-or-config> --prompt <agent-prompt> --json
```

```bash
superset agents create --workspace <workspace-id> --agent <verified-model-reasoning-preset-or-config> --prompt <agent-prompt> --json
```

Mode 3 では、親側で Agent Prompt を一時 file へ保存する。path は space や quote を含まない絶対 path にし、local same-host workspace から読めることを確認する。prompt 本文を `--command` へ inline しない。

model slug と reasoning value は current catalog で検証した値だけを command に入れる。interactive command value は次を使う。

```bash
'codex --model <model> -c '\''model_reasoning_effort="<reasoning>"'\'' --dangerously-bypass-approvals-and-sandbox -- "$(cat <prompt-file-path>)"; rm -f <prompt-file-path>; exec $SHELL'
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

Mode 3 は prompt file を共有できる local same-host workspace に限定する。remote workspace で選択した model/reasoning の preset/config を確認できない場合は起動せず blocker を返す。

### 8. Verify Real Startup

command success や workspace、agent、terminal ID の発行だけを、実行開始の証拠にしない。

JSON 結果から ID、branch、worktree path を記録した後、次を read-only で確認する。

- 対象 workspace に紐づく Codex process または agent が live である
- terminal history、process args、または preset/config 上、承認済み model と reasoning で起動している
- terminal history または表示上、Codex が承認済み Agent Prompt を受け取っている
- 子 agent による task 関連の worktree activity が観測できる

ID しか確認できない場合は「launch request 作成済み・Codex 起動未確認」と報告し、成功扱いにしない。失敗時に workspace や session を自動削除しない。

この skill は起動確認までで停止する。実装完了の監視は、ユーザーが明示的に依頼した場合だけ続ける。

### 9. Parent Report

起動を確認できた場合だけ、次の形式で返す。

```markdown
承認済み preview の内容で Superset implementation agent を起動し、Codex の実行開始まで確認しました。

| # | repository | workspace / session | branch / worktree | model | reasoning | startup proof |
|---:|---|---|---|---|---|---|
| 1 | <owner/repo> | <ids> | <branch and path> | <verified model> | <verified reasoning> | <observed evidence> |
```

起動できない、承認待ち、承認内容が stale、または起動確認できない場合は成功表現を使わない。

```markdown
Superset handoff は完了していません。

| # | state | confirmed evidence | smallest next action |
|---:|---|---|---|
| 1 | <awaiting approval / approval stale / not launched / startup unconfirmed> | <observed evidence> | <next approval, check, or decision> |
```
