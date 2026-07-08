#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202607031500-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  drift-guard-read.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Friday, May 16, 2026 00:00 EDT
# @@File             :  drift-guard-read.sh
# @@Description      :  PreToolUse hook: block reading ~/.claude/ deployed copies when home/ source exists
# @@Changelog        :  Fail open with a stderr warning when jq is missing
# @@TODO             :
# @@Other            :  Fires only when inside a claudemgr/config project (detected by presence of home/CLAUDE.md)
# @@Resource         :
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202607031500-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -

set -euo pipefail

# Fail open when jq is missing — a broken hook must never block every Read call
if ! command -v jq >/dev/null 2>&1; then
  printf 'drift-guard-read.sh: jq not found — drift guard disabled\n' >&2
  exit 0
fi

DRIFT_GUARD_READ_INPUT="$(cat)"

# Extract file_path from the Read tool input
DRIFT_GUARD_READ_FILE_PATH=$(printf '%s' "$DRIFT_GUARD_READ_INPUT" | jq -r '.tool_input.file_path // ""')
[ -z "$DRIFT_GUARD_READ_FILE_PATH" ] && exit 0

# Resolve leading ~ to $HOME
DRIFT_GUARD_READ_FILE_PATH="${DRIFT_GUARD_READ_FILE_PATH/#\~/$HOME}"

# Only check paths under ~/.claude/ that have a home/ source equivalent
case "$DRIFT_GUARD_READ_FILE_PATH" in
  "$HOME/.claude/CLAUDE.md" \
  | "$HOME/.claude/settings.json" \
  | "$HOME/.claude/memory/"* \
  | "$HOME/.claude/agents/"* \
  | "$HOME/.claude/hooks/"* \
  | "$HOME/.claude/skills/"* \
  | "$HOME/.claude/TEMPLATES/"*)
    ;;
  *)
    exit 0
    ;;
esac

# Only enforce when inside a project that has home/CLAUDE.md (claudemgr/config signature)
DRIFT_GUARD_READ_PROJECT=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$DRIFT_GUARD_READ_PROJECT/home/CLAUDE.md" ] || exit 0

# Compute the home/-relative path for the redirect message
DRIFT_GUARD_READ_RELATIVE="${DRIFT_GUARD_READ_FILE_PATH#"$HOME/.claude/"}"

DRIFT_GUARD_READ_MSG="BLOCKED: Drift guard — read home/${DRIFT_GUARD_READ_RELATIVE} (source) not ~/.claude/${DRIFT_GUARD_READ_RELATIVE} (deployed copy).
Source files live in ${DRIFT_GUARD_READ_PROJECT}/home/ and are deployed to ~/.claude/ by the deploy script.
Never read deployed copies from within this project."

printf '%s\n' "$DRIFT_GUARD_READ_MSG"
printf '%s\n' "$DRIFT_GUARD_READ_MSG" >&2
exit 2
