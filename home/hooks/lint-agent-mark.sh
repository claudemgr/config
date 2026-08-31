#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608302400-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  lint-agent-mark.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 22:00 EDT
# @@File             :  lint-agent-mark.sh
# @@Description      :  SubagentStop hook: records the lint gate satisfied when script-lint/go-lint/rust-lint finishes, since it never runs as a host command.
# @@Changelog        :  Marker dir moved from unnamespaced claude-test-lint-guard to claudemgr/config/test-lint-guard, per tempdir_conventions.md's org/internal_name namespacing rule.
# @@TODO             :  None
# @@Other            :  No pass/fail field exists for a finished subagent, so completion itself counts as satisfied; writes the same marker enforce-test-lint-gate.sh checks.
# @@Resource         :  CLAUDE.md - Commit Workflow (Lint gate), home/hooks/test-lint-mark.sh, home/hooks/enforce-test-lint-gate.sh
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608302400-git"
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

# tempdir_conventions.md's mandated shape is {project_org}/{internal_name}-XXXXXX,
# but the -XXXXXX random mktemp suffix is for one-shot unique dirs; this marker
# must be a deterministic, reconstructable path so enforce-test-lint-gate.sh's
# reader can look it up again by session_id alone (and so it matches the same
# path test-lint-mark.sh writes). session_id already serves the uniqueness
# role -XXXXXX would, so it replaces that suffix here while still satisfying
# the org/internal_name namespacing the rule requires. Per IDEA.md, this
# project's frozen internal org is claudemgr and its frozen internal name
# is config.
LINT_AGENT_MARK_DIR="${TMPDIR:-/tmp}/claudemgr/config/test-lint-guard/${LINT_AGENT_MARK_SESSION_ID}"
mkdir -p "$LINT_AGENT_MARK_DIR"
chmod 700 "${TMPDIR:-/tmp}/claudemgr/config/test-lint-guard" "$LINT_AGENT_MARK_DIR" 2>/dev/null || true

# Prune marker dirs older than 1 day — scoped only to this tool's own temp namespace
find "${TMPDIR:-/tmp}/claudemgr/config/test-lint-guard" -maxdepth 1 -type d -mtime +1 -exec rm -rf -- {} + 2>/dev/null || true

LINT_AGENT_MARK_MARKER="$LINT_AGENT_MARK_DIR/lint"
grep -qxF -- "$LINT_AGENT_MARK_PROJECT" "$LINT_AGENT_MARK_MARKER" 2>/dev/null \
  || printf '%s\n' "$LINT_AGENT_MARK_PROJECT" >>"$LINT_AGENT_MARK_MARKER"

exit 0
