---
name: kei-worktree-local-main-merge
description: "作業 worktree、detached HEAD、一時 checkout で完了した local commit を、親 repo の local main に合流する workflow。ユーザーが「local mainに合流」「親mainにmerge」「このworktreeの作業をmainに取り込む」と依頼したときに使う。push、PR、deploy はしない。"
---

# Kei Worktree Local Main Merge

## Overview

worktree で完了した作業 commit を、親 repo の local `main` に安全に取り込む。
source 側と target 側の状態を分けて確認し、ユーザーの未保存作業を壊さず、merge 後に必要な local verification まで実行する。

## Workflow

1. source worktree の成果を固定する。
   - 現在の checkout で `git status -sb` と `git log --oneline --decorate -5` を実行する。
   - source が clean で、取り込む対象が commit として存在することを確認する。
   - uncommitted changes がある場合は、勝手に混ぜない。ユーザーが明示した範囲だけ commit するか、未完了として止める。
   - detached HEAD でもよいが、取り込む commit SHA を必ず記録する。

2. 親 repo の local `main` を特定する。
   - `git worktree list` で、同じ repo の `main` checkout を確認する。
   - Codex 一時 worktree から元の repo へ戻す場合は、通常 `<your-clones-root>/<org>/<repo>` が親 repo だが、推測だけで進めず実際の worktree list と path で確認する。
   - target は local `main` だけにする。remote main、PR branch、別 task branch へはこの skill では合流しない。

3. target `main` の安全確認をする。
   - target repo で `git status -sb` と `git branch --show-current` を実行する。
   - branch が `main` でない場合は、local changes がないことを確認してから `git switch main` する。
   - target `main` が dirty の場合は merge しない。変更ファイルを報告し、ユーザー判断を待つ。
   - `main...origin/main [ahead N]` は、その repo の通常運用で local commits が積まれているだけなら blocker にしない。ただし final で ahead 状態を短く報告する。

4. 既に取り込み済みか確認する。
   - target repo で `git merge-base --is-ancestor <source-sha> HEAD` を実行する。
   - 既に ancestor なら merge しない。取り込み済み commit と target HEAD を報告して止める。
   - ancestor でなければ、`git show --stat --oneline --decorate <source-sha>` で取り込む内容を最終確認する。

5. merge commit で local `main` に合流する。
   - ユーザーが `merge` / `合流` と言った場合は、通常 `git merge --no-ff <source-sha> -m "merge: <短い目的>をmainへ合流"` を使う。
   - squash や cherry-pick は、ユーザーが明示した場合だけ使う。
   - conflict が出た場合は、conflicted files を確認する。source commit の同一仕様変更に対する直接追随や、明らかな stale test / snapshot / type expectation / docs / display metadata / persisted settings migration だけなら、最小の ownership expansion として解決してよい。
   - production behavior、contract/API、DB、external state、広い refactor、または product intent 判断が必要な conflict は止めて報告する。

6. merge 後の状態を確認する。
   - target repo で `git status -sb` と `git log --oneline --decorate -5` を実行する。
   - merge commit SHA、source commit SHA、target branch、ahead count を記録する。
   - source worktree は自動削除しない。削除依頼がない限り残す。

7. local verification を実行する。
   - 直前の worktree で通した verification があっても、target `main` 合流後に最低限の focused verification を再実行する。
   - source 側で `codex-review` が clean になっていて、merge conflict 解消がない、または conflict 解消が単純で focused verification が通っている場合、merge 後に重複して `codex-review` を回さない。merge 後は target `main` 上の focused test / type-check / format check を優先する。
   - merge 後 verification で、source commit の同一仕様変更から直接生じた stale expectation が見つかった場合は、test / snapshot / type expectation / docs / display metadata / persisted settings migration の最小追随修正なら止めずに直し、focused verification を再実行する。報告では追加修正 file と理由を明記する。
   - UI / TypeScript 変更では、まず対象 package の focused test と type-check を使う。
   - `main` へ push する依頼が続く場合は、push 前に repo policy の full gate を実行する。例: `pnpm ci:check` のような repo の CI gate command。
   - docs / skill だけの変更では、skill validation や format check など、変更に対応する最小 check を選ぶ。
   - ユーザーが手元で確認すべき動作確認内容を、source commit の目的と変更ファイルから 1-3 個に絞って整理する。UI 変更なら画面、操作、期待表示を具体的に書く。backend/parser/test-only 変更でも、ユーザー視点の確認入口がある場合はそれを示す。

8. final response を短く返す。
   - local main への合流完了、merge commit、未 push、verification result を報告する。
   - 追加で「動作確認内容」を必ず報告する。実施済みの自動 verification と、ユーザーが手元で見るべき manual check を分ける。
   - target `main` が `origin/main` より ahead なら、その事実だけ補足する。
   - push、PR、deploy は、この skill では行わない。ユーザーが次に明示した場合だけ別 workflow へ進む。

## Safety Rules

- Explicit user request なしに local `main` へ merge しない。
- `git reset --hard`、`git checkout -- <file>`、untracked cleanup でユーザー変更を消さない。
- target `main` が dirty のまま merge しない。
- source worktree の未 commit 変更を暗黙に取り込まない。
- remote push、PR 作成、deploy、external service 変更はしない。
- merge conflict の解決で task scope を広げない。ただし source commit と同一仕様変更の直接追随である stale test / snapshot / type expectation / docs / display metadata / persisted settings migration は、最小 ownership expansion として解決してよい。
- production behavior、contract/API、DB、external state、広い refactor、または product intent 判断が必要な ownership expansion は止めて報告する。

## Command Pattern

Use this as the normal command shape, with actual paths and commit SHA substituted after inspection:

```bash
git status -sb
git log --oneline --decorate -5
git worktree list
```

```bash
git status -sb
git branch --show-current
git merge-base --is-ancestor <source-sha> HEAD
git show --stat --oneline --decorate <source-sha>
git merge --no-ff <source-sha> -m "merge: <目的>をmainへ合流"
git status -sb
git log --oneline --decorate -5
```

If `merge-base --is-ancestor` exits `0`, report that the commit is already included. If it exits `1`, continue. Treat any other exit code as a diagnostic failure.

