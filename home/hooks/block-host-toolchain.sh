#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202607031800-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  block-host-toolchain.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Wednesday, May 14, 2026 00:00 EDT
# @@File             :  block-host-toolchain.sh
# @@Description      :  Claude Code PreToolUse hook — block direct host toolchain invocations and suggest the Docker equivalent
# @@Changelog        :  Shell-aware sub-command split — join line continuations, never split inside quotes or $(), skip heredoc bodies
# @@TODO             :  None
# @@Other            :  Commands already mediated by docker/incus/podman/kubectl are exempted.
# @@Other            :  Pure POSIX / system tools (make, ninja, curl, wget, jq, grep, git, ssh, …) are never blocked.
# @@Other            :  perl and lua are NOT blocked (system scripting); only their package managers are.
# @@Other            :  python/python3 are NOT blocked (used internally and as scripting tools); only build/pkg tools are.
# @@Resource         :  ~/.claude/memory/go_conventions.md, ~/.claude/memory/rust_conventions.md
# @@Resource         :  ~/.claude/memory/tempdir_conventions.md, ~/.claude/memory/execution_hierarchy.md
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  shell/bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202607031800-git"
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
# The stdout message includes a temp-directory reminder so Claude knows to
# mount build output into a proper temp dir, never into the project tree.
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

# __split_subcommands <cmd> — print each sub-command on its own line, splitting
# on ; & && || | and newlines so container-runtime exemptions apply per
# sub-command, never to the whole compound string (a leading "docker run ..."
# must not exempt a trailing "; go build").
#
# The split is shell-aware: backslash-newline continuations are joined first,
# operators inside single/double quotes or $(...) substitutions never split
# (so `docker run ... sh -c "go vet && go build"` stays ONE sub-command and
# keeps its container-runtime exemption), and heredoc bodies are dropped so
# their content is never inspected as host commands.
__split_subcommands() {
  python3 -c '
import re, sys
SQ = chr(39)
DQ = chr(34)
cmd = sys.argv[1]
# join backslash-newline continuations into one logical line
cmd = re.sub(r"\\\n\s*", " ", cmd)
# drop heredoc bodies (<<EOF ... EOF) so their lines are not treated as sub-commands; (?<!<)(?!<) avoids matching here-strings <<<
kept = []
delim = None
for line in cmd.split("\n"):
    if delim is not None:
        if line.strip() == delim:
            delim = None
        continue
    m = re.search(r"(?<!<)<<(?!<)-?\s*[\x27\x22]?([A-Za-z_][A-Za-z0-9_]*)", line)
    if m:
        delim = m.group(1)
    kept.append(line)
cmd = "\n".join(kept)
# quote- and $()-aware operator scan
subs = []
buf = []
quote = None
depth = 0
i = 0
n = len(cmd)
while i < n:
    c = cmd[i]
    if quote is not None:
        if quote == DQ and c == "\\" and i + 1 < n:
            buf.append(cmd[i:i + 2])
            i += 2
            continue
        if c == quote:
            quote = None
        buf.append(c)
        i += 1
        continue
    if c == SQ or c == DQ:
        quote = c
        buf.append(c)
        i += 1
        continue
    if c == "\\" and i + 1 < n:
        buf.append(cmd[i:i + 2])
        i += 2
        continue
    if cmd.startswith("$(", i):
        depth += 1
        buf.append("$(")
        i += 2
        continue
    if depth > 0 and c == "(":
        depth += 1
        buf.append(c)
        i += 1
        continue
    if depth > 0 and c == ")":
        depth -= 1
        buf.append(c)
        i += 1
        continue
    if depth == 0 and c in ";&|\n":
        subs.append("".join(buf))
        buf = []
        i += 1
        while i < n and cmd[i] in ";&|":
            i += 1
        continue
    buf.append(c)
    i += 1
subs.append("".join(buf))
for sub in subs:
    sub = sub.strip()
    if sub:
        print(sub)
' "$1"
}

INPUT="$(cat)"
FULL_CMD="$(printf '%s' "$INPUT" | __extract_command)"
[[ -z "$FULL_CMD" ]] && exit 0

# Inspect every sub-command independently; __block exits 2 on the first violation
while IFS= read -r CMD; do

# Sub-commands already mediated by a container runtime are exempt at this layer.
case "$CMD" in
  docker\ exec\ *|docker\ run\ *|docker\ compose\ exec\ *|docker\ compose\ run\ *|\
  docker-compose\ exec\ *|docker-compose\ run\ *|\
  incus\ exec\ *|incus\ shell\ *|lxc\ exec\ *|\
  podman\ exec\ *|podman\ run\ *|\
  kubectl\ exec\ *)
    continue
    ;;
esac

FIRST="$(__first_word "$CMD")"
[[ -z "$FIRST" ]] && continue

