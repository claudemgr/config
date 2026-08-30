#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608302300-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  spec-guard-mark.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Monday, July 20, 2026 00:00 EDT
# @@File             :  spec-guard-mark.sh
# @@Description      :  PostToolUse hook: record that AI.md/SPEC.md was read this session, per project
# @@Changelog        :  Added template-repo fallback - projects with neither AI.md nor SPEC.md at
# @@Changelog        :  their root (claudemgr/{lang|type}/ template repos, whose spec is a root-level
# @@Changelog        :  *.md file like APPLICATION.md/COMPOSEMGR.md/SCRIPT.md) now mark on any such
# @@Changelog        :  root-level *.md read, so enforce-test-lint-gate.sh's spec-collection re-read
# @@Changelog        :  requirement is satisfiable for them
# @@TODO             :
# @@Other            :  Pairs with spec-guard.sh (PreToolUse on Edit/Write), which checks the marker this writes
# @@Other            :  Pairs with enforce-test-lint-gate.sh, whose spec-collection branch reuses this marker
# @@Resource         :  ~/.claude/memory/project_conventions.md
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608302300-git"
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

SPEC_GUARD_MARK_BASENAME=$(basename -- "$SPEC_GUARD_MARK_FILE_PATH")
SPEC_GUARD_MARK_DIRNAME=$(dirname -- "$SPEC_GUARD_MARK_FILE_PATH")

SPEC_GUARD_MARK_PROJECT=$(git -C "$SPEC_GUARD_MARK_DIRNAME" rev-parse --show-toplevel 2>/dev/null) \
  || SPEC_GUARD_MARK_PROJECT="$SPEC_GUARD_MARK_DIRNAME"

# Mark on AI.md or SPEC.md directly - the two files spec-guard.sh gates on.
# Template-repo fallback: a project with neither AI.md nor SPEC.md at its root
# (e.g. claudemgr/{go,rust,android,docker,mgr} - the spec is a root-level *.md
# template file like APPLICATION.md/COMPOSEMGR.md/SCRIPT.md, never named
# AI.md/SPEC.md) marks on any such root-level *.md read instead, excluding the
# well-known non-spec meta filenames.
case "$SPEC_GUARD_MARK_BASENAME" in
  AI.md | SPEC.md) ;;
  README.md | LICENSE.md | CLAUDE.md | IDEA.md | TODO.AI.md | TODO.md | PLAN.AI.md | PLAN.md)
    exit 0
    ;;
  *.md)
    [ "$SPEC_GUARD_MARK_DIRNAME" = "$SPEC_GUARD_MARK_PROJECT" ] || exit 0
    [ ! -f "$SPEC_GUARD_MARK_PROJECT/AI.md" ] || exit 0
    [ ! -f "$SPEC_GUARD_MARK_PROJECT/SPEC.md" ] || exit 0
    ;;
  *) exit 0 ;;
esac

SPEC_GUARD_MARK_DIR="${TMPDIR:-/tmp}/claude-spec-guard/${SPEC_GUARD_MARK_SESSION_ID}"
mkdir -p "$SPEC_GUARD_MARK_DIR"
chmod 700 "${TMPDIR:-/tmp}/claude-spec-guard" "$SPEC_GUARD_MARK_DIR" 2>/dev/null || true

# Prune marker dirs older than 1 day — scoped only to this tool's own temp namespace
find "${TMPDIR:-/tmp}/claude-spec-guard" -maxdepth 1 -type d -mtime +1 -exec rm -rf -- {} + 2>/dev/null || true

SPEC_GUARD_MARK_MARKER="$SPEC_GUARD_MARK_DIR/read"
grep -qxF -- "$SPEC_GUARD_MARK_PROJECT" "$SPEC_GUARD_MARK_MARKER" 2>/dev/null || printf '%s\n' "$SPEC_GUARD_MARK_PROJECT" >>"$SPEC_GUARD_MARK_MARKER"

exit 0
