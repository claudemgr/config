---
name: Makefile conventions
description: Universal Makefile patterns shared across all CasjaysDev project types and languages
type: user
---

## Core Rules

- **`.PHONY` is mandatory** — declare every non-file target; prevents collision with files of the same name
- **Never hardcode `PROJECTNAME` or `PROJECTORG`** — always infer from git remote
- **`VERSION` from `release.txt`** — never hardcode; see `~/.claude/memory/version_conventions.md`
- **`@` prefix suppresses echo** — every recipe line that is not intentional debug output uses `@`
- **`help` is always the first target** — `make` alone prints the help screen
- **Local only — no outbound writes** — the Makefile is a local developer tool; it must never push, publish, or write to any remote system. Specifically forbidden in any Makefile target: `docker push`, `docker buildx ... --push`, `git commit`, `git push`, `git tag`, `npm publish`, `cargo publish`, `gh release`, `glab release`, or any equivalent. `docker pull` is allowed — fetching images and dependencies (remote → local) is fine; sending artifacts or commits outward (local → remote) is not.

---

## Standard Variables (All Languages)

```makefile
# Infer from git remote — NEVER hardcode org or project name
PROJECTNAME := $(shell git remote get-url origin 2>/dev/null | \
    sed -E 's|.*/([^/]+)(\.git)?$$|\1|' || basename "$$(pwd)")
PROJECTORG  := $(shell git remote get-url origin 2>/dev/null | \
    sed -E 's|.*/([^/]+)/[^/]+(\.git)?$$|\1|' || \
    basename "$$(dirname "$$(pwd)")")

VERSION    ?= $(shell cat release.txt 2>/dev/null || echo "devel")
BUILD_DATE := $(shell date +"%a %b %d, %Y at %H:%M:%S %Z")
COMMIT_ID  := $(shell git rev-parse --short HEAD 2>/dev/null || echo "N/A")
PLATFORMS  ?= linux/amd64,linux/arm64
```

Use `:=` (immediate) for shell-computed values — evaluated once at parse time.
Use `?=` for overridable variables — allows `make build VERSION=1.2.3-rc1` or `make docker PLATFORMS=linux/amd64`.
Never use `=` (recursive) for computed values — causes repeated shell invocations on every reference.

---

## Standard Target Names

All projects define these targets (when applicable). All are `.PHONY`.

| Target | Description |
|--------|-------------|
| `help` | Print target list and current version — **always first** |
| `build` | Compile/package into `binaries/` or `dist/` |
| `test` | Lint + vet + test suite |
| `dev` | Quick single-platform build into a temp dir for local testing |
| `lint` | Linter/formatter check only (no test suite) |
| `docker` | Build multi-arch Docker image locally (no push) |
| `release` | Prepare release archives in `releases/` |
| `clean` | Remove build output — never source, `.git`, or base images |

---

## `.PHONY` Declaration

```makefile
.PHONY: help build test dev lint docker release clean
```

Declare all non-file targets together near the top of the Makefile (or immediately before each target group).

---

## `help` Target Pattern

```makefile
.PHONY: help
help: ## Show this help message
	@printf '\n\033[1;37m  %s v%s\033[0m\n\n' "$(PROJECTNAME)" "$(VERSION)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@printf '\n'
```

Targets self-document with `## description` inline comments. The `help` target greps for them automatically — no manual maintenance.

---

## Recipe Rules

- `@` prefix on every recipe line that does not need to be echoed
- Multi-line recipes: use `\` continuation with tab-indented continuation lines
- Use `$(MAKE)` not `make` when recursing — preserves `-j`, `-n`, and other flags
- Chain with `&&` not `;` when subsequent steps must not run after a failure
- Temp files created in recipes: use `mktemp` and clean up in the same recipe block

---

## Variable Hygiene

| Assignment | When to use |
|-----------|-------------|
| `:=` | Shell-computed or string values — evaluated once at parse time |
| `?=` | User-overridable values — `VERSION ?= ...`, `PORT ?= 8080` |
| `=` | Only for values that must re-expand on each use (rare) |

Never put `$(shell ...)` inside a recipe — use variables defined outside recipes so evaluation happens once.

Never `export` Makefile variables globally — pass them explicitly to Docker containers with `-e VAR=$(VAR)`.

---

## Docker Run Pattern

All build-time tool invocations run inside Docker — language files define the specific image and mounts:

```makefile
# Shared pattern — each language substitutes its own image, cache vars, and mounts
CACHE_DIR ?= $(HOME)/.cache/{lang}   # ?= honors host env var override

