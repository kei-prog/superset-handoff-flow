---
name: kei-superset-implementation-handoff
description: 事前調査と作業設計を行ったうえで、Superset CLI から Codex agent または Codex CLI terminal session に repo-scoped implementation を委譲する handoff skill。ユーザーが「Superset で実装を渡して」「superset implementation handoff」「superset 経由で codex に依頼」「kei-superset-implementation-handoff」と依頼した時に使う。親スレッドは source of truth、所有範囲、acceptance criteria、検証、停止条件を決め、Superset workspace/agent 作成だけを実行面として使う。
---

# Kei Superset Implementation Handoff

## Purpose

実装を、調査済み・設計済みの Superset workspace 上の Codex agent へ渡す。

品質を上げる主因は Superset を使うことではなく、親スレッドが先に正解、所有範囲、検証、停止条件を固定し、子 agent が迷わず実装できる handoff を作ること。

## Safety Contract

- Do not start a Superset workspace, agent, or terminal before grounding in the repo.
- Treat Superset workspace/agent creation as an external-state change. Use it only when the user requested Superset handoff or clearly authorized starting a separate execution lane.
- Do not push, create PRs, deploy, edit production state, or write external services unless the user explicitly requested that action.
- When designing the implementation prompt, use `$kei-handoff` discipline: read `~/.codex/skills/kei-handoff/SKILL.md` if it is not already loaded, and keep the prompt self-contained, repo-scoped, concise, evidence-based, and explicit about constraints, verification, stop condition, and reporting.
- The prompt sent to the Superset implementation agent must be written primarily in Japanese. Keep file paths, command names, code identifiers, branch names, and exact error strings in their original language.
- Do not tell the child agent to "use `$kei-handoff` style" or "create a handoff prompt" inside the prompt sent to the agent. That can make the child agent generate another handoff instead of implementing. Use `$kei-handoff` only as parent-side drafting discipline.
- The first line of every implementation-agent prompt must explicitly say that the child agent is the implementation agent and must implement the change now, not write another handoff prompt.
- If the worktree is dirty, identify whether changes are user-owned. Do not assign the Superset agent to overwrite unknown dirty changes.
- The implementation agent must run `$codex-review` as its final closeout review before reporting completion, unless blocked before code changes.
- The implementation agent must finish with its changes committed locally and `git status --short` clean, unless the user explicitly said not to commit or the agent is blocked before commit.
- Prefer JSON output for Superset commands when the result must be parsed or reported.

## Workflow

### 1. Ground Truth First

Before starting Superset, inspect enough local context to freeze the work shape:

- current branch and dirty files
- source-of-truth files, existing design docs, related tests, and nearby implementation patterns
- prior commit / PR / design artifact if the task is a restoration or migration
- likely shared interfaces, state, schemas, routes, IPC, test utilities, and build scripts
- minimum verification commands and known environment blockers
- Superset availability: `superset --version`, `superset status`, and project/workspace IDs if needed

If the desired outcome is ambiguous after inspection, ask one focused question. Otherwise make a conservative assumption and record it in the handoff brief.

### 2. Decide The Superset Launch Mode

Choose one launch mode:

| # | Mode | Command shape | Use when |
|---:|---|---|---|
| 1 | New workspace + Codex agent | `superset workspaces create --local --project <id> --name <workspace-name> --branch <branch> --agent codex --prompt <prompt> --json` | A new isolated repo workspace should be created for the implementation |
| 2 | Existing workspace + Codex agent | `superset agents create --workspace <id> --agent codex --prompt <prompt> --json` | A Superset workspace already exists and should receive the handoff |
| 3 | Existing workspace + Codex CLI terminal | `superset terminals create --workspace <id> --command <codex command> --cwd <path> --json` | The user specifically wants Codex CLI invoked through a terminal session |

Default to Mode 1 when the task is repo implementation and project/workspace creation is appropriate. Default to Mode 2 when the user provides a workspace ID. Use Mode 3 only when the user specifically asks for CLI execution or when no Codex agent preset is available.

If project or workspace IDs are unknown, use read-only Superset list commands first:

```bash
superset projects list --json
superset workspaces list --json
superset hosts list --json
superset agents list --json
```

### 3. Write The Implementation Brief

Create a shared brief before launching Superset. It must be decision-complete:

```text
Goal:
<observable final outcome>

Source of truth:
- <commit/spec/test/design/file that defines the correct behavior>

Current state:
- <verified repo facts>

Owned files:
- <files or folders the implementation agent may edit>

Read-only context:
- <files or folders it should inspect but not edit>

Global constraints:
- <must not change>
- <must preserve>

Out of scope:
- <explicit non-goals>

Verification:
- <commands or manual checks the implementation agent should run>

Superset launch:
- <mode, project/workspace/branch/host assumptions>

Stop condition:
- <exact completion or blocker report condition>
```

Default ownership policy:

