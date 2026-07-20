#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202607201500-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  spec-guard.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Monday, July 20, 2026 00:00 EDT
# @@File             :  spec-guard.sh
# @@Description      :  PreToolUse hook: block Edit/Write on project files until AI.md/SPEC.md was read this session
# @@Changelog        :  Initial version
# @@TODO             :
# @@Other            :  Only fires inside a git repo whose root has AI.md or SPEC.md (a spec-governed project)
# @@Other            :  Meta/spec files themselves (AI.md, IDEA.md, SPEC.md, CLAUDE.md, TODO(.AI).md, PLAN(.AI).md, .claude/*, .git/*) are exempt
# @@Other            :  Pairs with spec-guard-mark.sh (PostToolUse on Read), which writes the marker this checks
# @@Resource         :  ~/.claude/memory/project_conventions.md
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202607201500-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -

set -euo pipefail

# Fail open when jq is missing — a broken hook must never block every Edit/Write
if ! command -v jq >/dev/null 2>&1; then
  printf 'spec-guard.sh: jq not found — spec guard disabled\n' >&2
  exit 0
fi

SPEC_GUARD_INPUT="$(cat)"

SPEC_GUARD_FILE_PATH=$(printf '%s' "$SPEC_GUARD_INPUT" | jq -r '.tool_input.file_path // ""')
SPEC_GUARD_SESSION_ID=$(printf '%s' "$SPEC_GUARD_INPUT" | jq -r '.session_id // ""')
[ -z "$SPEC_GUARD_FILE_PATH" ] && exit 0
[ -z "$SPEC_GUARD_SESSION_ID" ] && exit 0

# Exempt meta/spec files — these are pre-approved to edit without having read AI.md first
# (editing AI.md itself, or IDEA.md/SPEC.md/TODO/PLAN, is not "implementing against the spec")
case "$SPEC_GUARD_FILE_PATH" in
  */.git/* | */.claude/*) exit 0 ;;
esac
case "$(basename -- "$SPEC_GUARD_FILE_PATH")" in
  AI.md | IDEA.md | SPEC.md | CLAUDE.md | TODO.AI.md | TODO.md | PLAN.AI.md | PLAN.md \
    | COMMIT_MESS | .env | app.env | default.env | .no_push | README.md | LICENSE.md)
    exit 0
    ;;
esac

SPEC_GUARD_PROJECT=$(git -C "$(dirname -- "$SPEC_GUARD_FILE_PATH")" rev-parse --show-toplevel 2>/dev/null) || exit 0

# Only gate projects that actually have a spec to read
[ -f "$SPEC_GUARD_PROJECT/AI.md" ] || [ -f "$SPEC_GUARD_PROJECT/SPEC.md" ] || exit 0

SPEC_GUARD_MARKER="${TMPDIR:-/tmp}/claude-spec-guard/${SPEC_GUARD_SESSION_ID}/read"
grep -qxF -- "$SPEC_GUARD_PROJECT" "$SPEC_GUARD_MARKER" 2>/dev/null && exit 0

SPEC_GUARD_MSG="BLOCKED: Spec guard — AI.md/SPEC.md for this project has not been read yet this session.
project_dir: ${SPEC_GUARD_PROJECT}
Before editing project files: run \`grep -n '^# PART' AI.md\` to find the slice relevant to this task, Read that slice (and SPEC.md if present), then retry this edit.
This gate re-arms after every compaction — re-read the spec again after a compact before resuming edits."

printf '%s\n' "$SPEC_GUARD_MSG"
printf '%s\n' "$SPEC_GUARD_MSG" >&2
exit 2
