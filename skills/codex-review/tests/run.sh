#!/usr/bin/env bash
# End-to-end tests for the codex-review helper using a stubbed `codex` binary.
# Verifies the findings/clean/empty exit contract and auto mode selection,
# without invoking the real Codex CLI. bash 3.2 compatible.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
helper="$here/../scripts/codex-review"
fails=0

pass() { printf 'ok  - %s\n' "$1"; }
fail() { printf 'NOT ok - %s\n' "$1" >&2; fails=$((fails + 1)); }

# Stub codex binary: prints $STUB_OUTPUT file, exits $STUB_EXIT.
stub_dir=$(mktemp -d)
stub="$stub_dir/codex"
cat > "$stub" <<'STUB'
#!/usr/bin/env bash
# ignore all args (review --uncommitted / --base ...); emit the fixture.
[[ -n "${STUB_OUTPUT:-}" && -f "$STUB_OUTPUT" ]] && cat "$STUB_OUTPUT"
exit "${STUB_EXIT:-0}"
STUB
chmod +x "$stub"

# Fixtures.
fx_findings="$stub_dir/findings.txt"
fx_clean="$stub_dir/clean.txt"
fx_empty="$stub_dir/empty.txt"
printf '%s\n' 'Reviewed diff.' '[P1] src/app.ts: possible null deref' 'Consider guarding.' > "$fx_findings"
printf '%s\n' 'Reviewed diff.' 'No blocking issues found.' > "$fx_clean"
: > "$fx_empty"

make_repo() {
  local d; d=$(mktemp -d)/repo; mkdir -p "$d"
  git -C "$d" init -q
  git -C "$d" config user.email t@t.local
  git -C "$d" config user.name test
  printf 'v1\n' > "$d/file.txt"
  git -C "$d" add -A
  git -C "$d" commit -q -m init
  printf '%s' "$d"
}

# Run the helper in a repo; echo "exit\n<stdout>".
run_helper() {
  local repo=$1; shift
  ( cd "$repo" && "$helper" --codex-bin "$stub" "$@" )
}

# --- Scenario A: findings (dirty -> local), stub exit 0 with [P1] ---
repo=$(make_repo); printf 'dirty\n' >> "$repo/file.txt"
out=$(STUB_OUTPUT="$fx_findings" STUB_EXIT=0 run_helper "$repo"); rc=$?
if [[ $rc -eq 1 && "$out" == *"findings: accepted/actionable"* ]]; then
  pass "findings -> exit 1 + findings line"
else
  fail "findings scenario (rc=$rc)"; printf '%s\n' "$out" >&2
fi

# --- Scenario B: clean (dirty -> local), stub exit 0, no [P#] ---
repo=$(make_repo); printf 'dirty\n' >> "$repo/file.txt"
out=$(STUB_OUTPUT="$fx_clean" STUB_EXIT=0 run_helper "$repo"); rc=$?
if [[ $rc -eq 0 && "$out" == *"clean: no accepted/actionable"* ]]; then
  pass "clean -> exit 0 + clean line"
else
  fail "clean scenario (rc=$rc)"; printf '%s\n' "$out" >&2
fi

# --- Scenario C: empty output -> exit 1 + no output line ---
repo=$(make_repo); printf 'dirty\n' >> "$repo/file.txt"
out=$(STUB_OUTPUT="$fx_empty" STUB_EXIT=0 run_helper "$repo"); rc=$?
if [[ $rc -eq 1 && "$out" == *"no output"* ]]; then
  pass "empty -> exit 1 + no output line"
else
  fail "empty scenario (rc=$rc)"; printf '%s\n' "$out" >&2
fi

# --- Scenario D1: dirty repo, --dry-run -> selects local ---
repo=$(make_repo); printf 'dirty\n' >> "$repo/file.txt"
out=$(run_helper "$repo" --dry-run); rc=$?
if [[ $rc -eq 0 && "$out" == *"target: local"* ]]; then
  pass "dry-run dirty -> target local"
else
  fail "dry-run local (rc=$rc)"; printf '%s\n' "$out" >&2
fi

# --- Scenario D2: clean repo on non-main branch, --dry-run -> selects branch ---
repo=$(make_repo); git -C "$repo" switch -q -c feature/x
out=$(run_helper "$repo" --dry-run); rc=$?
if [[ $rc -eq 0 && "$out" == *"target: branch"* ]]; then
  pass "dry-run clean branch -> target branch"
else
  fail "dry-run branch (rc=$rc)"; printf '%s\n' "$out" >&2
fi

if [[ $fails -eq 0 ]]; then
  printf 'codex-review tests: all passed\n'
  exit 0
fi
printf 'codex-review tests: %s failed\n' "$fails" >&2
exit 1
