#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202609031200-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  statusline.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Thursday, September 3, 2026 00:00 EDT
# @@File             :  statusline.sh
# @@Description      :  Claude Code statusLine command — 2-line model/usage/cost + dir/agent/worktree summary
# @@Changelog        :  Initial version, extracted from the inline settings.json jq one-liner; dropped git branch/status (too resource-intensive across many concurrent sessions)
# @@TODO             :
# @@Other            :  Honors NO_COLOR (no-color.org) — disables both color and emoji
# @@Resource         :  https://code.claude.com/docs/en/statusline
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202609031200-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -

set -euo pipefail

# Fail open — a missing jq or malformed payload must never crash the statusline
__cmd_exists() { command -v -- "$1" >/dev/null 2>&1; }
__cmd_exists jq || { printf '[?]\n?\n'; exit 0; }

payload="$(cat 2>/dev/null || true)"
[ -n "${payload}" ] || { printf '[?]\n?\n'; exit 0; }

if [ -n "${NO_COLOR:-}" ]; then
  USE_COLOR=0
else
  USE_COLOR=1
fi

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Color helpers — ANSI direct (never tput), suppressed under NO_COLOR
# - - - - - - - - - - - - - - - - - - - - - - - - -
c_reset=""
c_bold=""
c_cyan=""
c_magenta=""
c_green=""
c_yellow=""
c_red=""
c_dim=""
if [ "$USE_COLOR" -eq 1 ]; then
  c_reset=$'\033[0m'
  c_bold=$'\033[1m'
  c_cyan=$'\033[36m'
  c_magenta=$'\033[35m'
  c_green=$'\033[32m'
  c_yellow=$'\033[33m'
  c_red=$'\033[31m'
  c_dim=$'\033[2m'
fi

# threshold color for a percentage: green <50, yellow 50-79, red >=80
__pct_color() {
  v="$1"
  [ "$USE_COLOR" -eq 1 ] || { printf '%s' "$v"; return; }
  if [ "$v" = "?" ]; then
    printf '%s%s%s' "$c_dim" "$v" "$c_reset"
    return
  fi
  n="${v%.*}"
  if [ "$n" -ge 80 ] 2>/dev/null; then
    printf '%s%s%s' "$c_red" "$v" "$c_reset"
  elif [ "$n" -ge 50 ] 2>/dev/null; then
    printf '%s%s%s' "$c_yellow" "$v" "$c_reset"
  else
    printf '%s%s%s' "$c_green" "$v" "$c_reset"
  fi
}

emoji() {
  [ "$USE_COLOR" -eq 1 ] && printf '%s' "$1" || true
}

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Extract fields from the Claude Code statusLine JSON payload
# - - - - - - - - - - - - - - - - - - - - - - - - -
fields="$(printf '%s' "${payload}" | jq -r '
  def p(v): if v==null then "?" else (v|floor|tostring) end;
  def money(v): if v==null then "?" else ((v*100|round)/100|tostring) end;
  [
    (.model.display_name // "?"),
    p(.context_window.used_percentage),
    p(.rate_limits.five_hour.used_percentage),
    p(.rate_limits.seven_day.used_percentage),
    p(.rate_limits.spend_limit.used_percentage),
    money(.cost.total_cost_usd),
    (.effort.level // env.CLAUDE_CODE_EFFORT_LEVEL // "?"),
    (.workspace.current_dir // .cwd // env.PWD // "?"),
    (.cost.total_lines_added // 0 | tostring),
    (.cost.total_lines_removed // 0 | tostring),
    (.agent.name // ""),
    (.worktree.name // "")
  ] | @tsv
' 2>/dev/null)" || fields=""

if [ -z "${fields}" ]; then
  printf '[?]\n?\n'
  exit 0
fi

IFS=$'\t' read -r model ctx_pct five_pct seven_pct spend_pct cost effort dir lines_added lines_removed agent_name worktree_name <<<"${fields}"

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Line 1: model | context % | 5h/7d rate limits | cost | effort
# - - - - - - - - - - - - - - - - - - - - - - - - -
model_part="$(emoji '🧠 ')${c_bold}${c_cyan}[${model}]${c_reset}"
ctx_part="$(emoji '📊 ')$(__pct_color "${ctx_pct}")% ctx"
rate_part="$(emoji '⏱ ')5h $(__pct_color "${five_pct}")% | W $(__pct_color "${seven_pct}")%"
if [ "${spend_pct}" != "?" ]; then
  rate_part="${rate_part} spend $(__pct_color "${spend_pct}")%"
fi
cost_part="$(emoji '💰 ')${c_green}\$${cost}${c_reset}"
effort_part="$(emoji '🎚 ')${c_magenta}${effort}${c_reset}"

line1="${model_part} ${ctx_part} | ${rate_part} | ${cost_part} | ${effort_part}"

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Line 2: dir + extras
# - - - - - - - - - - - - - - - - - - - - - - - - -
# No git branch/status here on purpose — shelling out to git per statusline
# refresh is too resource-intensive across many concurrent sessions.
short_dir="${dir/#"$HOME"/'~'}"

extras=""
if [ "${lines_added}" != "0" ] || [ "${lines_removed}" != "0" ]; then
  extras="${extras} | $(emoji '✏️ ')${c_green}+${lines_added}${c_reset}/${c_red}-${lines_removed}${c_reset}"
fi
if [ -n "${agent_name}" ]; then
  extras="${extras} | $(emoji '🧩 ')${agent_name}"
fi
if [ -n "${worktree_name}" ]; then
  extras="${extras} | $(emoji '🌳 ')${worktree_name}"
fi

line2="$(emoji '📁 ')${c_dim}${short_dir}${c_reset}${extras}"

printf '%s\n%s\n' "${line1}" "${line2}"
