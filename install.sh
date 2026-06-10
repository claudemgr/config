#!/usr/bin/env sh
# shellcheck shell=sh
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202605121722-git
# @@Author           :  Jason Hempstead
# @@Contact          :  jason@casjaysdev.pro
# @@License          :  LICENSE.md
# @@ReadME           :  install.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Tuesday, May 12, 2026 17:22 EDT
# @@File             :  install.sh
# @@Description      :
# @@Changelog        :  New script
# @@TODO             :  Better documentation
# @@Other            :
# @@Resource         :
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/sh
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
APPNAME="${0##*/}"
VERSION="202605121722-git"
RUN_USER="${USER}"
SET_UID="$(id -u)"
SCRIPT_SRC_DIR="$(dirname -- "$0")"
INSTALL_SH_CWD="${PWD}"
# - - - - - - - - - - - - - - - - - - - - - - - - -
# colorization
if [ -n "${NO_COLOR+x}" ] || [ "${SHOW_RAW}" = "true" ]; then
  __printf_color() { printf '%s\n' "$1"; }
else
  __printf_color() { if [ -t 1 ]; then printf '%b%s%b\n' "${2:-$PRINTF_SET_RESET}" "$1" "$PRINTF_SET_RESET"; else printf '%s\n' "$1"; fi; }
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
# check for command
__cmd_exists() { command -v "$1" >/dev/null 2>&1; }
__function_exists() { case "$(type "$1" 2>/dev/null)" in *function*) return 0 ;; *) return 1 ;; esac; }
# - - - - - - - - - - - - - - - - - - - - - - - - -
# custom functions
__git_clone() { git clone "$1" "$2" -q; }
__git_local() { git -C "$CLAUDE_LOCAL_REPO" "$@"; }
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Define variables
PRINTF_SET_BLACK='\033[1;30m'
PRINTF_SET_RED='\033[0;31m'
PRINTF_SET_GREEN='\033[0;32m'
PRINTF_SET_YELLOW='\033[1;33m'
PRINTF_SET_BLUE='\033[1;34m'
PRINTF_SET_PURPLE='\033[0;35m'
PRINTF_SET_CYAN='\033[0;36m'
PRINTF_SET_WHITE='\033[1;37m'
PRINTF_SET_RESET='\033[0m'
INSTALL_SH_EXIT_STATUS=0
CLAUDE_LOCAL_REPO="$HOME/.local/dotfiles/claude"
CLAUDE_CONFIG_REPO="https://github.com/claudemgr/config"
[ -z "$GITHUB_TOKEN" ] && GITHUB_TOKEN="$GITHUB_ACCESS_TOKEN"
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Main application
if ! __cmd_exists git; then
  __printf_color "git is not installed" "$PRINTF_SET_RED" >&2
  exit 1
fi
if ! __cmd_exists claude; then
  __printf_color "claude code is not installed" "$PRINTF_SET_RED" >&2
  exit 1
fi
if ! __cmd_exists npx; then
  __printf_color "npx is not installed — fetch MCP server will be skipped" "$PRINTF_SET_YELLOW" >&2
fi
if [ -d "$CLAUDE_LOCAL_REPO/.git" ]; then
  __printf_color "Updating the claude configs in $CLAUDE_LOCAL_REPO" "$PRINTF_SET_CYAN"
  __git_local reset --hard -q
  __git_local pull -q
  INSTALL_SH_EXIT_STATUS=$?
else
  if [ -d "$CLAUDE_LOCAL_REPO" ]; then
    [ -n "$CLAUDE_LOCAL_REPO" ] && rm -Rf "$CLAUDE_LOCAL_REPO"
  fi
  __printf_color "cloning $CLAUDE_CONFIG_REPO to $CLAUDE_LOCAL_REPO" "$PRINTF_SET_CYAN"
  __git_clone "$CLAUDE_CONFIG_REPO" "$CLAUDE_LOCAL_REPO"
  INSTALL_SH_EXIT_STATUS=$?
fi
__printf_color "Updating claude code"
if ! \claude update >/dev/null 2>&1; then __printf_color "claude code failed to update" "$PRINTF_SET_RED" >&2; fi
if [ "$INSTALL_SH_EXIT_STATUS" = 0 ]; then
  cp -R "$CLAUDE_LOCAL_REPO/home/." "$HOME/.claude/"
  find "$HOME/.claude/hooks" -name '*.sh' -exec chmod 755 {} \;
  \claude plugin install gopls-lsp@claude-plugins-official 2>/dev/null || true
  \claude plugin install rust-analyzer-lsp@claude-plugins-official 2>/dev/null || true
  \claude plugin install typescript-lsp@claude-plugins-official 2>/dev/null || true
  if [ -n "${GITHUB_TOKEN}" ]; then
    \claude mcp remove --scope user github 2>/dev/null || true
    \claude mcp add --scope user --transport http github https://api.githubcopilot.com/mcp/ --header "Authorization: Bearer ${GITHUB_TOKEN}" 2>/dev/null >/dev/null || true
  else
    __printf_color "GITHUB_TOKEN not set — skipping GitHub MCP server" "$PRINTF_SET_YELLOW" >&2
  fi
  if __cmd_exists npx; then
    \claude mcp remove --scope user fetch 2>/dev/null || true
    \claude mcp add --scope user --transport stdio fetch -- npx -y @anthropic-ai/mcp-server-fetch 2>/dev/null || true
  fi
  python3 -c "
import json, pathlib
p = pathlib.Path.home() / '.claude.json'
if p.exists():
    d = json.loads(p.read_text())
    d['autoCompactEnabled'] = True
    p.write_text(json.dumps(d, indent=2))
" 2>/dev/null || true
  if [ "$INSTALL_SH_EXIT_STATUS" = 0 ]; then
    __printf_color "The claude config files, plugins, and MCP servers have been installed" "$PRINTF_SET_GREEN"
  else
    __printf_color "Installation completed with errors (exit: $INSTALL_SH_EXIT_STATUS)" "$PRINTF_SET_YELLOW" >&2
  fi
fi

# - - - - - - - - - - - - - - - - - - - - - - - - -
# End application
# - - - - - - - - - - - - - - - - - - - - - - - - -
# lets exit with code
# - - - - - - - - - - - - - - - - - - - - - - - - -
exit $INSTALL_SH_EXIT_STATUS
# - - - - - - - - - - - - - - - - - - - - - - - - -
# ex: ts=2 sw=2 et filetype=sh
