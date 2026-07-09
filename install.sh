#!/usr/bin/env bash
# Install the superset-handoff-flow skills into ~/.codex/skills.
# Idempotent: existing symlinks are refreshed, existing real
# directories are left untouched and reported.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.codex/skills"
mkdir -p "$DEST"
status=0

echo "== prerequisites"
for cmd in git codex superset; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "ok: $cmd ($(command -v "$cmd"))"
  else
    echo "MISSING: $cmd — install it before using the flow" >&2
    [ "$cmd" = git ] && exit 1
  fi
done
command -v gh >/dev/null 2>&1 && echo "ok: gh" || echo "note: gh not found (needed only for kei-create-pr)"

echo
echo "== pruning renamed skills"
legacy_name="kei-implementation-preflight"
legacy_target="$DEST/$legacy_name"
expected_target="$HERE/skills/$legacy_name"
if [ -L "$legacy_target" ]; then
  current_target="$(readlink "$legacy_target")"
  if [ "$current_target" = "$expected_target" ]; then
    unlink "$legacy_target"
    echo "removed renamed skill link: $legacy_name"
  else
    echo "SKIPPED (legacy symlink points elsewhere): $legacy_target -> $current_target" >&2
    status=1
  fi
elif [ -e "$legacy_target" ]; then
  echo "SKIPPED (legacy skill is not a symlink): $legacy_target" >&2
  status=1
fi

echo
echo "== linking skills"
for s in "$HERE"/skills/*/; do
  name="$(basename "$s")"
  target="$DEST/$name"
  if [ -L "$target" ]; then
    ln -sfn "${s%/}" "$target"
    echo "refreshed: $name"
  elif [ -e "$target" ]; then
    echo "SKIPPED (already exists, not a symlink): $target" >&2
    status=1
  else
    ln -s "${s%/}" "$target"
    echo "linked: $name"
  fi
done

echo
echo "== verification"
for s in "$HERE"/skills/*/; do
  name="$(basename "$s")"
  if [ -f "$DEST/$name/SKILL.md" ]; then
    echo "ok: $name"
  else
    echo "FAILED: $name (SKILL.md not readable via $DEST/$name)" >&2
    status=1
  fi
done
if "$DEST/codex-review/scripts/codex-review" --help >/dev/null 2>&1; then
  echo "ok: codex-review helper runs"
else
  echo "FAILED: codex-review helper" >&2
  status=1
fi

exit "$status"
