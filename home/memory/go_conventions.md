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
	-X 'main.BuildDate=$(BUILD_DATE)'

BINDIR    := binaries
RELDIR    := releases
GOCACHE   := $(HOME)/.cache/go-build
GOMODCACHE:= $(HOME)/go/pkg/mod
REGISTRY  := ghcr.io/$(PROJECTORG)/$(PROJECTNAME)

GO_DOCKER := docker run --rm \
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
| `docker` | Builds + pushes multi-arch image via `docker buildx` |
| `test` | Runs `go test -v -cover ./...` inside Docker |
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
GO_DOCKER := docker run --rm \
	-v $(PWD):/build \
	-v $(GOCACHE):/root/.cache/go-build \
	-v $(GOMODCACHE):/go/pkg/mod \
	-w /build \
	-e CGO_ENABLED=0 \
	golang:alpine
```

- Always `golang:alpine` (rolling tag — never pinned)
- Always `-e CGO_ENABLED=0`
- Module cache mounted from host for speed (`~/.cache/go-build`, `~/go/pkg/mod`)

## Dev Target Pattern

```makefile
dev:
	@mkdir -p $(GOCACHE) $(GOMODCACHE)
	@BUILD_DIR=$$(mktemp -d "$${TMPDIR:-/tmp}/$(PROJECTORG).XXXXXX") && \
		echo "Quick dev build..." && \
		$(GO_DOCKER) go build -o $$BUILD_DIR/$(PROJECTNAME) ./src && \
		echo "Built: $$BUILD_DIR/$(PROJECTNAME)" && \
		echo "Test:  docker run --rm -v $$BUILD_DIR:/app alpine:latest /app/$(PROJECTNAME) --help"
```

Always builds into a temp dir, never to a hardcoded path.

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

## Code Rules

- **CGO_ENABLED=0** — always; pure Go, no C, no exceptions
- **Strip release binaries** — always pass `-s -w` in LDFLAGS for `build`, `release`, and `docker` targets; `-s` strips the symbol table, `-w` strips DWARF debug info. The `dev` target (quick local build) omits `-s -w` to preserve debug symbols
- **No `-musl` suffix** — never include `-musl` in the output binary name; the binary naming schema is `{name}-{GOOS}-{GOARCH}` regardless of libc used to build
- **No `go build` on host** — always via `make dev`, `make build`, `make test` (Docker internally)
- **No external cron** — use the project's built-in scheduler (see project AI.md PART 19)
- **No `strconv.ParseBool()`** — use `config.ParseBool()` which handles 40+ variations
- **No client-side rendering** — server-side Go templates only
- **Single static binary** — `go:embed` for assets; zero runtime file deps
- **Go embed** — assets bundled at build time; binary works air-gapped

## Exit Codes

Use standard POSIX / sysexits codes via `os.Exit(N)` — never invent custom schemes. Key codes:

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | General runtime error |
| `2` | Bad arguments / misuse |
| `64` | EX_USAGE — wrong usage |
| `65` | EX_DATAERR — bad input data |
| `66` | EX_NOINPUT — input file not found |
| `69` | EX_UNAVAILABLE — service unavailable |
| `70` | EX_SOFTWARE — internal error |
| `74` | EX_IOERR — I/O error |
| `75` | EX_TEMPFAIL — temporary, caller may retry |
| `77` | EX_NOPERM — insufficient permissions |
| `78` | EX_CONFIG — configuration error |

`--help` and `--version` always exit `0`. Signal exits are `128 + signal` (SIGINT=130, SIGTERM=143). See `script_conventions.md` for the full table.

For Go, import `golang.org/x/sys/unix` or define the constants locally — the stdlib does not export sysexits. Never use `log.Fatal` as a substitute for a proper exit code.

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

Singular package and directory names: `handler/`, `model/`, `middleware/`, `config/` — not `handlers/`, `models/`. Exception: tooling dirs follow community convention and may be plural (`scripts/`, `tests/`, `binaries/`, `completions/`).

## Module Cache

Mount host cache dirs into the Docker container — do not re-download modules on every build:

```
~/.cache/go-build  → /root/.cache/go-build
~/go/pkg/mod       → /go/pkg/mod
```

## Version Source

`release.txt` is the version file — single line, semver (e.g. `0.1.0`). The Makefile reads it with `cat release.txt 2>/dev/null || echo "0.1.0"`. Never hardcode the version in the Makefile.
