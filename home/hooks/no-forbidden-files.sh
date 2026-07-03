#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202607031500-git
# @@Author           :  Jason Hempstead
# @@Contact          :  git-admin@casjaysdev.pro
# @@License          :  MIT or LICENSE.md
# @@ReadME           :  no-forbidden-files.sh --help
# @@Copyright        :  Copyright: (c) 2026 Jason Hempstead, Casjays Developments
# @@Created          :  Thursday, May 15, 2026 00:00 EDT
# @@File             :  no-forbidden-files.sh
# @@Description      :  PreToolUse hook: confirm before writing normally-forbidden files
# @@Changelog        :  Deny wins over allow, case-insensitive basename/extension checks, python3 fail-open guard
# @@TODO             :  Better docs
# @@Other            :
# @@Resource         :
# - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1001,SC1003,SC2001,SC2003,SC2016,SC2031,SC2090,SC2115,SC2120,SC2155,SC2199,SC2229,SC2317,SC2329
# - - - - - - - - - - - - - - - - - - - - - - - - -
VERSION="202607031500-git"
# - - - - - - - - - - - - - - - - - - - - - - - - -
set -euo pipefail

INPUT="$(cat)"

# Fail-open if python3 is missing — a broken hook exits 0 (no-op) so we never silently block every Write/Edit call.
if ! command -v python3 >/dev/null 2>&1; then
  printf 'no-forbidden-files.sh: required command not found: python3\n' >&2
  exit 0
fi

HOOK_INPUT="$INPUT" python3 - <<'PYEOF'
import json
import os
import re
import sys

raw = os.environ.get("HOOK_INPUT", "")
try:
    payload = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(0)

tool = payload.get("tool_name", "")
tool_input = payload.get("tool_input", {})

if tool in ("Write", "Edit"):
    file_path = tool_input.get("file_path", "")
else:
    sys.exit(0)

if not file_path:
    sys.exit(0)

basename = os.path.basename(file_path)
norm_path = file_path.replace("\\", "/")

