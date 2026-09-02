#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608302205-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  lint-agent-mark.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 22:00 EDT
# @@File             :  lint-agent-mark.sh
# @@Description      :  SubagentStop hook: records the lint gate satisfied when script-lint/go-lint/rust-lint reports a clean result.
# @@Changelog        :  Now parses last_assistant_message for the clean/issues-found contract instead of marking on bare subagent completion.
# @@TODO             :  None
# @@Other            :  Lint agents always end their report `: clean` or `: N issue(s) found` — last_assistant_message is checked against that; issues found skips the marker.
# @@Resource         :  CLAUDE.md - Commit Workflow (Lint gate), home/hooks/test-lint-mark.sh, home/hooks/enforce-test-lint-gate.sh
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608302205-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  printf 'lint-agent-mark.sh: jq not found — lint agent mark disabled\n' >&2
  exit 0
fi

LINT_AGENT_MARK_INPUT="$(cat)"

# Fail open on an empty, malformed, or non-object payload. Without this, jq
# exits 4/5 and `set -e` propagates that code, which Claude Code surfaces as a
# "hook error" instead of the silent no-op Part 6 requires on a parse failure.
if ! printf '%s' "$LINT_AGENT_MARK_INPUT" | jq -e 'type == "object"' >/dev/null 2>&1; then
  exit 0
fi

LINT_AGENT_MARK_TYPE=$(printf '%s' "$LINT_AGENT_MARK_INPUT" | jq -r 'try (.agent_type) catch "" // ""')
case "$LINT_AGENT_MARK_TYPE" in
  script-lint | go-lint | rust-lint) ;;
  *) exit 0 ;;
esac

LINT_AGENT_MARK_CWD=$(printf '%s' "$LINT_AGENT_MARK_INPUT" | jq -r 'try (.cwd) catch "" // ""')
LINT_AGENT_MARK_SESSION_ID=$(printf '%s' "$LINT_AGENT_MARK_INPUT" | jq -r 'try (.session_id) catch "" // ""')
[ -z "$LINT_AGENT_MARK_SESSION_ID" ] && exit 0

# script-lint/go-lint/rust-lint's own Output Format section ends every
# report with `: clean` (pass) or `: N issue(s) found` (fail), one line
# per file/package/crate — a multi-file run must be ALL clean, so any
# "issue(s) found" line anywhere disqualifies the whole report.
LINT_AGENT_MARK_MSG=$(printf '%s' "$LINT_AGENT_MARK_INPUT" | jq -r 'try (.last_assistant_message) catch "" // ""')
printf '%s' "$LINT_AGENT_MARK_MSG" | grep -qE -- ': clean\b' || exit 0
printf '%s' "$LINT_AGENT_MARK_MSG" | grep -qE -- ': [0-9]+ issue\(s\) found\b' && exit 0

LINT_AGENT_MARK_PROJECT=$(git -C "${LINT_AGENT_MARK_CWD:-.}" rev-parse --show-toplevel 2>/dev/null) \
  || LINT_AGENT_MARK_PROJECT="$LINT_AGENT_MARK_CWD"
[ -z "$LINT_AGENT_MARK_PROJECT" ] && exit 0

# This marker must be a deterministic, reconstructable path so
# enforce-test-lint-gate.sh's reader can look it up again by session_id
# alone (and so it matches the same path test-lint-mark.sh writes).
# session_id serves as the uniqueness key here. The namespace is
# claude-hooks, not a repo name — these hooks deploy to ~/.claude/hooks
# and run for every project's session, not just this one.
LINT_AGENT_MARK_DIR="${TMPDIR:-/tmp}/claude-hooks/test-lint-guard/${LINT_AGENT_MARK_SESSION_ID}"
mkdir -p "$LINT_AGENT_MARK_DIR"
chmod 700 "${TMPDIR:-/tmp}/claude-hooks/test-lint-guard" "$LINT_AGENT_MARK_DIR" 2>/dev/null || true

# Prune marker dirs older than 1 day — scoped only to this tool's own temp namespace
find "${TMPDIR:-/tmp}/claude-hooks/test-lint-guard" -maxdepth 1 -type d -mtime +1 -exec rm -rf -- {} + 2>/dev/null || true

LINT_AGENT_MARK_MARKER="$LINT_AGENT_MARK_DIR/lint"
grep -qxF -- "$LINT_AGENT_MARK_PROJECT" "$LINT_AGENT_MARK_MARKER" 2>/dev/null \
  || printf '%s\n' "$LINT_AGENT_MARK_PROJECT" >>"$LINT_AGENT_MARK_MARKER"

exit 0
