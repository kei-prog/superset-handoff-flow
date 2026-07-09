---
name: kei-handoff
description: 受け取った Implementation Brief またはユーザー提供 context を、判断内容を変えず、別の Codex agent がこの thread に依存せず実行できる自己完結した repo-scoped Agent Prompt へ変換する。ユーザーが handoff prompt、別 agent への指示、delegate prompt、implementation prompt を求めた時、または実行 skill が完成済み Brief を prompt 化する時に使う。repo 調査、実装、thread/workspace 作成、agent 起動は行わない。
---

# Kei Handoff

supplied Brief または明示された context を、自己完結した Agent Prompt に変換する。

## Contract

- repo を調査しない。
- supplied facts、decisions、constraints を変更、補完、再判断しない。
- 実装、file edit、commit、thread/workspace 作成、Superset 起動を行わない。
- repository ごとに prompt を 1 つ作る。
- repo を読まなければ埋められない判断が不足している場合は推測せず、`$kei-prepare-implementation-brief` が必要だと返す。
- launch mode、reasoning effort、workspace ID、terminal command は prompt に入れない。実行 skill が管理する。

## Input Readiness

implementation prompt には最低限、次の supplied information が必要。

- Repository
- Goal
- Success criteria
- Source of truth
- Current state
- Implementation decision
- Primary files
- Constraints
- Out of scope
- Verification
- Task stop condition

簡単な依頼では、同等の情報がユーザー context に明示されていれば Brief 形式でなくてもよい。

不足が表現上の問題なら整形する。実装判断が不足している場合は調査や発明をせず、不足項目を返す。

## Transformation Rules

- Goal、判断、制約、事実 label を維持する。
- 同じ内容を複数 section に展開しない。
- repo を読めば分かる一般的な実装手順を増やさない。
- exact identifier、path、command、error string は保持する。
- prompt は原則として日本語で書く。
- local path や `cd` は、supplied context または実行基盤が必要とする場合だけ含める。
- implementation prompt と read-only prompt で execution contract を分ける。
- user または Brief の明示条件を、以下の default より優先する。

## Implementation Agent Prompt

Implementation Brief 全体を一度だけ貼り、その後に共通 execution contract を一度だけ付ける。

```text
あなたは implementation agent です。別の handoff prompt は作らず、この repository で今すぐ実装してください。

Implementation Brief:
<supplied Implementation Brief を判断内容を変えずに貼る>

Execution contract:
- Implementation Brief をこの task の source of truth として扱い、Goal、Success criteria、Constraints、Out of scope を守る。
- 作業開始時に branch、HEAD、`git status --short` を記録する。
- `Primary files` は初期主対象であり denylist ではない。理解のために必要な repo file は読んでよい。
- scoped task の完了に予想外の repo file 変更が必要なら、最小の一貫した変更を行い、検証、review、commit まで続行する。最後に unexpected/expanded files と理由を報告する。
- `Protected files` と user-owned または pre-existing dirty changes を変更、削除、commit しない。
- Brief またはユーザーが明示的に許可していない push、PR 作成、deploy、production 変更、external service write を行わない。
- source of truth と current tests または明示的なユーザー制約が衝突する場合は停止して証拠を報告する。Brief から stale と判断できる期待値の直接追随は最小修正して続行する。
- blocker は、明示制約との衝突、secret、未許可の外部変更、破壊的操作、資格情報不足、検証不能、または Brief と current code から決められない product decision に限る。

Verification and closeout:
- Brief に指定された focused verification を実行する。
- 実装と verification 後、この実装差分に対して `$codex-review` を final closeout review として使う。
- accepted/actionable finding が scoped implementation の直接追随なら、最小修正し、必要な verification と review を finding がなくなるまで繰り返す。
- Brief またはユーザーが commit 禁止を明示しない限り、verification と review 後にこの task の意図した変更だけを含む local commit を作る。
- 開始時が clean なら終了時も clean にする。開始時に dirty changes があった場合は baseline を維持し、この task 由来の未commit差分を残さない。pre-existing dirty state だけを理由に block しない。

Report:
- branch、base、changed files
- unexpected/expanded files と理由
- commit SHA/message、または commit を skip した理由
- verification results
- final review result
- final `git status --short` と開始時 baseline との差
- blocked items
- 最終報告の末尾に `実装ブリーフのGoal:` を置き、Brief の Goal をそのまま再掲する。

Stop condition:
Implementation Brief の Task stop condition を満たし、focused verification、final review、必要な local commit、worktree 確認を完了したら停止する。blocker がある場合は変更を広げず、証拠と必要な判断を報告して停止する。
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

prompt 以外の説明は、どの Brief または context を何用の prompt へ変換したかを示す日本語 1 文だけにする。