LANG_DOCKER := docker run --rm -it \
    --name $(PROJECTNAME)-$$(tr -dc 'a-z0-9' </dev/urandom | head -c8) \
    -v $(PWD):/build \
    -v $(CACHE_DIR):/root/.cache/{lang} \
    -w /build \
    {lang}:alpine
```

### Cache mount rules (apply to every toolchain container)

1. **Declare cache paths with `?=`** — `VAR ?= $(HOME)/.cache/...` so the host env var is honored when set (e.g. custom XDG paths). Never hardcode a path that a user may have relocated.
2. **`@mkdir -p` before every `docker run`** — Docker silently creates missing dirs as root, breaking cache ownership and persistence. Always create the host dirs first:
   ```makefile
   build:
       @mkdir -p $(CACHE_DIR)
       $(LANG_DOCKER) ...
   ```
3. **Mount with `-v $(VAR):/container/path`** — the host path resolves from the `?=` variable; the container path is the fixed location for that toolchain image.

| Language | Host variable | Default | Container path |
|----------|--------------|---------|----------------|
| Go (build) | `GOCACHE ?= $(HOME)/.cache/go-build` | `~/.cache/go-build` | `/root/.cache/go-build` |
| Go (modules) | `GOMODCACHE ?= $(GOPATH)/pkg/mod` | `~/go/pkg/mod` | `/go/pkg/mod` |
| Rust (registry) | `CARGO_REGISTRY ?= $(CARGO_HOME)/registry` | `~/.cargo/registry` | `/usr/local/cargo/registry` |
| Rust (git) | `CARGO_GIT ?= $(CARGO_HOME)/git` | `~/.cargo/git` | `/usr/local/cargo/git` |
| Node | `NPM_CACHE ?= $(HOME)/.npm` | `~/.npm` | `/root/.npm` |
| Python (pip) | `PIP_CACHE ?= $(HOME)/.cache/pip` | `~/.cache/pip` | `/root/.cache/pip` |
| Python (uv) | `UV_CACHE ?= $(HOME)/.cache/uv` | `~/.cache/uv` | `/root/.cache/uv` |

- Always `--rm -it --name $(PROJECTNAME)-XXXX` — never leave build containers running; `-it` enables interactive use; `XXXX` is a random suffix: `$$(tr -dc 'a-z0-9' </dev/urandom | head -c8)`
- Always `-w /build` — explicit working directory
- Mount project root at `/build`; output dirs (`binaries/`, `dist/`) are subdirs of `/build`

Language-specific Docker variables and full cache mount patterns are in each language's conventions file:
- Go: `~/.claude/memory/go_conventions.md`
- Rust: `~/.claude/memory/rust_conventions.md`
- Node/TypeScript: `~/.claude/memory/node_typescript_conventions.md`
- Python: `~/.claude/memory/python_conventions.md`

---

## Cross-Platform Pitfalls

All build commands run inside Docker, so host OS differences are mostly irrelevant. Variable definitions (evaluated on the host) must be portable:

| Pitfall | Fix |
|---------|-----|
| `sed -i` needs `-i ''` on macOS | Run sed-using recipes inside Docker |
| `date` format varies (GNU vs BSD macOS) | `date +"%Y-%m-%dT%H:%M:%SZ"` works on both |
| `readlink -f` not available on macOS | Use `realpath` or run inside Docker |
| Tabs vs spaces in recipes | Makefiles require real tabs — never spaces in recipes |

---

## What `clean` Must Never Remove

- Source files (`src/`, `tests/`, `*.go`, `*.rs`, `*.ts`, `*.py`)
- `.git/` directory
- Base Docker images (`golang:alpine`, `rust:alpine`, etc.) — only project images are cleaned
- `AI.md`, `IDEA.md`, `CLAUDE.md`, `release.txt`, `Makefile`

`clean` removes only build artifacts: `binaries/`, `releases/`, `dist/`, language caches (`target/`, `__pycache__/`, `.mypy_cache/`, `node_modules/`).
