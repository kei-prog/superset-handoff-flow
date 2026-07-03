---
name: kei-handoff
description: "別の Codex agent に渡す、repo scope の concise handoff prompt を作る。handoff、delegate、別 Codex への instruction、implementation prompt 作成をユーザーが求めたときに使う。"
---

# Kei Handoff

この thread に依存せず、別の Codex agent が実行できる prompt を作る。

## 基本ルール

target repository ごとに、自己完結した prompt を 1 つ出力する。

ユーザーが明示しない限り、local working directory、absolute folder path、`cd` instruction は含めない。target は `<org>/<repo>` のように repository で識別する。

handoff prompt は Codex agent が読みやすいように、短く直接書く。長い背景説明より、先に outcome、守る制約、完了条件、検証を置き、同じ事実を複数 section で繰り返さない。

handoff prompt は原則として日本語で作成する。英語の identifier、command、error string、section label、既存の定型文は、正確性や受け取り側 agent の実行しやすさに必要な場合だけそのまま使う。

受け取り側 agent が repo を読めば分かる実装手順や周辺情報は過剰に書かない。必要なのは、誤実装を防ぐ fact、scope、制約、確認すべき identifier、targeted verification だけ。

## 複数 repository が関わる場合

handoff は repository ごとに分ける。

各 prompt には、その repository の作業だけを含める。cross-repo context は、誤実装を避けるために必要な場合だけ各 prompt に入れる。

## Prompt 形式

default では次の構造を使う。

```text
Repository:
<owner>/<repo>

Goal:
<望む outcome を 1-2 行で説明>

Success criteria:
- <完了時に真であるべき状態>

Strict constraints:
- <絶対に守る制約>
- <ついで変更を防ぐ禁止事項>

Out of scope:
- <今回やらないこと>

Context:
- <verified fact>
- <verified fact>

Root cause / current behavior:
- <今起きていること>

Expected behavior:
- <変更後に真であるべきこと>

Implementation guidance:
- <分かっている場合は確認すべき file、function、pattern>

Tests / verification:
- <実行すべき targeted checks>

Stop condition:
- <どこまで完了したら止めるか>

報告:
- <実装 agent が含めるべき evidence>
```

狭い実装では原則この順序を使い、不要な section は省略してよい。`Context` は 3-7 bullets 程度に圧縮する。長い経緯、会話の流れ、判断に使わない周辺情報は入れない。

`Root cause / current behavior` と `Expected behavior` は、原因説明や挙動差分が必要な場合だけ使う。単純な整理、レビュー、機械的移動では省略してよい。

受け取り側 agent の判断基準が特別に重要な場合だけ、`Role:` を 1 文で追加してよい。通常は `Goal`、`Success criteria`、`Strict constraints` で足りる。

調査・レビューなど read-only handoff では、`Success criteria` と `Strict constraints` に「no edits / no commits / no external writes」を先に置く。

実装を完了させる handoff では、ユーザーが明示的に否定しない限り `Stop condition` は「targeted verification 後に local commit を作成して止める」にする。実装案、調査、レビュー、方針整理の handoff では commit 作成を default にしない。push、PR 作成、deploy、production 変更、external service write は stop の外側であり、別途明示されない限り依頼しない。

local commit を作る handoff では、`報告` に commit hash、branch、base、変更 file、実行した verification を含めるよう指示する。review を依頼する場合は、対象が uncommitted changes、commit、branch diff、PR diff のどれかを明記させる。local commit 後の clean working tree だけを、差分 review 済みとして報告させない。

## Evidence Discipline

verified fact と inference を分ける。

利用できる場合は、具体的な identifier を使う。

- repository name
- PR number
- commit hash
- issue ID
- endpoint
- error string
- repo 内 file path
- function または type name

不確かな fact を言い過ぎない。`Assumption:` または `Not verified:` と label する。

## 範囲管理

最小の有用な fix を書く。

ユーザーが `調査だけ`、`診断のみ`、`commit しない`、`read-only` のように明示した場合は、commit 作成を依頼しない。

`Owned files` や `Implementation guidance` に列挙した file は初期想定の主対象であり、絶対的な編集禁止リストではない。targeted verification や `codex-review` が、同じ仕様変更に対する直接の追随不足を示した場合は、関連する test、snapshot、type expectation、docs、表示 metadata、保存設定 migration などを最小限で owned files 外でも修正してよい。

ブロックするのは、別機能の product 判断、広い refactor、API / DB / external state 変更、secret や production への影響、または仕様判断が必要な場合だけにする。明らかな stale expectation follow-up は ownership violation と扱わず、修正して再検証する前提で handoff に含める。

## Narrow Implementation Handoff

小さな構造整理、段階的 PR、挙動変更なしの refactor、既存導線の最小修正を handoff するときは、背景説明より先に `Goal`、`Success criteria`、`Strict constraints`、`Out of scope` を明示する。

特に「分割ついでの改善」を避けるため、必要に応じて次を入れる。

- Do not change function behavior.
- Do not change function bodies except for movement/import adjustment.
- Do not change exported API names.
- Do not change fallback behavior.
- Do not replace call sites outside the stated scope.
- Do not create new packages or abstractions.
- Do not rename any functions, including unexported helpers.

## スタイル

user-facing answer は短く保つ。

1 repo の狭い実装なら、prompt は原則として 1 画面で読める長さを目指す。

prompt を返すときは、次を優先する。

```text
結論: repo ごとに分けた handoff prompt です。

```text
...
```
```

repository が 1 つだけの場合は、prompt も 1 つだけ返す。
