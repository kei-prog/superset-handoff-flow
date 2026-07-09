---
name: kei-prepare-implementation-brief
description: 実装前に repo を read-only で調査し、source of truth、現状、実装方針、success criteria、主対象ファイル、制約、検証、停止条件を確定した decision-complete な Implementation Brief を作る。ユーザーが「実装前に調査」「事前調査」「現状把握」「原因を調べて実装方針を決めて」「Superset に渡す前に調査」と依頼した時に使う。Agent Prompt の作成、実装、thread/workspace 作成、Superset 起動は行わない。
---

# Kei Prepare Implementation Brief

repo を調査し、実装判断の正本となる Implementation Brief を作る。

## Contract

この skill の責務は read-only 調査と task 固有の実装判断まで。

- repo file、Git、外部 service を変更しない。
- file edit、commit、push、PR、deploy、Agent Prompt 作成、thread/workspace 作成、Superset 起動を行わない。
- 後続 skill がある場合も、Brief を完成させた時点で終了する。
- 共通の execution contract、`codex-review`、commit、報告形式、launch 設定は定義しない。それらは `$kei-handoff` と実行 skill の責務。

## Workflow

### 1. Fix The Scope

次を明確にする。

- target repository
- observable Goal
- Success criteria
- explicit constraints と Out of scope
- 正とする仕様、実装、test、commit、PR、画面、ユーザー判断

repo と利用可能な情報から決められない product decision が残る場合は、推測せず focused question を 1 つ返す。

### 2. Ground In The Repo

実装せず、必要な範囲だけ確認する。

- current branch、HEAD、working-tree status
- source-of-truth files、仕様、reference implementation、tests、design docs
- 関連する implementation path、state、API、store、route、IPC、schema
- 現在の挙動と原因
- 変更後に stale になり得る tests、snapshots、types、docs、generated artifacts
- focused verification command、manual check、environment blocker
- pre-existing dirty changes と実装対象を分離できるか

広く検索した後は、関係する file、function、test に絞る。

### 3. Separate Evidence

Brief 内で次を混ぜない。

- `Confirmed:` code、test、log、UI、API response などで観測した事実
- `Inference:` confirmed facts から導いた判断
- `Assumption:` 実装開始のために置く明示的な仮定
- `Unconfirmed:` 今回の開始条件ではない未確認事項

具体的な repository、file、function、type、endpoint、test、commit、PR、error string を優先する。

### 4. Decide The Implementation

実装案が複数ある場合は、必要な候補だけ比較し、採用案を 1 つ決める。

- confirmed root cause がある層だけを変更する。
- stale expectation は必要な追随対象として扱う。
- 無関係な構造変更を混ぜない。
- `Primary files` は初期主対象として特定する。
- 参照だけに使う file は `Reference context` に分ける。
- 明示的に編集禁止の file だけを `Protected files` に置く。
- 採用しない案が誤実装防止に役立つ場合だけ `Reject:` を残す。

### 5. Check Readiness

次が埋まれば Brief は ready。

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

`Task stop condition` には task 固有の完了状態または blocker 条件を書く。共通の review、commit、報告、launch 契約は書かない。

## Output

最初に ready / not ready を日本語 1 文で示す。ready なら次を返す。

```text
Implementation Brief

Repository:
- <owner/repo>

Goal:
- <observable final outcome>

Success criteria:
- <completion 時に観測できる状態>

Source of truth:
- <spec / test / reference implementation / commit / user decision>

Current state:
- Confirmed: <observed repo fact>
- Inference: <reasoned conclusion, if needed>
- Assumption: <necessary assumption, if needed>
- Unconfirmed: <non-blocking unknown, if useful>

Implementation decision:
- Adopt: <chosen approach>
- Reject: <rejected approach and reason, if useful>

Primary files:
- <initial primary edit targets>

Reference context:
- <files / repos / docs used only as context>

Protected files:
- <explicit no-edit targets, only when needed>

Constraints:
- <task-specific behavior and scope constraints>

Out of scope:
- <explicit non-goals>

Verification:
- <focused commands>
- <manual checks, if needed>
- Known blocker: <if any>

Task stop condition:
- <task-specific completion or blocker boundary>
```

`Primary files` は初期主対象であり denylist ではない。`Protected files` だけを明示的な no-edit 境界として扱う。scoped task に必要な直接追随を予測できる場合は、Brief の Constraints に含める。

Brief が作れない場合は、repo 調査で埋められない blocker だけを返す。

```markdown
| # | blocker | confirmed evidence | smallest next action |
|---:|---|---|---|
| 1 | <missing decision> | <observed evidence> | <one question or check> |
```

ユーザーが実装や Superset handoff へ進むか尋ねても、この skill では起動しない。Brief が ready かと、次に渡す skill だけを示す。
