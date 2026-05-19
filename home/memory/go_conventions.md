---
name: Go conventions
description: Build system, project layout, Makefile targets, and code rules for CasjaysDev Go projects
type: user
---

## Project Layout

```
{project_name}/
├── src/            # all Go source files (package main lives here)
├── binaries/       # compiled output — gitignored
├── releases/       # release archives — gitignored
├── docker/
│   ├── Dockerfile
│   └── rootfs/
├── scripts/
├── tests/
├── go.mod
├── go.sum
├── Makefile
├── release.txt     # current version string (e.g. 0.1.0)
└── AI.md
```

Source always under `src/` — never at repo root. `package main` entry point is `./src`.

## Makefile — Standard Variables

```makefile
# Infer from git remote — NEVER hardcode
PROJECTNAME := $(shell git remote get-url origin 2>/dev/null | sed -E 's|.*/([^/]+)(\.git)?$$|\1|' || basename "$$(pwd)")
PROJECTORG  := $(shell git remote get-url origin 2>/dev/null | sed -E 's|.*/([^/]+)/[^/]+(\.git)?$$|\1|' || basename "$$(dirname "$$(pwd)")")

VERSION    ?= $(shell cat release.txt 2>/dev/null || echo "0.1.0")
BUILD_DATE := $(shell date +"%a %b %d, %Y at %H:%M:%S %Z")
COMMIT_ID  := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

LDFLAGS := -s -w \
	-X 'main.Version=$(VERSION)' \
	-X 'main.CommitID=$(COMMIT_ID)' \
	-X 'main.BuildDate=$(BUILD_DATE)' \
	-X 'main.OfficialSite=$(OFFICIAL_SITE)'

BINDIR     := binaries
RELDIR     := releases
GOPATH     ?= $(HOME)/go
GOCACHE    ?= $(HOME)/.cache/go-build
GOMODCACHE ?= $(GOPATH)/pkg/mod
REGISTRY   := ghcr.io/$(PROJECTORG)/$(PROJECTNAME)

GO_DOCKER := docker run --rm -it \
	--name $(PROJECTNAME)-$$(tr -dc 'a-z0-9' </dev/urandom | head -c8) \
	-v $(PWD):/build \
	-v $(GOCACHE):/root/.cache/go-build \
	-v $(GOMODCACHE):/go/pkg/mod \
	-w /build \
	-e CGO_ENABLED=0 \
	golang:alpine
```

## Makefile — Standard Targets

| Target | What it does |
|--------|-------------|
| `build` | All 8 platforms + host binary; outputs to `binaries/` |
| `release` | Prepares release archives in `releases/` |
| `docker` | Builds + pushes multi-arch image via `docker buildx --platform linux/amd64,linux/arm64 --push` |
| `test` | Runs `go vet ./...` then `go test -v -cover ./...` inside Docker |
| `dev` | Quick host-platform-only build into `mktemp` temp dir |
| `clean` | Removes `binaries/` and `releases/` |

## Build Targets and Binary Naming

8 platforms — uses Go's native GOOS/GOARCH terms directly:

| GOOS | GOARCH | Output binary |
|------|--------|--------------|
| `linux` | `amd64` | `{name}-linux-amd64` |
| `linux` | `arm64` | `{name}-linux-arm64` |
| `darwin` | `amd64` | `{name}-darwin-amd64` |
| `darwin` | `arm64` | `{name}-darwin-arm64` |
| `windows` | `amd64` | `{name}-windows-amd64.exe` |
| `windows` | `arm64` | `{name}-windows-arm64.exe` |
| `freebsd` | `amd64` | `{name}-freebsd-amd64` |
| `freebsd` | `arm64` | `{name}-freebsd-arm64` |

Schema: **`{project_name}-{GOOS}-{GOARCH}`** — windows appends `.exe`. macOS is always `darwin`, never `macos`. The host-platform binary (no suffix) is also built: `{project_name}` (or `{project_name}.exe` on Windows host).

## Docker Build Pattern

```makefile
GO_DOCKER := docker run --rm -it \
	--name $(PROJECTNAME)-$$(tr -dc 'a-z0-9' </dev/urandom | head -c8) \
	-v $(PWD):/build \
	-v $(GOCACHE):/root/.cache/go-build \
	-v $(GOMODCACHE):/go/pkg/mod \
	-w /build \
	-e CGO_ENABLED=0 \
	golang:alpine
```

- Always `golang:alpine` (rolling tag — never pinned)
- Always `-e CGO_ENABLED=0`
- `/root/.cache/go-build` and `/go/pkg/mod` are paths **inside the container** — `golang:alpine` runs as root, so `/root` is correct and expected there. `$(GOCACHE)` and `$(GOMODCACHE)` are the **host** paths, always resolved via `$(HOME)` — never hardcoded.

## Target Patterns

Every target that invokes `GO_DOCKER` or any `docker run` with a Go toolchain image **must** create the cache dirs as its first step. This ensures the host dirs exist before Docker mounts them and that downloaded modules persist across runs.

