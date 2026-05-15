#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  YYYYMMDDHHMM-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  block-host-toolchain.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Wednesday, May 14, 2026 00:00 EDT
# @@File             :  block-host-toolchain.sh
# @@Description      :  Claude Code PreToolUse hook — block direct host toolchain invocations and suggest the Docker equivalent
# @@Changelog        :  Initial version
# @@TODO             :  None
# @@Other            :  Commands already mediated by docker/incus/podman/kubectl are exempted
# @@Resource         :  ~/.claude/memory/go_conventions.md, ~/.claude/memory/rust_conventions.md
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="YYYYMMDDHHMM-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -uo pipefail
# - - - - - - - - - - - - - - - - - - - - - - - - -

# __require_cmd <name> — bail with a clear error if a required tool is missing.
# A broken hook must exit 0 (no-op) to avoid silently blocking every Bash call.
__require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'block-host-toolchain.sh: required command not found: %s\n' "$1" >&2
    exit 0
  fi
}

# __extract_command — read the JSON payload on stdin, return tool_input.command.
__extract_command() {
  python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("tool_input", {}).get("command", ""))
except Exception:
    print("")
'
}

# __first_word <cmd> — strip leading KEY=VALUE env assignments and return the
# first executable token. Handles patterns like: CGO_ENABLED=0 go build ./...
__first_word() {
  python3 -c '
import re, sys
cmd = sys.argv[1].strip()
# strip leading VAR=value assignments (quoted or unquoted values)
cmd = re.sub(r"^(?:[A-Za-z_][A-Za-z0-9_]*=(?:\"[^\"]*\"|'"'"'[^'"'"']*'"'"'|[^\s]*)\s+)*", "", cmd)
parts = cmd.split()
print(parts[0] if parts else "")
' "$1"
}

# __block <tool> <docker_cmd> <convention_ref>
# Emits the block message to BOTH stdout (Claude Code reads this as the block
# reason and feeds it back to Claude) and stderr (visible to the user in the
# terminal), then exits 2 to block the tool call.
__block() {
  local tool="$1"
  local docker_cmd="$2"
  local ref="$3"
  local msg
  msg="BLOCKED: direct \`${tool}\` invocation is not allowed on the host.

Run inside Docker instead:

${docker_cmd}
"
  if [[ -n "$ref" ]]; then
    msg="${msg}
Convention: ${ref}"
  fi
  # stdout → Claude Code (block reason returned to Claude as context)
  printf '%s\n' "$msg"
  # stderr → user terminal
  printf '%s\n' "$msg" >&2
  exit 2
}

# - - - - - - - - - - - - - - - - - - - - - - - - -
__require_cmd python3
# - - - - - - - - - - - - - - - - - - - - - - - - -

INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | __extract_command)"
[[ -z "$CMD" ]] && exit 0

# Commands already mediated by a container runtime are exempt at this layer.
case "$CMD" in
  docker\ exec\ *|docker\ run\ *|docker\ compose\ exec\ *|docker\ compose\ run\ *|\
  docker-compose\ exec\ *|docker-compose\ run\ *|\
  incus\ exec\ *|incus\ shell\ *|lxc\ exec\ *|\
  podman\ exec\ *|podman\ run\ *|\
  kubectl\ exec\ *)
    exit 0
    ;;
esac

FIRST="$(__first_word "$CMD")"
[[ -z "$FIRST" ]] && exit 0

# Normalise: strip any leading path component so /usr/local/go/bin/go → go
FIRST_BASE="${FIRST##*/}"

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Toolchain dispatch
# - - - - - - - - - - - - - - - - - - - - - - - - -

case "$FIRST_BASE" in

  # ── Go ────────────────────────────────────────────────────────────────────
  go)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/build \\
    -v \"\${HOME}/.cache/go-build\":/root/.cache/go-build \\
    -v \"\${HOME}/go/pkg/mod\":/go/pkg/mod \\
    -w /build \\
    -e CGO_ENABLED=0 \\
    golang:alpine \\
    ${CMD}"
    __block "go" "$DOCKER_CMD" "~/.claude/memory/go_conventions.md"
    ;;

  # ── Rust ──────────────────────────────────────────────────────────────────
  cargo|rustc|rustup)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    rust:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" "~/.claude/memory/rust_conventions.md"
    ;;

  # ── Node / JavaScript ─────────────────────────────────────────────────────
  node|npm|npx|yarn|pnpm|corepack)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/app \\
    -w /app \\
    node:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Python (as build tool — pip installs, package builds, etc.) ───────────
  # Note: python3 invoked as a scripting tool (e.g. python3 -c '...') is
  # common and legitimate; only block when it looks like a build/package op.
  pip|pip3|uv)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/app \\
    -w /app \\
    python:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Ruby ──────────────────────────────────────────────────────────────────
  gem|bundle|bundler)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/app \\
    -w /app \\
    ruby:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── JVM (Gradle / Maven) ──────────────────────────────────────────────────
  gradle|gradlew|./gradlew|mvn|mvnw|./mvnw)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    gradle:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

esac

exit 0