- Owned files are the initial primary edit target, not an absolute denylist.
- It may read any file needed to understand the task.
- If it needs to edit an unowned file, first classify whether the change is direct follow-up from the scoped implementation or a real scope expansion.
- When a `codex-review` finding or test failure is clearly caused by the scoped implementation, and the fix is a narrow related update to test, snapshot, type expectation, docs, display metadata, or persisted settings migration, the implementation agent may make that minimal ownership expansion, fix it, rerun focused verification, and report the expanded file explicitly. Do not treat this as a blocker.
- Still stop for unowned production-code behavior changes, broad refactors, contract/API changes, generated artifacts with unclear ownership, external-state changes, or any change whose product intent is not obvious.
- Current behavior tests and explicit user constraints beat visual similarity or inferred intent.
- If the source of truth conflicts with current tests or user constraints, the agent must stop and report the conflict.

### 4. Build The Codex Agent Prompt

Use this prompt shape for `--prompt`:

```text
あなたは implementation agent です。別の handoff prompt は作らず、この workspace で今すぐ実装してください。

Repository:
<owner/repo or absolute repo path if needed by Superset>

実装ブリーフ:
<paste the implementation brief>

役割:
<what kind of expert this implementation needs>

編集してよいファイル:
- <paths>

読むだけの参考ファイル:
- <paths>

禁止事項:
- 編集してよいファイルは初期主対象とする。targeted verification / `$codex-review` が同一実装に伴う直接の追随不足を示した場合は、test / snapshot / type expectation / docs / display metadata / persisted settings migration の最小修正に限り、編集許可外でも修正してよい。
- push、PR 作成、deploy、外部サービス変更はしない。
- scope を広げない。無関係な refactor はしない。
- user-owned または pre-existing dirty changes を上書きしない。

依存・前提:
<none / use current repo state / wait for explicit user decision>

実装タスク:
<precise implementation task>

完了条件:
- <criteria>
- blocked または明示的に commit 禁止でない限り、この実装の変更だけを含む local commit がある。
- 報告前に `git status --short` が clean。

検証:
- <commands>

最終 review:
- 実装と targeted verification の後、この実装差分に対して `$codex-review` skill を final closeout review として使う。
- `$codex-review` が accepted/actionable finding を返したら、code 上で確認し、主対象ファイル内の finding または同一実装に伴う狭い追随更新だけ直し、必要な検証を再実行し、accepted/actionable finding がなくなるまで `$codex-review` を再実行する。
- finding の修正に編集許可外のファイル変更が必要な場合でも、同一実装に伴う stale test / snapshot / type expectation / docs / display metadata / persisted settings migration の狭い追随更新なら、最小 ownership expansion として修正し、報告に expanded file と理由を含める。
- 編集許可外の production code behavior、広い refactor、contract/API 変更、external state 変更、または意図判断が必要な変更が必要なら、そのファイルは編集せず blocked ownership change として報告する。

Commit:
検証と `$codex-review` が clean になったら、この実装の意図した変更だけを含む local commit を作る。
無関係な user-owned / pre-existing dirty changes は commit しない。
commit 後に `git status --short` が clean であることを確認する。clean でなければ、意図した生成・format 変更は同じ commit に含めるか、blocker として明確に報告する。

停止条件:
この scoped task だけを実装し、targeted verification を実行し、`$codex-review` closeout を通し、review が clean になった後に local commit を作り、`git status --short` が clean であることを確認して停止する。報告には changed files、commit SHA/message、verification results、final review result、clean worktree proof、blocked ownership changes を含める。ユーザーが明示的に commit 禁止と言った場合は commit せず、検証済み uncommitted diff と commit を skipped した理由を報告する。
```

### 5. Launch With Superset

Use the selected command shape. Keep the command non-interactive and parseable.

For a new workspace:

```bash
superset workspaces create --local --project <project-id> --name <workspace-name> --branch <branch-name> --agent codex --prompt <prompt> --json
```

For an existing workspace:

```bash
superset agents create --workspace <workspace-id> --agent codex --prompt <prompt> --json
```

For a terminal-driven Codex CLI handoff:

```bash
superset terminals create --workspace <workspace-id> --cwd <repo-path> --command <codex-cli-command> --json
```

If Superset reports missing auth, missing project setup, unavailable host service, or unavailable Codex agent preset, do not improvise broad setup changes. Report the exact blocker and the smallest next command or decision needed.

### 6. Parent Output

After launching, return a compact Japanese table:

```markdown
Superset 経由で Codex implementation agent に委譲しました。親の設計では <source of truth> を正にし、子 agent が <owned files> を主対象に、必要な直接追随だけ最小拡張して実装・検証・review・commit まで完了します。

| # | Superset result | 目的 | 所有範囲 | 停止条件 |
|---:|---|---|---|---|
| 1 | <workspace/agent/session id> | <目的> | `...` | <停止条件> |
```

Include the Superset workspace/agent/session IDs, branch, and worktree path when known.

If launch failed, report:

```markdown
Superset handoff は未開始です。

| # | blocker | confirmed evidence | next action |
|---:|---|---|---|
| 1 | <blocker> | <observed output> | <smallest safe next step> |
```
