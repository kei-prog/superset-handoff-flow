---
name: kei-superset-worktree-merge
description: "Superset が作った同じ repo の worktree を番号付きで提示し、ユーザーが番号や「全部」で選択した後、選択された Superset worktree の完了 commit を表示順または選択順に local main へ merge する workflow。ユーザーが「superset worktreeを提示して選ばせてからmerge」「superset shの候補を番号で出して選択分を順番に合流」「supersetのやつを全部順番にmerge」などを依頼したときに使う。push、PR、deploy はしない。"
---

# Kei Superset Worktree Merge

## Overview

Superset が作った同じ Git repo の候補 worktree を先に番号付きで提示し、ユーザーの選択を受けてから local `main` へ順番に merge する。
個別 merge の安全確認と検証は `$kei-worktree-local-main-merge` の規約を継承する。

## Workflow

### 1. 候補 worktree を提示する

- `git worktree list --porcelain` で同じ repo の worktree を取得する。
- 親 repo の local `main` を target として特定する。通常は現在 repo の `main` checkout だが、推測だけで進めず worktree list で確認する。
- target `main` 自体は候補から除外する。
- 候補は原則として Superset 管理 path（例: `~/.superset/worktrees/...`）または Superset 由来だと分かる path / branch に絞る。
- ユーザーが明示的に別範囲を足した場合だけ、追加範囲も候補に含める。
- 各候補で `git status -sb` と `git log --oneline --decorate -1` を確認し、番号付き table で提示する。
- table には最低限 `番号`、`worktree名`、`branch/detached`、`clean/dirty`、`HEAD`、`path` を含める。
- dirty、missing、merge中、または HEAD が読めない候補は `対象外` として理由を示し、選択番号には入れても merge 前に止める。
- 候補提示後は merge せず、ユーザーに番号で選んでもらう。ユーザーが最初から「全部」と明示している場合だけ、提示後に選択確認を省いて全 clean 候補を順番に merge してよい。

### 2. 選択を解釈する

- ユーザーが番号を返したら、直前に提示した番号表に対応させる。
- `全部` / `all` は、直前に提示した clean 候補を表示順に全選択する。
- `1,3`、`1 3`、`1-3` のような指定を受け付ける。
- 番号が曖昧、範囲外、または直前の候補表が会話上不明な場合は、merge せず候補提示からやり直す。
- merge 直前に `git worktree list --porcelain` と各 source の `git status -sb` / `git log --oneline --decorate -1` を再実行し、候補が消えた・dirty になった・HEAD が変わった場合は該当候補を止めて報告する。

### 3. target main を安全確認する

- target repo で `git status -sb` と `git branch --show-current` を確認する。
- target が `main` でない場合、target worktree が clean であることを確認してから `git switch main` する。
- target `main` が dirty の場合は merge しない。変更ファイルを報告し、ユーザー判断を待つ。
- `main...origin/main [ahead N]` は通常 blocker にしない。ただし final で ahead 状態を短く報告する。

### 4. 選択順に merge する

- 選択された各 source について `$kei-worktree-local-main-merge` の source 確認、ancestor 確認、`git show --stat`、`--no-ff` merge、merge 後 status/log 記録の手順を順番に適用する。
- merge message は source commit の目的を短く使い、`merge: <目的>をmainへ合流` の形にする。
- 途中の source が既に target `main` に含まれている場合は、その source は skip して次へ進む。
- conflict が出た場合は `$kei-worktree-local-main-merge` と同じ判断基準で扱う。解決可能な同一仕様変更の stale test / snapshot / type expectation / docs / display metadata / persisted settings migration だけ最小解決してよい。
- production behavior、contract/API、DB、external state、広い refactor、または product intent 判断が必要な conflict は止める。未完了の後続 merge は実行しない。

### 5. verification を実行する

- 全 merge 完了後、target `main` 上で関連する focused verification をまとめて実行する。
- UI / TypeScript 変更では、対象 package の focused test と type-check を優先する。
- 複数 Superset source の変更が混ざる場合、各 source commit の変更ファイルから最小の test set を組み、重複実行を避ける。
- push 依頼が続く場合は別 workflow として扱い、push 前に repo policy の full gate を実行する。この skill 自体では push しない。

### 6. final response を短く返す

- merge した worktree 名、source commit、merge commit を番号順に報告する。
- skip / blocked があれば理由を明記する。
- 実行した verification と結果を報告する。
- target `main` が `origin/main` より ahead なら、その事実だけ補足する。
- source worktree は削除しない。削除依頼がある場合だけ別途扱う。

## Command Pattern

候補提示:

```bash
git worktree list --porcelain
git status -sb
git log --oneline --decorate -1
```

選択後の merge:

```bash
git status -sb
git branch --show-current
git merge-base --is-ancestor <source-sha> HEAD
git show --stat --oneline --decorate <source-sha>
git merge --no-ff <source-sha> -m "merge: <目的>をmainへ合流"
git status -sb
git log --oneline --decorate -5
```

## Safety Rules

- 番号選択または最初からの明示的な「全部」なしに local `main` へ merge しない。
- target `main` が dirty のまま merge しない。
- source worktree の未 commit 変更を暗黙に取り込まない。
- 候補提示時の古い情報だけで merge しない。選択後に必ず live recheck する。
- `git reset --hard`、`git checkout -- <file>`、untracked cleanup でユーザー変更を消さない。
- remote push、PR 作成、deploy、external service 変更はしない。
