#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202608301735-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  test-lint-mark.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, August 30, 2026 22:00 EDT
# @@File             :  test-lint-mark.sh
# @@Description      :  PostToolUse Bash hook: records, per session and project, that a test-gate
# @@Description      :  command (make test, go test, cargo test, pytest, npm test; bash -n only
# @@Description      :  counts for a script-collection project — no Makefile/go.mod/Cargo.toml/
# @@Description      :  package.json/pyproject.toml/setup.py) or a
# @@Description      :  lint-gate command (script-lint, go-lint, rust-lint — CLAUDE.md's Commit
# @@Description      :  Workflow Lint gate names exactly these three, never `make lint`) exited 0
# @@Description      :  in this Bash call. Pairs with enforce-test-lint-gate.sh (PreToolUse on
# @@Description      :  gitcommit), which checks the markers this writes.
# @@Changelog        :  Initial version
# @@Changelog        :  Removed `make lint` from the lint-gate detection regex — CLAUDE.md's Lint
# @@Changelog        :  gate is defined as exactly script-lint/go-lint/rust-lint, and a project's
# @@Changelog        :  own `make lint` target (makefile_conventions.md) runs generic tooling
# @@Changelog        :  (golangci-lint/clippy/etc.), not the CasjaysDev-specific convention checks
# @@Changelog        :  those three agents perform — accepting it as equivalent would let a commit
# @@Changelog        :  through without the actual mandated lint gate ever running
# @@Changelog        :  Fixed stdin read: `$(< /dev/stdin)` fails with ENXIO because hook stdin is
# @@Changelog        :  a socket, not a real file — reported by the user hitting the actual error
# @@Changelog        :  live ("/dev/stdin: No such device or address"); switched to `$(cat)`, matching
# @@Changelog        :  the pattern already used by protect-host.sh/enforce-docker-rm.sh
# @@Changelog        :  `bash -n` no longer satisfies the test gate for every project type —
# @@Changelog        :  home/CLAUDE.md's Test gate scopes `bash -n` to script-collection projects
# @@Changelog        :  only; a project with a real manifest (Makefile/go.mod/Cargo.toml/
# @@Changelog        :  package.json/pyproject.toml/setup.py) now requires its actual test runner
# @@TODO             :  None
# @@Other            :  Only marks on exit_code == 0 and interrupted == false - a failed or
# @@Other            :  timed-out test/lint run must never count as passing
# @@Resource         :  CLAUDE.md - Commit Workflow (Test gate, Lint gate), home/hooks/spec-guard-mark.sh
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202608301735-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -euo pipefail

# Fail open when jq is missing — a broken hook must never crash the tool run
if ! command -v jq >/dev/null 2>&1; then
  printf 'test-lint-mark.sh: jq not found — test/lint mark disabled\n' >&2
  exit 0
fi

# $(cat) is required here — hook stdin is a socket; $(</dev/stdin) re-opens it and fails with ENXIO
TEST_LINT_MARK_INPUT="$(cat)"

TEST_LINT_MARK_TOOL=$(printf '%s' "$TEST_LINT_MARK_INPUT" | jq -r '.tool_name // ""')
[ "$TEST_LINT_MARK_TOOL" = "Bash" ] || exit 0

TEST_LINT_MARK_EXIT=$(printf '%s' "$TEST_LINT_MARK_INPUT" | jq -r '.tool_response.exit_code // 1')
TEST_LINT_MARK_INTERRUPTED=$(printf '%s' "$TEST_LINT_MARK_INPUT" | jq -r '.tool_response.interrupted // false')
[ "$TEST_LINT_MARK_EXIT" = "0" ] || exit 0
[ "$TEST_LINT_MARK_INTERRUPTED" = "false" ] || exit 0

TEST_LINT_MARK_CMD=$(printf '%s' "$TEST_LINT_MARK_INPUT" | jq -r '.tool_input.command // ""')
TEST_LINT_MARK_CWD=$(printf '%s' "$TEST_LINT_MARK_INPUT" | jq -r '.cwd // ""')
TEST_LINT_MARK_SESSION_ID=$(printf '%s' "$TEST_LINT_MARK_INPUT" | jq -r '.session_id // ""')
[ -z "$TEST_LINT_MARK_CMD" ] && exit 0
[ -z "$TEST_LINT_MARK_SESSION_ID" ] && exit 0