```makefile
build:
	@mkdir -p $(GOCACHE) $(GOMODCACHE)
	$(GO_DOCKER) go build -ldflags "$(LDFLAGS)" -o $(BINDIR)/$(PROJECTNAME) ./src

test:
	@mkdir -p $(GOCACHE) $(GOMODCACHE)
	$(GO_DOCKER) go vet ./...
	$(GO_DOCKER) go test -v -cover ./...

dev:
	@mkdir -p $(GOCACHE) $(GOMODCACHE)
	@mkdir -p "$${TMPDIR:-/tmp}/$(PROJECTORG)" && \
		BUILD_DIR=$$(mktemp -d "$${TMPDIR:-/tmp}/$(PROJECTORG)/$(PROJECTNAME)-XXXXXX") && \
		echo "Quick dev build..." && \
		$(GO_DOCKER) go build -o $$BUILD_DIR/$(PROJECTNAME) ./src && \
		echo "Built: $$BUILD_DIR/$(PROJECTNAME)" && \
		echo "Test:  docker run --rm -it --name $(PROJECTNAME)-test -v $$BUILD_DIR:/app alpine:latest /app/$(PROJECTNAME) --help"
```

Always builds into a temp dir, never to a hardcoded path.

**Rule — any direct `docker run` with a Go toolchain image** (not via `GO_DOCKER` macro) must also include the cache mounts and the preceding mkdir:

```makefile
some-target:
	@mkdir -p $(GOCACHE) $(GOMODCACHE)
	@docker run --rm -it \
		--name $(PROJECTNAME)-$$(tr -dc 'a-z0-9' </dev/urandom | head -c8) \
		-v $(PWD):/build \
		-v $(GOCACHE):/root/.cache/go-build \
		-v $(GOMODCACHE):/go/pkg/mod \
		-w /build \
		-e CGO_ENABLED=0 \
		golang:alpine \
		go ...
```

Never omit the cache mounts from a Go docker run — every invocation that downloads or compiles modules must persist results to the host.

## Build Info Variables

Declare in `main.go` as package-level vars set by ldflags:

```go
var (
    Version   = "dev"
    CommitID  = "unknown"
    BuildDate = "unknown"
)
```

Never use `VCS_REF` as an alias — `CommitID` is the canonical name.

## Registry

Always `ghcr.io/{PROJECTORG}/{PROJECTNAME}` — tagged as both `:{VERSION}` and `:latest`.

Docker target uses `docker buildx` with `--platform linux/amd64,linux/arm64` and `--push`.

## Minimum Go Version

Set `go` directive in `go.mod` to the minimum required version. New projects start with the current stable release. Never set it lower than needed just to broaden compatibility — use the version that matches the features the code actually uses.

```
go 1.22
```

Update when a feature from a newer version is adopted.

## Linting & Vetting

- **`go vet`** runs as part of the `test` target (before `go test`); CI fails on any vet warning
- **`golangci-lint`** is required for all projects; config lives at `{project_dir}/.golangci.yml`; CI runs it in `ci.yml`; minimum enabled linters: `errcheck`, `govet`, `staticcheck`, `unused`, `gosimple`
- Never suppress a lint warning with a `//nolint` directive without a comment explaining why

## Error Handling

- Wrap errors with context using `fmt.Errorf("operation: %w", err)` — always wrap, never discard
- Sentinel errors are defined as `var ErrFoo = errors.New("foo")` at package level; use `errors.Is` / `errors.As` to check, never string comparison
- Custom error types implement the `error` interface; use when the caller needs to inspect error fields
- Never use `log.Fatal` as a substitute for a proper exit code — `log.Fatal` calls `os.Exit(1)` with no cleanup

## Code Rules

- **CGO_ENABLED=0** — always; pure Go, no C, no exceptions
- **Strip release binaries** — always pass `-s -w` in LDFLAGS for `build`, `release`, and `docker` targets; `-s` strips the symbol table, `-w` strips DWARF debug info. The `dev` target (quick local build) omits `-s -w` to preserve debug symbols
- **No `-musl` suffix** — never include `-musl` in the output binary name; the binary naming schema is `{name}-{GOOS}-{GOARCH}` regardless of libc used to build
- **No `go build` on host** — always via `make dev`, `make build`, `make test` (Docker internally)
- **No external cron** — use a built-in scheduler (e.g. `robfig/cron`, `go-co-op/gocron`, or a ticker loop); never depend on host cron or systemd timers for application-level scheduling
- **No `strconv.ParseBool()`** — use `config.ParseBool()` which handles 40+ variations
- **No client-side rendering** — server-side Go templates only
- **Single static binary** — `go:embed` for assets; zero runtime file deps
- **Go embed** — assets bundled at build time; binary works air-gapped

## Exit Codes

Use standard POSIX / sysexits codes via `os.Exit(N)` — never invent custom schemes. Full table is in `~/.claude/memory/script_conventions.md`. `--help` and `--version` always exit `0`; signal exits are `128 + signal` (SIGINT=130, SIGTERM=143).

