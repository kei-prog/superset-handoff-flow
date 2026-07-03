---
name: kei-create-pr
description: "Kei の PR 作成 workflow。verify、commit、push、PR open まで進める。"
---

# Kei Create PR

Kei の好む style で pull request を作成する。evidence first、狭い scope、local verification、context 付き commit、push、通常の open PR 作成を default とする。

## 手順

1. repository と現在状態を確認する。
   - `git status -sb`、`git branch --show-current` を実行し、現在の diff を確認する。
   - working tree に無関係な変更がある場合は、意図した file だけを stage する。
   - 現在の branch name や upstream が明らかに別 task のものなら、混ぜずに target base から専用 branch を作る。

2. base と branch を選ぶ。
   - ユーザーが別 base を指定しない限り、repository default branch を優先する。
   - base が不明な場合は `gh repo view --json defaultBranchRef,nameWithOwner` を使う。
   - fix を表す短い `codex/...` branch name を使う。
   - 必要なら、意図した local diff だけを stash し、base から clean branch に切り替えてから stash を戻す。

3. 編集前に PR contract を定義する。
   - 観測された問題を平易に書く。
   - expected invariant、つまり PR 後に真であるべき behavior を書く。
   - 必要な最小 behavior change を書く。
   - 重要な claim を `Verified`、`Assumed`、`Not verified`、`Blocked` に分類する。
   - 観測された問題、expected invariant、最小 behavior change が内部的に整合するまで実装しない。

4. 最小で安全な変更を行う。
   - 編集前に関連 code を読む。
   - 無関係な refactor は PR から外す。
   - bug または contract を直接証明する test を優先する。
   - red test が有用なら、fix 前に 1 回実行し、重要なら failure evidence を最終 summary に残す。
   - migration、infra、billing、production、destructive change では、commit 前に rollback safety を明示する。

5. commit 前に検証する。
   - まず最も狭く意味のある test を実行する。
   - 次に、変更箇所を守る最も近い package または workflow level の test を実行する。
   - 必要に応じて formatting と `git diff --check` を実行する。
   - check を実行できない場合は、正確な blocker を書く。

6. commit 前に最終 diff を review する。
   - staged diff を reviewer 視点で確認する。
   - accidental edit、scope leakage、debug leftover、secret、unrelated formatting churn を確認する。
   - test が implementation detail ではなく intended invariant を証明しているか確認する。
   - risky change では、PR revert で prior behavior に戻ることを確認する。clean rollback でない場合は明示する。

7. reusable context 付きで commit する。
   - explicit file path を stage する。
   - concise subject を使う。
   - useful な場合は body section を加える。
     - `Context:` この変更が存在する理由
     - `Goal:` この commit が達成すべきこと
     - `Scope:` 変更したこと
     - `Out of scope:` 意図的に外したこと
     - `Behavior guard:` 保つべき behavior
     - `Rollback:` risky change の rollback または revert safety
     - `Verification:` 実行した command と結果
     - `Follow-up:` 残る risk
   - secret、token、production raw ID、長い log は含めない。
   - message body に backtick、`$()`、引用符を含める場合は、shell に解釈されない渡し方にする。single quote、heredoc、一時ファイルなどを使い、command substitution で本文が壊れないことを優先する。

8. push して PR を作成する。
   - tracking 付きで push する: `git push -u origin $(git branch --show-current)`。
   - default は通常の open PR とする。
   - draft は、ユーザーが明示した場合、変更が意図的に incomplete な場合、required verification が blocked の場合だけ使う。
   - GitHub app tool が有効でない場合は `gh pr create --base <base> --head <branch> ...` を使う。
   - PR body には summary、fix の root cause、expected invariant、impact、risky change の rollback note、verification を含める。
   - PR body に画像を貼る場合は、ローカルファイルパスではなく GitHub 上で表示できる URL を使う。repo 内 asset、GitHub upload、外部 artifact のいずれかを選び、private 情報がある画像は貼る前に扱いを確認する。
   - PR body に backtick、`$()`、引用符を含める場合も、shell に解釈されない渡し方にする。本文が長いときは一時ファイルから渡す。
   - `gh pr create` / `gh pr edit` で PR body を渡すときは、`--body-file -` の stdin 渡しに依存しない。本文が長い場合は一時ファイルを作り、`--body-file "$tmp_body"` または `--body "$(cat "$tmp_body")"` で渡す。
   - PR 作成・編集後は `gh pr view <PR> --json body --jq ...` で、本文が空でないことと `Summary` / `Verification` など必須セクションが残っていることを確認する。command success だけを本文反映の証拠にしない。

9. PR 作成で止める。
   - PR 作成後は PR URL を返す。
   - ユーザーが明示的に follow-up を頼まない限り、GitHub CI、Claude review、Cursor Automation、post-PR check を待たない。
   - plain な「create PR」依頼では、CI status や failure log を inspect しない。
   - local verification blocked により draft で開いた場合は、blocker と ready 条件を説明する。

10. final response。
   - まず PR URL を自然な 1 文で返す。
   - branch、commit、local verification、CI 未確認、draft/blocker の有無など、次の判断に必要な情報だけを短く足す。
   - 表は `Assumed` / `Not verified` / `Blocked` が複数ある場合や、比較して判断する必要がある場合だけ使う。
   - 固定見出しや定型 3 行で始めない。単純な PR 作成完了報告では、1〜2 文で十分。
   - unverified または blocked な local check は明確に書く。

## 安全ルール

- 無関係な変更を silent に stage しない。
- 別 task の branch に見える場所から、PR scope を isolate せずに push しない。
- ユーザー変更を、明示依頼なしに rewrite または discard しない。
- ユーザーが draft を頼むか、変更が未 ready と分かっている場合以外は normal open PR を優先する。
- final answer は短く保つ。decision を変える detail だけ足す。