# ------------------------------------------------------------------
# ALLOWLIST — toolchain-required files that are never blocked
# ------------------------------------------------------------------
ALWAYS_ALLOW_BASENAMES = {
    # Make / Autotools
    "Makefile", "GNUmakefile", "makefile",
    "Makefile.am", "Makefile.in", "Makefile.dist",
    "configure.ac", "configure.in", "configure",
    "autogen.sh", "bootstrap.sh", "autoclean.sh",
    "aclocal.m4", "config.h.in",
    # CMake
    "CMakeLists.txt", "CMakeCache.txt",
    # Go
    "go.mod", "go.sum", "go.work", "go.work.sum",
    # Rust
    "Cargo.toml", "Cargo.lock",
    # Node / JS / TS
    "package.json", "package-lock.json",
    "yarn.lock", "yarn.config.js", "yarn.config.cjs",
    "bun.lockb", "bun.lock",
    "pnpm-lock.yaml", "pnpm-workspace.yaml",
    "tsconfig.json", "tsconfig.base.json", "tsconfig.node.json",
    "jsconfig.json",
    "webpack.config.js", "webpack.config.ts",
    "vite.config.js", "vite.config.ts",
    "rollup.config.js", "rollup.config.ts", "rollup.config.mjs",
    "babel.config.js", "babel.config.json", "babel.config.ts",
    ".babelrc", ".babelrc.js", ".babelrc.json",
    "jest.config.js", "jest.config.ts", "jest.config.json",
    "vitest.config.js", "vitest.config.ts",
    ".eslintrc", ".eslintrc.js", ".eslintrc.json", ".eslintrc.yaml", ".eslintrc.yml",
    "eslint.config.js", "eslint.config.ts", "eslint.config.mjs",
    ".prettierrc", ".prettierrc.js", ".prettierrc.json",
    "prettier.config.js", "prettier.config.ts",
    "biome.json",
    "deno.json", "deno.jsonc", "deno.lock",
    # Python
    "pyproject.toml", "setup.py", "setup.cfg",
    "requirements.txt", "requirements-dev.txt", "requirements-test.txt",
    "Pipfile", "Pipfile.lock",
    "poetry.lock",
    "tox.ini", "noxfile.py",
    "MANIFEST.in",
    ".flake8", ".pylintrc", "mypy.ini",
    "pyrightconfig.json",
    # Ruby
    "Gemfile", "Gemfile.lock", "Rakefile",
    # Java / Maven / Gradle
    "pom.xml",
    "build.gradle", "build.gradle.kts",
    "settings.gradle", "settings.gradle.kts",
    "gradle.properties", "gradlew", "gradlew.bat",
    # Bazel
    "BUILD", "BUILD.bazel", "WORKSPACE", "WORKSPACE.bazel",
    "WORKSPACE.bzlmod", "MODULE.bazel",
    ".bazelrc", ".bazelignore", ".bazelversion",
    # Zig
    "build.zig", "build.zig.zon",
    # D / DUB
    "dub.json", "dub.sdl",
    # Elixir / Erlang
    "mix.exs", "mix.lock", "rebar.config", "rebar.lock",
    # PHP
    "composer.json", "composer.lock",
    ".php-cs-fixer.php", ".php-cs-fixer.dist.php",
    "phpunit.xml", "phpunit.xml.dist",
    "phpstan.neon", "phpstan.dist.neon",
    # .NET / C#
    "global.json", "NuGet.Config", "nuget.config",
    "Directory.Build.props", "Directory.Build.targets",
    # Haskell
    "stack.yaml", "stack.yaml.lock", "cabal.project", "cabal.project.freeze",
    # Swift
    "Package.swift", "Package.resolved",
    # Dart / Flutter
    "pubspec.yaml", "pubspec.lock", "analysis_options.yaml",
    # OCaml
    "dune", "dune-project", "dune-workspace",
    # Scala / sbt
    "build.sbt",
    # Clojure
    "project.clj", "deps.edn", "bb.edn",
    # Crystal
    "shard.yml", "shard.lock",
    # Julia
    "Project.toml", "Manifest.toml",
    # Docker / Container
    "Dockerfile", "Containerfile",
    "docker-compose.yml", "docker-compose.yaml",
    "docker-compose.override.yml", "docker-compose.override.yaml",
    ".dockerignore",
    # CI / CD
    ".travis.yml", "Jenkinsfile",
    "appveyor.yml",
    # Tooling dot-configs
    ".gitignore", ".gitattributes", ".gitmodules",
    ".editorconfig",
    ".env.example", ".env.sample", ".env.template",
    # Nix
    "flake.nix", "flake.lock", "default.nix", "shell.nix",
    # Docs (project-standard names)
    # CHANGELOG.md / CHANGES.md are explicitly allowed at any path (root or .github/).
    "CHANGELOG.md", "CHANGELOG.txt", "CHANGES.md", "CHANGES.txt",
    # CONTRIBUTING / CODE_OF_CONDUCT / SECURITY / PULL_REQUEST_TEMPLATE
    # are only auto-allowed when nested under .github/ (or other dotfile dirs
    # in ALWAYS_ALLOW_PATH_PATTERNS). At repo root they fall through to the
    # confirmation prompt below.
    "AUTHORS", "AUTHORS.md", "CONTRIBUTORS", "CONTRIBUTORS.md",
    "NOTICE", "NOTICE.md", "NOTICE.txt",
    "LICENSE", "LICENSE.md", "LICENSE.txt", "COPYING",
    # Misc project root files
    "VERSION", "VERSION.txt", "version.txt",
    ".npmignore", ".npmrc", ".nvmrc", ".node-version",
    ".ruby-version", ".python-version", ".tool-versions",
    ".golangci.yml", ".golangci.yaml",
    # Nim
    "config.nims",
    # R package
    "DESCRIPTION",
    # R package
    "NAMESPACE",
}

ALWAYS_ALLOW_EXTENSIONS = {
    # Protocol Buffers
    ".proto",
    # Thrift
    ".thrift",
    # Avro schema
    ".avsc",
    # Cap'n Proto
    ".capnp",
    # FlatBuffers
    ".fbs",
    # Nim package manifest
    ".nimble",
    # Haskell Cabal
    ".cabal",
    # OCaml OPAM
    ".opam",
    # Ruby gemspec
    ".gemspec",
    # CocoaPods
    ".podspec",
    # LuaRocks
    ".rockspec",
    # Terraform
    ".tf",
    # Terraform vars
    ".tfvars",
    # HCL config
    ".hcl",
    # Solidity
    ".sol",
    # Vyper
    ".vy",
}

ALWAYS_ALLOW_PATH_PATTERNS = [
    r"\.github/",
    r"\.circleci/",
    r"\.cargo/",
    r"/gradle/wrapper/",
    r"/\.mvn/",
    r"/vendor/",
    r"/node_modules/",
    r"/__pycache__/",
    r"/\.git/",
]