For Go, import `golang.org/x/sys/unix` or define sysexits constants locally — the stdlib does not export them. Never use `log.Fatal` as a substitute for a proper exit code.

## CLI Flags — Standard Interface

### Standard flags (all Go TUI/CLI binaries)

| Flag | Short | Values | Behavior |
|------|-------|--------|----------|
| `--help` | `-h` | — | Print help and exit 0 — never escalate privileges |
| `--version` | `-v` | — | Print version and exit 0 — never escalate privileges |
| `--debug` | — | — | Enable debug output |
| `--color` | — | `auto` / `yes` / `no` | Control color output |

- `--color auto` detects terminal capability (default); `yes` forces color; `no` disables it and removes emojis from output.
- Both `--color auto` and `--color=auto` must work — flag library must support `=` syntax.
- `--help` and `--version` must never require root — always exit immediately with the requested output.

### NO_COLOR support

Every Go TUI/CLI binary must honor the `NO_COLOR` environment variable ([no-color.org](https://no-color.org/)):

```go
// Color resolution order (highest precedence first):
// 1. --color=no  or  --color=yes
// 2. NO_COLOR env var present (any value) → disable color and emojis
// 3. --color=auto → check os.Stdout isatty
func resolveColor(flag string) bool {
    switch flag {
    case "yes":
        return true
    case "no":
        return false
    default: // "auto"
        if _, set := os.LookupEnv("NO_COLOR"); set {
            return false
        }
        return isatty(os.Stdout.Fd())
    }
}
```

### Flag parsing — use `flag` stdlib or `pflag`

Use the standard `flag` package or `pflag` (cobra/viper) — never hand-roll argument parsing. `pflag` supports `--flag=value` and `--flag value` natively.

Recommended for multi-command CLIs: `cobra` + `viper`. Recommended for single-command binaries: stdlib `flag`.

```go
// cobra example — color flag on root command
rootCmd.PersistentFlags().String("color", "auto", "Color output: auto, yes, no")
```

## Terminal Display — Alt Buffer and ANSI Escapes

Any Go binary that is a TUI or acts as a TUI must use the alternate screen buffer. Use raw ANSI escape sequences written to `os.Stdout` — never shell out to `tput`.

### Constants

```go
const (
    AltBufEnter   = "\033[?1049h" // enter alternate screen buffer
    AltBufLeave   = "\033[?1049l" // leave alternate screen buffer
    CursorBlink   = "\033[5 q"    // blinking I-beam (preferred)
    CursorRestore = "\033[0 q"    // restore terminal default cursor
    CursorHide    = "\033[?25l"
    CursorShow    = "\033[?25h"
    ClearScreen   = "\033[2J\033[H"
)
```

### Enter / leave pattern

```go
func enterTUI() {
    fmt.Fprint(os.Stdout, AltBufEnter+CursorBlink)
}

func leaveTUI() {
    fmt.Fprint(os.Stdout, AltBufLeave+CursorRestore)
}
```

Always call `leaveTUI()` via `defer` **and** from a signal handler so the terminal is restored on Ctrl-C:

```go
enterTUI()
defer leaveTUI()

sigs := make(chan os.Signal, 1)
signal.Notify(sigs, os.Interrupt, syscall.SIGTERM)
go func() {
    <-sigs
    leaveTUI()
    os.Exit(130)
}()
```

### bubbletea shortcut

If using `github.com/charmbracelet/bubbletea`, pass `tea.WithAltScreen()` — it manages alt buffer and cursor automatically:

```go
p := tea.NewProgram(model, tea.WithAltScreen())
```

Do not manually call `enterTUI`/`leaveTUI` when using bubbletea — it handles setup and teardown internally.

### NO_COLOR

Suppress all ANSI output (colors, cursor sequences) when `NO_COLOR` is set or `--color=no` is in effect. Use the `resolveColor` function from the CLI Flags section — do not emit any escape sequence when color is disabled.

---

## Directory Naming

Singular package and directory names — see `~/.claude/CLAUDE.md` → Code & Files for the full rule and exceptions.

## Module Cache

Mount host cache dirs into the Docker container — do not re-download modules on every build:

```
$(GOCACHE) on host    →  /root/.cache/go-build  in container  (golang:alpine runs as root)
$(GOMODCACHE) on host →  /go/pkg/mod            in container
```

`GOPATH`, `GOCACHE`, and `GOMODCACHE` all use `?=` so host environment values are respected when set (e.g. XDG paths, custom `GOPATH`, CI overrides). `GOMODCACHE` derives from `GOPATH` rather than hardcoding `~/go` so custom `GOPATH` locations (like `~/.local/share/go`) are handled automatically. Every target that uses `GO_DOCKER` or any direct `docker run` with a Go image must `@mkdir -p $(GOCACHE) $(GOMODCACHE)` first — Docker will silently create dirs as root if they don't exist, breaking cache persistence.

## Version Source

`release.txt` is the version file — single line, semver (e.g. `0.1.0`). The Makefile reads it with `cat release.txt 2>/dev/null || echo "0.1.0"`. Never hardcode the version in the Makefile.