TEST_LINT_MARK_IS_TEST=0
TEST_LINT_MARK_IS_LINT=0
TEST_LINT_MARK_IS_BASHN=0
printf '%s' "$TEST_LINT_MARK_CMD" | grep -qE -- '\bmake[[:space:]]+test\b|\bgo[[:space:]]+test\b|\bcargo[[:space:]]+test\b|\bpytest\b|\bnpm[[:space:]]+(run[[:space:]]+)?test\b' \
  && TEST_LINT_MARK_IS_TEST=1
printf '%s' "$TEST_LINT_MARK_CMD" | grep -qE -- '\bbash[[:space:]]+-n\b' \
  && TEST_LINT_MARK_IS_BASHN=1
printf '%s' "$TEST_LINT_MARK_CMD" | grep -qE -- '\bscript-lint\b|\bgo-lint\b|\brust-lint\b' \
  && TEST_LINT_MARK_IS_LINT=1

[ "$TEST_LINT_MARK_IS_TEST" = "1" ] || [ "$TEST_LINT_MARK_IS_BASHN" = "1" ] || [ "$TEST_LINT_MARK_IS_LINT" = "1" ] || exit 0

TEST_LINT_MARK_PROJECT=$(git -C "${TEST_LINT_MARK_CWD:-.}" rev-parse --show-toplevel 2>/dev/null) \
  || TEST_LINT_MARK_PROJECT="$TEST_LINT_MARK_CWD"
[ -z "$TEST_LINT_MARK_PROJECT" ] && exit 0

# `bash -n` only satisfies the test gate for script-collection projects
# (home/CLAUDE.md's Test gate line) — a project with a real test runner
# (Makefile/go.mod/Cargo.toml/package.json/pyproject.toml/setup.py) must
# not have its test gate satisfied by syntax-checking an unrelated script.
if [ "$TEST_LINT_MARK_IS_BASHN" = "1" ] && [ "$TEST_LINT_MARK_IS_TEST" != "1" ]; then
  TEST_LINT_MARK_IS_SCRIPT_COLLECTION=1
  for TEST_LINT_MARK_MANIFEST in Makefile go.mod Cargo.toml package.json pyproject.toml setup.py; do
    [ -f "$TEST_LINT_MARK_PROJECT/$TEST_LINT_MARK_MANIFEST" ] && TEST_LINT_MARK_IS_SCRIPT_COLLECTION=0 && break
  done
  if [ "$TEST_LINT_MARK_IS_SCRIPT_COLLECTION" = "1" ]; then
    TEST_LINT_MARK_IS_TEST=1
  fi
fi
[ "$TEST_LINT_MARK_IS_TEST" = "1" ] || [ "$TEST_LINT_MARK_IS_LINT" = "1" ] || exit 0

TEST_LINT_MARK_DIR="${TMPDIR:-/tmp}/claude-test-lint-guard/${TEST_LINT_MARK_SESSION_ID}"
mkdir -p "$TEST_LINT_MARK_DIR"
chmod 700 "${TMPDIR:-/tmp}/claude-test-lint-guard" "$TEST_LINT_MARK_DIR" 2>/dev/null || true

# Prune marker dirs older than 1 day — scoped only to this tool's own temp namespace
find "${TMPDIR:-/tmp}/claude-test-lint-guard" -maxdepth 1 -type d -mtime +1 -exec rm -rf -- {} + 2>/dev/null || true

if [ "$TEST_LINT_MARK_IS_TEST" = "1" ]; then
  TEST_LINT_MARK_TEST_MARKER="$TEST_LINT_MARK_DIR/test"
  grep -qxF -- "$TEST_LINT_MARK_PROJECT" "$TEST_LINT_MARK_TEST_MARKER" 2>/dev/null \
    || printf '%s\n' "$TEST_LINT_MARK_PROJECT" >>"$TEST_LINT_MARK_TEST_MARKER"
fi

if [ "$TEST_LINT_MARK_IS_LINT" = "1" ]; then
  TEST_LINT_MARK_LINT_MARKER="$TEST_LINT_MARK_DIR/lint"
  grep -qxF -- "$TEST_LINT_MARK_PROJECT" "$TEST_LINT_MARK_LINT_MARKER" 2>/dev/null \
    || printf '%s\n' "$TEST_LINT_MARK_PROJECT" >>"$TEST_LINT_MARK_LINT_MARKER"
fi

exit 0