def is_allowed(fp, bn):
    if bn in ALWAYS_ALLOW_BASENAMES:
        return True
    _, ext = os.path.splitext(bn)
    if ext in ALWAYS_ALLOW_EXTENSIONS:
        return True
    for pat in ALWAYS_ALLOW_PATH_PATTERNS:
        if re.search(pat, fp):
            return True
    return False

# ------------------------------------------------------------------
# FORBIDDEN FILE PATTERNS — prompt confirmation before writing
# Deny wins over allow: these checks run BEFORE the allowlist so that
# credential files under allowlisted paths (.github/, vendor/, ...) still block.
# Patterns are split across variables to avoid triggering other hooks
# when this script itself is written.
# ------------------------------------------------------------------

# All entries lowercase — compared case-insensitively against basename.lower().
FORBIDDEN_BASENAMES = {
    ".netrc",
    "credentials.json", "service-account.json", "service_account.json",
    "secrets.json", "secrets.yaml", "secrets.yml",
    "id_rsa", "id_ed25519", "id_ecdsa", "id_dsa",
    "id_rsa.pub", "id_ed25519.pub",
    ".ds_store", "thumbs.db", "desktop.ini",
}

# Doc files allowed under .github/ (auto-allowlisted by path pattern) but
# requiring confirmation at repo root or anywhere else.
# All entries lowercase — compared case-insensitively against basename.lower().
LOCATION_RESTRICTED_BASENAMES = {
    "contributing.md", "code_of_conduct.md",
    "security.md", "pull_request_template.md",
}

FORBIDDEN_EXTENSIONS = {
    # private keys / certificates
    ".pem",
    # private key (generic)
    ".key",
    # PKCS#12 bundle
    ".p12",
    # PFX bundle
    ".pfx",
    # Java KeyStore
    ".jks",
    # Apple private key
    ".p8",
    # PuTTY private key
    ".ppk",
}

# Patterns split to avoid triggering sibling hooks on this file itself
_ca = "co-authored-by"
_ai_tools = ["claude", "copilot", "chatgpt", "gpt"]
FORBIDDEN_PATH_PATTERNS = [
    (_ca + r".*(" + "|".join(_ai_tools) + r")", "AI attribution trailer in path"),
    (r"generated (with|by) (" + "|".join(_ai_tools) + r"|openai|anthropic)", "AI attribution phrase in path"),
    (r"/\.aws/credentials", "AWS credential file"),
    (r"/\.aws/config", "AWS config file"),
    (r"/\.ssh/id_", "SSH private key"),
]

def is_forbidden(fp, bn):
    # Basename and extension checks are case-insensitive (ID_RSA, cert.PEM, Secrets.json).
    bn_lower = bn.lower()
    if bn_lower in FORBIDDEN_BASENAMES:
        return bn, "credential/secrets/OS-detritus file"
    _, ext = os.path.splitext(bn_lower)
    if ext in FORBIDDEN_EXTENSIONS:
        return bn, "private key or certificate file"
    fp_lower = fp.lower()
    for pat, label in FORBIDDEN_PATH_PATTERNS:
        if re.search(pat, fp_lower):
            return fp, label
    return None, None

matched_name, reason = is_forbidden(norm_path, basename)

# Allowlist only rescues files NOT forbidden by name/extension/path — deny wins over allow.
if matched_name is None and is_allowed(norm_path, basename):
    sys.exit(0)

# Location-restricted docs under allowlisted paths were rescued above; anywhere else they need confirmation.
if matched_name is None and basename.lower() in LOCATION_RESTRICTED_BASENAMES:
    matched_name, reason = basename, "doc file only auto-allowed under .github/"

if matched_name is None:
    sys.exit(0)

msg = (
    f"CONFIRM REQUIRED before writing: {file_path}\n\n"
    f"Reason: matches forbidden-file pattern — {reason}\n\n"
    "Per project conventions this file should not be created without explicit user approval.\n\n"
    "Please ask the user:\n"
    f'  "I\'m about to write \'{file_path}\' which matches a forbidden-file pattern ({reason}).\n'
    '   Do you want me to proceed, or should I use a different path/approach?"\n\n'
    "Only proceed if the user explicitly says yes."
)

print(msg)
sys.stderr.write(msg + "\n")
sys.exit(2)
PYEOF
