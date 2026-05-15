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
# @@Other            :  Commands already mediated by docker/incus/podman/kubectl are exempted.
# @@Other            :  Pure POSIX / system tools (make, curl, jq, grep, git, ssh, …) are never blocked.
# @@Resource         :  ~/.claude/memory/go_conventions.md, ~/.claude/memory/rust_conventions.md
# @@Resource         :  ~/.claude/memory/tempdir_conventions.md, ~/.claude/memory/execution_hierarchy.md
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
#
# The stdout message also includes a temp-directory reminder so Claude knows
# to mount build output into a proper temp dir, not into the project tree.
__block() {
  local tool="$1"
  local docker_cmd="$2"
  local ref="$3"
  local msg
  msg="BLOCKED: direct \`${tool}\` invocation is not allowed on the host.

Run inside Docker instead:

${docker_cmd}

Temp directory reminder: any build output or test artifacts must be written
to a temp volume, never into the project tree. Use the pattern:
  \$(mktemp -d \"\${TMPDIR:-/tmp}/{project_org}/{internal_name}-XXXXXX\")
and mount it as an additional -v flag. See ~/.claude/memory/tempdir_conventions.md
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
#
# NOT blocked (pure POSIX / system / infra tools — always allowed on host):
#   make, cmake (meta-build), curl, wget, jq, yq, grep, sed, awk, find, sort,
#   git, ssh, rsync, docker, podman, incus, kubectl, helm, openssl, bash, sh,
#   python3 (as scripting tool — pip/uv/poetry are blocked separately), perl,
#   systemctl, journalctl, ps, kill, df, du, tar, zip, unzip, …
# - - - - - - - - - - - - - - - - - - - - - - - - -

case "$FIRST_BASE" in

  # ── Go ────────────────────────────────────────────────────────────────────
  go|gofmt|goimports|golangci-lint|govet|gopls|gomod|godoc)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/build \\
    -v \"\${HOME}/.cache/go-build\":/root/.cache/go-build \\
    -v \"\${HOME}/go/pkg/mod\":/go/pkg/mod \\
    -w /build \\
    -e CGO_ENABLED=0 \\
    golang:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" "~/.claude/memory/go_conventions.md"
    ;;

  # ── Rust ──────────────────────────────────────────────────────────────────
  cargo|rustc|rustup|rustfmt)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -v \"\${HOME}/.cargo/registry\":/usr/local/cargo/registry \\
    -w /workspace \\
    rust:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" "~/.claude/memory/rust_conventions.md"
    ;;

  # ── Node / JavaScript / TypeScript ───────────────────────────────────────
  node|npm|npx|yarn|pnpm|corepack)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/app \\
    -w /app \\
    node:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  bun)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/app \\
    -w /app \\
    oven/bun:alpine \\
    ${CMD}"
    __block "bun" "$DOCKER_CMD" ""
    ;;

  deno)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/app \\
    -w /app \\
    denoland/deno:alpine \\
    ${CMD}"
    __block "deno" "$DOCKER_CMD" ""
    ;;

  # ── Python — build / packaging tools ─────────────────────────────────────
  # python / python3 as a scripting tool (python3 -c '...') is legitimate and
  # NOT blocked here. Only package managers and build frontends are blocked.
  pip|pip3|pip3.[0-9]*|uv|poetry|pipenv|hatch|pdm|tox|nox|flit|twine|build|pyproject-build)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/app \\
    -w /app \\
    python:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Ruby ──────────────────────────────────────────────────────────────────
  gem|bundle|bundler|rake|rspec|rubocop)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/app \\
    -w /app \\
    ruby:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── JVM build tools (Gradle / Maven / Ant) ───────────────────────────────
  gradle|gradlew|mvn|mvnw|ant)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -v \"\${HOME}/.gradle\":/root/.gradle \\
    -v \"\${HOME}/.m2\":/root/.m2 \\
    -w /workspace \\
    gradle:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Java / JDK tools ──────────────────────────────────────────────────────
  java|javac|jar|javap|jshell|jlink|jpackage|javadoc|javaws|jmap|jstack|jinfo|jcmd|jps|jstat)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    eclipse-temurin:21-alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Kotlin ────────────────────────────────────────────────────────────────
  kotlin|kotlinc|kotlinc-jvm|kotlinc-js)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    eclipse-temurin:21-alpine \\
    sh -c 'apk add --no-cache kotlin && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Scala / SBT ───────────────────────────────────────────────────────────
  scala|scalac|scala3|scalac3|sbt)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -v \"\${HOME}/.ivy2\":/root/.ivy2 \\
    -v \"\${HOME}/.sbt\":/root/.sbt \\
    -w /workspace \\
    sbtscala/scala-sbt:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Clojure / Leiningen ───────────────────────────────────────────────────
  lein|clojure|clj|clj-kondo)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -v \"\${HOME}/.m2\":/root/.m2 \\
    -w /workspace \\
    clojure:tools-alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Groovy ────────────────────────────────────────────────────────────────
  groovy|groovyc|groovysh)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    groovy:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── PHP ───────────────────────────────────────────────────────────────────
  php|php[0-9]*|composer|phpunit|phpcs|phpmd|phpstan|psalm)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/app \\
    -w /app \\
    php:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── .NET / C# / F# ───────────────────────────────────────────────────────
  dotnet|msbuild|nuget|csc|fsc|vbc|dotnet-script)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/app \\
    -w /app \\
    mcr.microsoft.com/dotnet/sdk:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Elixir / Erlang ───────────────────────────────────────────────────────
  mix|elixir|elixirc|erl|erlc|escript|rebar3|dialyzer)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/app \\
    -w /app \\
    elixir:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Haskell ───────────────────────────────────────────────────────────────
  ghc|ghci|runghc|runhaskell|cabal|stack|haddock|hoogle)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    haskell:slim \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Swift ─────────────────────────────────────────────────────────────────
  swift|swiftc|swift-package|swift-build|swift-test|swift-run)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    swift:slim \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Dart / Flutter ────────────────────────────────────────────────────────
  dart|flutter|pub)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    dart:stable \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Zig ───────────────────────────────────────────────────────────────────
  zig)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    alpine:edge \\
    sh -c 'apk add --no-cache zig && ${CMD}'"
    __block "zig" "$DOCKER_CMD" ""
    ;;

  # ── Crystal ───────────────────────────────────────────────────────────────
  crystal|shards)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    crystallang/crystal:latest-alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── OCaml / OPAM / Dune ───────────────────────────────────────────────────
  ocaml|ocamlopt|ocamlfind|ocamlbuild|opam|dune)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    ocaml/opam:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── D language ────────────────────────────────────────────────────────────
  dmd|dub|ldc|ldc2|gdc|rdmd)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    dlangcommunity/docker-dmd:latest \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Julia ─────────────────────────────────────────────────────────────────
  julia)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -v \"\${HOME}/.julia\":/root/.julia \\
    -w /workspace \\
    julia:latest \\
    ${CMD}"
    __block "julia" "$DOCKER_CMD" ""
    ;;

  # ── R ─────────────────────────────────────────────────────────────────────
  R|Rscript|renv)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    r-base:latest \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Nim ───────────────────────────────────────────────────────────────────
  nim|nimble|nimgrep|nimpretty|testament)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    nimlang/nim:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Lua ───────────────────────────────────────────────────────────────────
  # lua itself is a common system scripting tool and is NOT blocked.
  # Only luarocks (package manager) and build tools are blocked.
  luarocks|luac)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    alpine \\
    sh -c 'apk add --no-cache lua5.4 lua5.4-dev luarocks5.4 && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── C / C++ compilers ────────────────────────────────────────────────────
  gcc|g++|cc|c++|clang|clang++|clang-[0-9]*|clang++-[0-9]*|\
  x86_64-linux-gnu-gcc|x86_64-linux-gnu-g++|\
  aarch64-linux-gnu-gcc|aarch64-linux-gnu-g++|\
  arm-linux-gnueabihf-gcc|arm-linux-gnueabihf-g++)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    alpine \\
    sh -c 'apk add --no-cache build-base && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── C / C++ build generators and configuration tools ─────────────────────
  # make is NOT blocked — it drives Docker-based builds in this project.
  # ninja is NOT blocked — analogous to make (a build runner, not a compiler).
  cmake|meson|autoconf|automake|autoreconf|configure)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    alpine \\
    sh -c 'apk add --no-cache build-base cmake && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Assembler / linker (rarely invoked directly; part of C/C++ chain) ────
  as|ld|ar|ranlib|objcopy|strip)
    DOCKER_CMD="  docker run --rm \\
    -v \"\$(pwd)\":/workspace \\
    -w /workspace \\
    alpine \\
    sh -c 'apk add --no-cache build-base binutils && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

esac

exit 0
