---
name: kei-handoff
description: 現在の thread で明確になった問題、期待結果、判断、制約などの Ready Context を、内容を変えず、別の Codex agent がこの thread に依存せず実行できる自己完結した repo-scoped Agent Prompt へ変換する。ユーザーが handoff prompt、別 agent への指示、delegate prompt、implementation prompt を求めた時、または実行 skill が現在の context を prompt 化する時に使う。repo 調査、実装、thread/workspace 作成、agent 起動は行わない。
---

# Kei Handoff

現在の thread で確定した Ready Context を、自己完結した Agent Prompt に変換する。

## Contract

- repo を調査しない。
- supplied facts、decisions、constraints を変更、補完、再判断しない。
- 実装、file edit、commit、thread/workspace 作成、Superset 起動を行わない。
- repository ごとに prompt を 1 つ作る。
- launch mode、reasoning effort、workspace ID、terminal command は prompt に入れない。実行 skill が管理する。
- Ready Context が不足している場合は、実装判断を発明せず Not ready と返す。

## Ready Context

implementation prompt を作る前に、現在の thread から次を確認する。

- target repository
- Problem または desired outcome
- Success criteria
- source of truth または明示的なユーザー判断（挙動が曖昧な場合）
- Constraints と Out of scope。特にない場合はその事実
- unresolved Blocking unknown が 0 件
- Accepted risks と Delegatable unknowns（存在する場合）

次は Ready Context の必須条件にしない。implementation agent が repo を調査して決める。

- root cause
- implementation decision
- primary files
- detailed implementation steps
- targeted test command

不明点の答えによってユーザーに見える挙動、API/DB contract、scope、Success criteria が変わる場合は Blocking unknown。これが残る場合は Agent Prompt を作らず、次の形式で確認を 1 つだけ返す。

```markdown
Not ready for handoff.

| # | missing decision | why it blocks implementation | focused question |
|---:|---|---|---|
| 1 | <unknown> | <impact> | <one question> |
```

## Transformation Rules

- Ready Context の問題、期待結果、判断、制約、事実 label を維持する。
- 同じ内容を複数 section に展開しない。
- exact identifier、path、command、error string は保持する。
- prompt は原則として日本語で書く。
- local path や `cd` は、supplied context または実行基盤が必要とする場合だけ含める。
- implementation prompt と read-only prompt で execution contract を分ける。
- user の明示条件を以下の default より優先する。

## Implementation Agent Prompt

Ready Context を一度だけ貼り、その後に共通 execution contract を一度だけ付ける。

```text
あなたは implementation agent です。別の handoff prompt は作らず、この repository で今すぐ実装してください。

Ready Context:
<現在の thread で確定した context を、内容を変えずに貼る>

Execution contract:
- Ready Context をこの task の source of truth として扱い、Problem、desired outcome、Success criteria、Constraints、Out of scope を守る。
- 編集前に repo を調査し、current behavior、root cause、関連経路、既存 pattern、必要な verification を確認する。
- 作業開始時に branch、HEAD、`git status --short` を記録する。
- scoped task に必要な最小の一貫した変更を行う。直接追随が必要な repo file は最小限変更し、unexpected/expanded files と理由を報告する。
- 明示的な protected files、user-owned changes、pre-existing dirty changes を変更、削除、commit しない。
- Ready Context またはユーザーが明示的に許可していない push、PR 作成、deploy、production 変更、external service write を行わない。
- current code、tests、docs と Ready Context が衝突し、どれを正とするか決められない場合は停止して証拠を報告する。Ready Context から stale と判断できる期待値は最小修正して続行する。
- blocker は、明示制約との衝突、secret、未許可の外部変更、破壊的操作、資格情報不足、検証不能、または current code と Ready Context から決められない product decision に限る。

Verification and closeout:
- Success criteria を証明する focused verification を特定して実行する。
- 実装と verification 後、この実装差分に対して `$codex-review` を final closeout review として使う。
- accepted/actionable finding が scoped implementation の直接追随なら、最小修正し、必要な verification と review を finding がなくなるまで繰り返す。
- Ready Context またはユーザーが commit 禁止を明示しない限り、verification と review 後にこの task の意図した変更だけを含む local commit を作る。
- 開始時が clean なら終了時も clean にする。開始時に dirty changes があった場合は baseline を維持し、この task 由来の未commit差分を残さない。

Report:
- branch、base、changed files
- unexpected/expanded files と理由
- commit SHA/message、または commit を skip した理由
- verification results
- final review result
- final `git status --short` と開始時 baseline との差
- resolved Delegatable unknowns、Accepted risks、blocked items
- 最終報告の末尾に `実装対象:` を置き、Ready Context の Problem または desired outcome を再掲する。

Stop condition:
Success criteria を満たし、focused verification、final review、必要な local commit、worktree 確認を完了したら停止する。blocker がある場合は変更を広げず、証拠と必要な判断を報告して停止する。
```

## Read-only Agent Prompt

調査、診断、review 用 prompt では implementation contract を付けない。

```text
あなたは read-only agent です。次の依頼をこの thread に依存せず実行してください。

Repository:
<owner/repo>

Task context:
<supplied context>

Constraints:
- file edit、commit、push、PR review 投稿、external service write を行わない。
- Confirmed、Inference、Assumption、Unconfirmed を混ぜない。
- 対象 diff または対象状態を明記し、観測できる証拠を優先する。

Report:
- conclusion
- evidence
- uncertainty または blocker
- smallest next action
```

## Output

1 repo なら prompt を 1 つだけ返す。複数 repo なら repository ごとに分ける。

prompt 以外の説明は、どの Ready Context を何用の prompt へ変換したかを示す日本語 1 文だけにする。
