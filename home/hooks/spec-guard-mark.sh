#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202607201500-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  spec-guard-mark.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Monday, July 20, 2026 00:00 EDT
# @@File             :  spec-guard-mark.sh
# @@Description      :  PostToolUse hook: record that AI.md/SPEC.md was read this session, per project
# @@Changelog        :  Initial version
# @@TODO             :
# @@Other            :  Pairs with spec-guard.sh (PreToolUse on Edit/Write), which checks the marker this writes
# @@Resource         :  ~/.claude/memory/project_conventions.md
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202607201500-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -

set -euo pipefail

# Fail open when jq is missing — a broken hook must never block every Read call
if ! command -v jq >/dev/null 2>&1; then
  printf 'spec-guard-mark.sh: jq not found — spec guard disabled\n' >&2
  exit 0
fi

SPEC_GUARD_MARK_INPUT="$(cat)"

SPEC_GUARD_MARK_FILE_PATH=$(printf '%s' "$SPEC_GUARD_MARK_INPUT" | jq -r '.tool_input.file_path // ""')
SPEC_GUARD_MARK_SESSION_ID=$(printf '%s' "$SPEC_GUARD_MARK_INPUT" | jq -r '.session_id // ""')
[ -z "$SPEC_GUARD_MARK_FILE_PATH" ] && exit 0
[ -z "$SPEC_GUARD_MARK_SESSION_ID" ] && exit 0

# Only mark on AI.md or SPEC.md — the two files spec-guard.sh gates on
case "$(basename -- "$SPEC_GUARD_MARK_FILE_PATH")" in
  AI.md | SPEC.md) ;;
  *) exit 0 ;;
esac

SPEC_GUARD_MARK_PROJECT=$(git -C "$(dirname -- "$SPEC_GUARD_MARK_FILE_PATH")" rev-parse --show-toplevel 2>/dev/null) \
  || SPEC_GUARD_MARK_PROJECT=$(dirname -- "$SPEC_GUARD_MARK_FILE_PATH")

SPEC_GUARD_MARK_DIR="${TMPDIR:-/tmp}/claude-spec-guard/${SPEC_GUARD_MARK_SESSION_ID}"
mkdir -p "$SPEC_GUARD_MARK_DIR"
chmod 700 "${TMPDIR:-/tmp}/claude-spec-guard" "$SPEC_GUARD_MARK_DIR" 2>/dev/null || true

# Prune marker dirs older than 1 day — scoped only to this tool's own temp namespace
find "${TMPDIR:-/tmp}/claude-spec-guard" -maxdepth 1 -type d -mtime +1 -exec rm -rf -- {} + 2>/dev/null || true

SPEC_GUARD_MARK_MARKER="$SPEC_GUARD_MARK_DIR/read"
grep -qxF -- "$SPEC_GUARD_MARK_PROJECT" "$SPEC_GUARD_MARK_MARKER" 2>/dev/null \
  || printf '%s\n' "$SPEC_GUARD_MARK_PROJECT" >>"$SPEC_GUARD_MARK_MARKER"

exit 0
