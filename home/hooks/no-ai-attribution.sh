#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202607031500-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  no-ai-attribution.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Tuesday, May 13, 2026 00:00 EDT
# @@File             :  no-ai-attribution.sh
# @@Description      :  Claude Code PreToolUse hook - block AI attribution phrases in written content
# @@Changelog        :  Broaden detection: using/Built/Made/Assisted variants, U+2011 hyphen trailers, split-string pattern assembly
# @@TODO             :  See project issues
# @@Other            :  Fires on Write and Edit tool use; blocks attribution trailers/comments only
# @@Resource         :  github.com/casapps/claude-code-hooks
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202607031500-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -uo pipefail
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Patterns that constitute AI attribution. Match only phrases where an AI
# tool is credited as the author/generator — NOT bare product names used
# in documentation, filenames, or tool references.
#
# Blocked (verb + connector + AI name, plus trailer forms):
#   verbs: Generated / Written / Created / Authored / Built / Made / Assisted
#   connectors: by / with / using
#   names: Claude, Anthropic, "an AI"
#   trailers: the Co + Authored + By git trailer naming Claude/Anthropic
#   (ASCII hyphen or Unicode non-breaking hyphen U+2011 between the words),
#   the "AI" + hyphen + "generated" adjective, robot-emoji attribution lines
#
# NOT blocked:
#   CLAUDE.md (filename)       Claude Code hook
#   Using Claude               Anthropic API docs
# - - - - - - - - - - - - - - - - - - - - - - - - -
# Pattern pieces are assembled from split strings so this file never trips its own scanner
_verbs='(generated|written|created|authored|built|made|assisted)'
_conn='(by|with|using)'
_ai='(claude|anthropic|an? ai\b)'
# ASCII hyphen or Unicode non-breaking hyphen (U+2011) between trailer words
_hyph='(-|‑)'
_ca="co${_hyph}authored${_hyph}by"
_gen='generated'
ATTRIBUTION_PATTERN="${_verbs}[[:space:]]+${_conn}[[:space:]]+${_ai}|${_ca}:[[:space:]]*(claude|anthropic)|co_authored_by:[[:space:]]*(claude|anthropic)|\bai[- ]${_gen}\b|🤖[[:space:]]*${_verbs}|(this[[:space:]]+file[[:space:]]+(was|is)[[:space:]]+(${_gen}|written|created)[[:space:]]+by[[:space:]]+(claude|anthropic|ai\b))"
# - - - - - - - - - - - - - - - - - - - - - - - - -
__require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'no-ai-attribution.sh: required command not found: %s\n' "$1" >&2
    exit 0
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - -
__extract_content() {
  python3 -c '
import json, sys
try:
    d = json.load(sys.stdin).get("tool_input", {})
    # Write tool uses "content"; Edit tool uses "new_string"
    print(d.get("content") or d.get("new_string") or "")
except Exception:
    print("")
'
}
# - - - - - - - - - - - - - - - - - - - - - - - - -
__require_cmd python3
__require_cmd grep
# - - - - - - - - - - - - - - - - - - - - - - - - -
INPUT="$(cat)"
CONTENT="$(printf '%s' "$INPUT" | __extract_content)"
# - - - - - - - - - - - - - - - - - - - - - - - - -
[ -z "$CONTENT" ] && exit 0
# - - - - - - - - - - - - - - - - - - - - - - - - -
if printf '%s' "$CONTENT" | grep -qiE -- "$ATTRIBUTION_PATTERN"; then
  printf 'BLOCKED: AI attribution phrase detected in file content.\n' >&2
  printf 'Remove lines like "Generated %s Claude", "Co%sAuthored%sBy: Claude", or "AI%sgenerated".\n' 'by' '-' '-' '-' >&2
  exit 2
fi
# - - - - - - - - - - - - - - - - - - - - - - - - -
exit 0
