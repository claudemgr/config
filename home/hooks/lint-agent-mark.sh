#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608302200-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  lint-agent-mark.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 22:00 EDT
# @@File             :  lint-agent-mark.sh
# @@Description      :  SubagentStop hook: records the lint gate as satisfied when the
# @@Description      :  script-lint / go-lint / rust-lint subagent finishes for this project
# @@Description      :  and session. CLAUDE.md's lint gate (script-lint/go-lint/rust-lint) is
# @@Description      :  actually run via the Agent tool (a subagent), never as a host CLI
# @@Description      :  command, so test-lint-mark.sh's PostToolUse-on-Bash detection can never
# @@Description      :  see it fire — this hook closes that gap using the field Claude Code
# @@Description      :  actually exposes for subagent completion (SubagentStop's agent_type),
# @@Description      :  since PostToolUse-on-Task carries no structured pass/fail signal.
# @@Changelog        :  Initial version - closes a gap found while enforcing audit #7
# @@TODO             :  None
# @@Other            :  Claude Code exposes no structured success/failure field for a finished
# @@Other            :  subagent (only free-text last_assistant_message) - completion itself is
# @@Other            :  treated as "lint gate satisfied", matching how these lint agents are
# @@Other            :  documented to work (fix violations directly, report back).
# @@Other            :  Writes to the same marker enforce-test-lint-gate.sh already checks:
# @@Other            :  ${TMPDIR:-/tmp}/claude-test-lint-guard/<session_id>/lint
# @@Other            :  Applies everywhere including the zone - no zone exception documented.
# @@Resource         :  CLAUDE.md - Commit Workflow (Lint gate), home/hooks/test-lint-mark.sh,
# @@Resource         :  home/hooks/enforce-test-lint-gate.sh
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608302200-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  printf 'lint-agent-mark.sh: jq not found — lint agent mark disabled\n' >&2
  exit 0
fi

LINT_AGENT_MARK_INPUT="$(cat)"

LINT_AGENT_MARK_TYPE=$(printf '%s' "$LINT_AGENT_MARK_INPUT" | jq -r '.agent_type // ""')
case "$LINT_AGENT_MARK_TYPE" in
  script-lint | go-lint | rust-lint) ;;
  *) exit 0 ;;
esac

LINT_AGENT_MARK_CWD=$(printf '%s' "$LINT_AGENT_MARK_INPUT" | jq -r '.cwd // ""')
LINT_AGENT_MARK_SESSION_ID=$(printf '%s' "$LINT_AGENT_MARK_INPUT" | jq -r '.session_id // ""')
[ -z "$LINT_AGENT_MARK_SESSION_ID" ] && exit 0

LINT_AGENT_MARK_PROJECT=$(git -C "${LINT_AGENT_MARK_CWD:-.}" rev-parse --show-toplevel 2>/dev/null) \
  || LINT_AGENT_MARK_PROJECT="$LINT_AGENT_MARK_CWD"
[ -z "$LINT_AGENT_MARK_PROJECT" ] && exit 0

LINT_AGENT_MARK_DIR="${TMPDIR:-/tmp}/claude-test-lint-guard/${LINT_AGENT_MARK_SESSION_ID}"
mkdir -p "$LINT_AGENT_MARK_DIR"
chmod 700 "${TMPDIR:-/tmp}/claude-test-lint-guard" "$LINT_AGENT_MARK_DIR" 2>/dev/null || true

# Prune marker dirs older than 1 day — scoped only to this tool's own temp namespace
find "${TMPDIR:-/tmp}/claude-test-lint-guard" -maxdepth 1 -type d -mtime +1 -exec rm -rf -- {} + 2>/dev/null || true

LINT_AGENT_MARK_MARKER="$LINT_AGENT_MARK_DIR/lint"
grep -qxF -- "$LINT_AGENT_MARK_PROJECT" "$LINT_AGENT_MARK_MARKER" 2>/dev/null \
  || printf '%s\n' "$LINT_AGENT_MARK_PROJECT" >>"$LINT_AGENT_MARK_MARKER"

exit 0
