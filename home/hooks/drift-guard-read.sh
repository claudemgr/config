#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202605160000-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  drift-guard-read.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Friday, May 16, 2026 00:00 EDT
# @@File             :  drift-guard-read.sh
# @@Description      :  PreToolUse hook: block reading ~/.claude/ deployed copies when home/ source exists
# @@Changelog        :  New File
# @@TODO             :
# @@Other            :  Fires only when inside a claudemgr/config project (detected by presence of home/CLAUDE.md)
# @@Resource         :
# - - - - - - - - - - - - - - - - - - - - - - - - -

set -euo pipefail

INPUT="$(cat)"

# Extract file_path from the Read tool input
file_path=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')
[ -z "$file_path" ] && exit 0

# Resolve leading ~ to $HOME
file_path="${file_path/#\~/$HOME}"

# Only check paths under ~/.claude/
case "$file_path" in
  "$HOME/.claude/CLAUDE.md" | "$HOME/.claude/memory/"* | "$HOME/.claude/agents/"*)
    ;;
  *)
    exit 0
    ;;
esac

# Only enforce when inside a project that has home/CLAUDE.md (claudemgr/config signature)
project=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$project/home/CLAUDE.md" ] || exit 0

# Compute the home/-relative path for the redirect message
relative="${file_path#"$HOME/.claude/"}"

MSG="BLOCKED: Drift guard — read home/${relative} (source) not ~/.claude/${relative} (deployed copy).
Source files live in ${project}/home/ and are deployed to ~/.claude/ by the deploy script.
Never read deployed copies from within this project."

printf '%s\n' "$MSG"
printf '%s\n' "$MSG" >&2
exit 2
