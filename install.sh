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
removed_skills=(
  kei-implementation-preflight
  kei-prepare-implementation-brief
)
for removed_name in "${removed_skills[@]}"; do
  removed_target="$DEST/$removed_name"
  expected_target="$HERE/skills/$removed_name"
  if [ -L "$removed_target" ]; then
    current_target="$(readlink "$removed_target")"
    if [ "$current_target" = "$expected_target" ]; then
      unlink "$removed_target"
      echo "removed obsolete skill link: $removed_name"
    else
      echo "SKIPPED (obsolete symlink points elsewhere): $removed_target -> $current_target" >&2
      status=1
    fi
  elif [ -e "$removed_target" ]; then
    echo "SKIPPED (obsolete skill is not a symlink): $removed_target" >&2
    status=1
  fi
done

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