# Normalise: strip any leading path component so /usr/local/go/bin/go → go
FIRST_BASE="${FIRST##*/}"

# - - - - - - - - - - - - - - - - - - - - - - - - -
# Toolchain dispatch
#
# Image selection: prefer :alpine; fall back to :debian or :latest when no
# Alpine variant exists. Never pin a specific version number.
#
# NOT blocked (pure POSIX / system / infra tools — always allowed on host):
#   make, ninja, curl, wget, jq, yq, grep, sed, awk, find, sort, git, ssh,
#   rsync, docker, podman, incus, kubectl, helm, openssl, bash, sh,
#   python / python3 (scripting; pip/uv/poetry etc. are blocked separately),
#   perl / lua (system scripting; cpan/luarocks are blocked separately),
#   systemctl, journalctl, ps, kill, df, du, tar, zip, unzip, …
# - - - - - - - - - - - - - - - - - - - - - - - - -

case "$FIRST_BASE" in

  # ── Go ────────────────────────────────────────────────────────────────────
  go|gofmt|goimports|golangci-lint|gopls|godoc)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/build \\
    -v \"\${GOCACHE:-\${HOME}/.cache/go-build}\":/root/.cache/go-build \\
    -v \"\${GOMODCACHE:-\${GOPATH:-\${HOME}/go}/pkg/mod}\":/go/pkg/mod \\
    -w /build \\
    -e CGO_ENABLED=0 \\
    -e GOFLAGS=-buildvcs=false \\
    casjaysdev/go:latest \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" "~/.claude/memory/go_conventions.md"
    ;;

  # ── Rust ──────────────────────────────────────────────────────────────────
  cargo|rustc|rustup|rustfmt|wasm-pack)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -v \"\${CARGO_HOME:-\${HOME}/.cargo}/registry\":/usr/local/cargo/registry \\
    -v \"\${CARGO_HOME:-\${HOME}/.cargo}/git\":/usr/local/cargo/git \\
    -w /workspace \\
    casjaysdev/rust:latest \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" "~/.claude/memory/rust_conventions.md"
    ;;

  # ── Node / JavaScript / TypeScript runtime & package managers ─────────────
  node|npm|npx|yarn|pnpm|corepack)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/app \\
    -w /app \\
    node:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── TypeScript compiler and JS build / lint tools ─────────────────────────
  # All run inside node:alpine; most are installed via npx or project deps.
  tsc|ts-node|tsx|ts-blank|babel|webpack|rollup|vite|parcel|esbuild|\
  turbo|turborepo|eslint|prettier|biome|oxlint|jshint|standard|xo|\
  swc|tsup|unbuild|pkgroll)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/app \\
    -w /app \\
    node:alpine \\
    sh -c 'npm install --prefer-offline && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Alt JS runtimes ───────────────────────────────────────────────────────
  bun)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/app \\
    -w /app \\
    oven/bun:alpine \\
    ${CMD}"
    __block "bun" "$DOCKER_CMD" ""
    ;;

  deno)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/app \\
    -w /app \\
    denoland/deno:alpine \\
    ${CMD}"
    __block "deno" "$DOCKER_CMD" ""
    ;;

  # ── Compile-to-JS / JS-ecosystem languages ────────────────────────────────
  # Elm, PureScript, ReScript, CoffeeScript, AssemblyScript — all installed
  # via npm; use node:alpine and install the toolchain inside the container.
  elm|spago|purs|rescript|coffee|asc)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/app \\
    -w /app \\
    node:alpine \\
    sh -c 'npm install --prefer-offline && npx ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Python — build / packaging tools ─────────────────────────────────────
  # python / python3 themselves are NOT blocked (scripting use is legitimate
  # and this hook uses python3 internally). Only package managers and build
  # frontends are blocked.
  pip|pip3|pip3.[0-9]*|uv|poetry|pipenv|hatch|pdm|tox|nox|flit|twine|\
  pyproject-build|setuptools|conda|mamba|micromamba)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/app \\
    -w /app \\
    python:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Ruby ──────────────────────────────────────────────────────────────────
  gem|bundle|bundler|rake|rspec|rubocop|standardrb|sorbet|srb)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/app \\
    -w /app \\
    ruby:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── JVM build tools (Gradle / Maven / Ant) ───────────────────────────────
  gradle|gradlew|mvn|mvnw|ant)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -v \"\${HOME}/.gradle\":/root/.gradle \\
    -v \"\${HOME}/.m2\":/root/.m2 \\
    -w /workspace \\
    gradle:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Java / JDK tools ──────────────────────────────────────────────────────
  java|javac|jar|javap|jshell|jlink|jpackage|javadoc|javaws|\
  jmap|jstack|jinfo|jcmd|jps|jstat|jfr|jdb)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    eclipse-temurin:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── GraalVM native-image ──────────────────────────────────────────────────
  native-image|gu)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    ghcr.io/graalvm/native-image:latest \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Kotlin ────────────────────────────────────────────────────────────────
  kotlin|kotlinc|kotlinc-jvm|kotlinc-js)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    eclipse-temurin:alpine \\
    sh -c 'apk add --no-cache kotlin && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Scala / SBT ───────────────────────────────────────────────────────────
  scala|scalac|scala3|scalac3|sbt)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -v \"\${HOME}/.ivy2\":/root/.ivy2 \\
    -v \"\${HOME}/.sbt\":/root/.sbt \\
    -w /workspace \\
    eclipse-temurin:alpine \\
    sh -c 'apk add --no-cache scala && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Clojure / Leiningen ───────────────────────────────────────────────────
  lein|clojure|clj|clj-kondo)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -v \"\${HOME}/.m2\":/root/.m2 \\
    -w /workspace \\
    clojure:tools-alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Groovy ────────────────────────────────────────────────────────────────
  groovy|groovyc|groovysh)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    groovy:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── PHP ───────────────────────────────────────────────────────────────────
  php|php[0-9]*|composer|phpunit|phpcs|phpmd|phpstan|psalm|phpbrew|phive)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/app \\
    -w /app \\
    php:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── .NET / C# / F# / VB ──────────────────────────────────────────────────
  dotnet|msbuild|nuget|csc|fsc|vbc|dotnet-script|dotnet-ef)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/app \\
    -w /app \\
    mcr.microsoft.com/dotnet/sdk:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Elixir / Erlang ───────────────────────────────────────────────────────
  mix|elixir|elixirc|erl|erlc|escript|rebar3|dialyzer)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/app \\
    -w /app \\
    elixir:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Gleam (BEAM / Erlang VM language) ────────────────────────────────────
  gleam)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/app \\
    -w /app \\
    ghcr.io/gleam-lang/gleam:latest \\
    ${CMD}"
    __block "gleam" "$DOCKER_CMD" ""
    ;;

  # ── Haskell ───────────────────────────────────────────────────────────────
  # No official Alpine image — uses Debian-based :latest.
  ghc|ghci|runghc|runhaskell|cabal|stack|haddock|hoogle)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    haskell:latest \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Swift ─────────────────────────────────────────────────────────────────
  # No official Alpine image — uses Ubuntu-based :latest.
  swift|swiftc|swift-package|swift-build|swift-test|swift-run)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    swift:latest \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Dart / Flutter ────────────────────────────────────────────────────────
  # No official Alpine image — uses Debian-based :latest.
  dart|flutter|pub)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    dart:latest \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Zig ───────────────────────────────────────────────────────────────────
  # Zig is in Alpine edge; no separate official Docker image.
  zig)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    alpine:edge \\
    sh -c 'apk add --no-cache zig && ${CMD}'"
    __block "zig" "$DOCKER_CMD" ""
    ;;

  # ── Crystal ───────────────────────────────────────────────────────────────
  crystal|shards)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    crystallang/crystal:latest-alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── OCaml / OPAM / Dune ───────────────────────────────────────────────────
  ocaml|ocamlopt|ocamlfind|ocamlbuild|opam|dune)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    ocaml/opam:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── D language ────────────────────────────────────────────────────────────
  dmd|dub|ldc|ldc2|gdc|rdmd)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    dlangcommunity/docker-dmd:latest \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Julia ─────────────────────────────────────────────────────────────────
  # No official Alpine image — uses Debian-based :latest.
  julia)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -v \"\${HOME}/.julia\":/root/.julia \\
    -w /workspace \\
    julia:latest \\
    ${CMD}"
    __block "julia" "$DOCKER_CMD" ""
    ;;

  # ── R ─────────────────────────────────────────────────────────────────────
  # No official Alpine image — uses Debian-based :latest.
  R|Rscript|renv)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    r-base:latest \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Nim ───────────────────────────────────────────────────────────────────
  nim|nimble|nimgrep|nimpretty|testament)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    nimlang/nim:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── V language ────────────────────────────────────────────────────────────
  # Bare "v" is not blocked — it collides with a common shell alias name.
  vpm)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    vlang/vlang:latest \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Odin ──────────────────────────────────────────────────────────────────
  # No official Docker image — install from GitHub release inside Ubuntu.
  odin)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    ubuntu:latest \\
    sh -c 'apt-get update && apt-get install -y odin && ${CMD}'"
    __block "odin" "$DOCKER_CMD" ""
    ;;

  # ── Lua — package manager / compiler only ────────────────────────────────
  # lua itself is a common system scripting tool and is NOT blocked.
  luarocks|luac)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    alpine \\
    sh -c 'apk add --no-cache lua5.4 lua5.4-dev luarocks5.4 && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Janet (small Lisp/C hybrid, in Alpine repos) ─────────────────────────
  janet|jpm)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    alpine:latest \\
    sh -c 'apk add --no-cache janet && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Fennel (Lisp dialect for Lua, in Alpine repos) ───────────────────────
  fennel)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    alpine:latest \\
    sh -c 'apk add --no-cache lua5.4 fennel && ${CMD}'"
    __block "fennel" "$DOCKER_CMD" ""
    ;;

  # ── Perl — package managers / build tools only ───────────────────────────
  # perl itself is a system scripting tool and is NOT blocked.
  cpan|cpanm|cpm|carton|prove|plackup|morbo)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/app \\
    -w /app \\
    perl:alpine \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Fortran ───────────────────────────────────────────────────────────────
  gfortran|flang|ifort|ifx|f77|f95|fort77)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    alpine \\
    sh -c 'apk add --no-cache gfortran && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── COBOL ─────────────────────────────────────────────────────────────────
  cobc|cobcrun|cob-config)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    alpine \\
    sh -c 'apk add --no-cache gnucobol && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Ada / GNAT ────────────────────────────────────────────────────────────
  gnat|gnatmake|gprbuild|gnatclean|gnatbind|gnatlink|gnatfind|gnatxref)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    alpine \\
    sh -c 'apk add --no-cache gcc-gnat gnat && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Emscripten — C / C++ to WebAssembly ──────────────────────────────────
  emcc|em++|emcmake|emmake|emar|emranlib|emstrip|emrun|emdump|emsize)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    emscripten/emsdk:latest \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Common Lisp ───────────────────────────────────────────────────────────
  # No Alpine image; use Debian-based :latest.
  sbcl|clisp|ecl|abcl|gcl|ccl|acl)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    debian:latest \\
    sh -c 'apt-get update && apt-get install -y sbcl && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Racket ────────────────────────────────────────────────────────────────
  # No Alpine image; official image is Debian-based.
  racket|raco)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    racket/racket:latest \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Scheme (Guile, Chicken, MIT, Chibi) ──────────────────────────────────
  # No Alpine image for most; use Debian-based :latest.
  # Note: csi = Chicken Scheme Interpreter (csc conflicts with C# compiler).
  guile|chicken|chicken-install|chicken-status|csi|\
  mit-scheme|chibi-scheme|chezscheme|chez|petite-chez)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    debian:latest \\
    sh -c 'apt-get update && apt-get install -y guile-3.0 && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Prolog ────────────────────────────────────────────────────────────────
  # No Alpine image; official SWI-Prolog image is Debian-based.
  swipl|swipl-ld|gprolog|yap|xsb|clingo|spass)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    swipl:latest \\
    ${CMD}"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Bazel / Bazelisk ──────────────────────────────────────────────────────
  bazel|bazelisk|ibazel)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -v \"\${HOME}/.cache/bazel\":/root/.cache/bazel \\
    -w /workspace \\
    ubuntu:latest \\
    sh -c 'apt-get update && apt-get install -y bazel && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── C / C++ compilers ────────────────────────────────────────────────────
  gcc|g++|cc|c++|clang|clang++|clang-[0-9]*|clang++-[0-9]*|\
  x86_64-linux-gnu-gcc|x86_64-linux-gnu-g++|\
  aarch64-linux-gnu-gcc|aarch64-linux-gnu-g++|\
  arm-linux-gnueabihf-gcc|arm-linux-gnueabihf-g++|\
  riscv64-linux-gnu-gcc|riscv64-linux-gnu-g++)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    alpine \\
    sh -c 'apk add --no-cache build-base && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── C / C++ build generators and configuration tools ─────────────────────
  # make and ninja are NOT blocked — they act as build runners, not compilers,
  # and make drives Docker-based builds in this project.
  cmake|meson|autoconf|automake|autoreconf|configure)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    alpine \\
    sh -c 'apk add --no-cache build-base cmake && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

  # ── Assembler / linker (part of C/C++ toolchain) ─────────────────────────
  # strip is not blocked — settings.json allowlists it and it is used on non-C artifacts.
  as|ld|ar|ranlib|objcopy)
    DOCKER_CMD="  docker run --rm \\
    --name \"\$(basename \"\$PWD\")-\$(tr -dc 'a-z0-9' </dev/urandom | head -c8)\" \\
    -v \"\$PWD\":/workspace \\
    -w /workspace \\
    alpine \\
    sh -c 'apk add --no-cache build-base binutils && ${CMD}'"
    __block "$FIRST_BASE" "$DOCKER_CMD" ""
    ;;

esac

done < <(__split_subcommands "$FULL_CMD")

exit 0
