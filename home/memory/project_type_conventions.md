---
name: Project type conventions
description: Cross-language rules by project type — rules follow what the project IS, not what language it uses
type: user
---

## Core Principle

**Rules follow project type, not language.** A Go desktop app and a Rust desktop app share the same desktop-gui type rules. A Rust HTTP server and a Go HTTP server share the same server type rules. Language-specific files (`go_conventions.md`, `rust_conventions.md`) answer HOW to implement; project type answers WHAT rules apply.

## Identifying Project Type

Read `IDEA.md ## Business logic` and `## Project description` to determine type. When ambiguous, ask — never guess. A project may be more than one type (e.g. a server with a CLI management tool), in which case all applicable type rules apply.

| Type | Signals in IDEA.md |
|------|--------------------|
| `server` | serves requests, listens on a port, daemon, API, webhook receiver |
| `desktop-gui` | windowed UI, native app, desktop application |
| `tui` | terminal UI, interactive terminal, ncurses-style |
| `cli` | command-line tool, one-shot invocation, scripting target |
| `library` | importable package/crate, no binary entrypoint |
| `agent` / `worker` | background job processor, queue consumer, scheduled task |

---

## Type: `server` / `daemon`

Applies to: HTTP servers, gRPC services, WebSocket servers, background daemons, queue workers.

### Required behavior
- **Timeouts everywhere** — every inbound request, outbound call, DB query, and subprocess wait must have an explicit timeout or deadline. No infinite waits.
- **Graceful shutdown** — handle `SIGTERM` / `SIGINT`; drain in-flight requests before exit; configurable drain timeout (default 30 s).
- **Health endpoint** — expose `GET /healthz` (or equivalent) returning `200 OK` with a JSON body; used by load balancers, Docker health checks, and Kubernetes liveness/readiness probes.
- **Structured logging to stdout/stderr** — servers always log to stdout (access/app) and stderr (errors). Never write to files inside the container (see `logging_conventions.md`).
- **Connection limits** — cap maximum concurrent connections and in-flight requests. Reject at the limit with `503 Service Unavailable`, not hang.
- **Backpressure** — queues and channels must be bounded. An unbounded queue is a memory leak under load.
- **Per-request context** — propagate a context/cancellation token through the entire call chain so timeouts and shutdown cancel all downstream work.
- **No ambient globals for request state** — per-request state lives in context, not package-level variables.

### Startup
- Validate all required config at startup; exit non-zero immediately if required values are missing or invalid — do not start partially configured.
- Log the listening address and version on startup.

### Security (server-specific)
- Bind to `localhost` by default; require explicit config to bind to `0.0.0.0`.
- Enforce request body size limits — reject oversized payloads before parsing.
- Rate-limit all public endpoints.
- All DB queries are parameterized — no string concatenation.
- CSRF protection on any endpoint that mutates state via a browser session.

---

## Type: `desktop-gui`

Applies to: native windowed applications on Linux, macOS, Windows.

### Display backend (Linux/BSD)
- **Both X11 and Wayland are required as first-class backends** — not one as fallback of the other.
- Auto-detect at runtime: prefer Wayland when `$WAYLAND_DISPLAY` is set; fall back to X11 when `$DISPLAY` is set; exit with a clear error if neither is available.
- **Never auto-launch a GUI in SSH/MOSH/headless contexts** — check `$DISPLAY` / `$WAYLAND_DISPLAY` before initializing any display backend. Fall back to TUI or CLI when no display is available.
- No link-time hard dependency on a specific display library; use `dlopen`-style or pure-Rust display crates so the binary works on systems with either display server.

### Platform behavior
| Platform | Expected |
|----------|---------|
| Linux/BSD | X11 + Wayland, runtime-selected |
| macOS | Native Cocoa/AppKit or Metal via platform APIs |
| Windows | Native Win32 or WinUI |

### Required features
- Keyboard-navigable — all interactive elements reachable without a mouse.
- Respect system dark/light mode preference.
- Remember window size and position across sessions (write to user config dir, never to project dir).
- `--no-gui` / detecting headless → fall back to TUI or CLI rather than crash.

### Asset handling
- All fonts, icons, and default themes are embedded in the binary at compile time — no first-run downloads.
- No hardcoded absolute asset paths.

---

## Type: `tui`

Applies to: interactive full-screen terminal UIs.

### Required behavior
- Use the **alternate screen buffer** — enter on start, leave on exit (including panic/signal). Never leave the terminal in a broken state.
- Set **blinking I-beam cursor** on enter; restore default cursor on leave.
- Handle `SIGTERM` / `SIGINT` — restore terminal before exit.
- **`TERM=dumb` and piped stdout** → fall back to CLI output, not a broken pseudo-TUI.
- **`NO_COLOR`** → disable all color and styling; fall back to plain text layout if the TUI depends on color for structure.
- Keyboard-only navigation — no mouse requirement (mouse may be an enhancement).

### Implementation
- Shell: ANSI escapes directly (never `tput` — it forks a subprocess per call).
- Go: raw ANSI constants or `bubbletea` with `tea.WithAltScreen()`.
- Rust: `crossterm` + `ratatui` (never raw ANSI strings in Rust).

See `script_conventions.md`, `go_conventions.md`, and `rust_conventions.md` for language-specific patterns.

---

## Type: `cli`

Applies to: non-interactive command-line tools invoked once per task.

### Interface discipline
- **stdin / stdout / stderr** — stdout is program output (machine-readable); stderr is human-readable status/errors. Never mix them.
- **Exit codes** — POSIX (0 success, 1 general error, 2 misuse) + sysexits 64–78 + signal 128+N. Never invent codes outside this range.
- **`--help` / `-h`** → print help and exit `0` — never require privileges.
- **`--version` / `-v`** → print version and exit `0` — never require privileges.
- **`--color auto|yes|no`** and **`NO_COLOR`** — always honor both; see language-specific conventions.
- **Machine-readable output** — provide `--json` or `--output json` for any output that downstream scripts might consume.
- **Idempotent when possible** — running twice should be safe; document when it is not.

### Argument parsing
- Shell: `getopt` / `zparseopts` / `argparse` (per `script_conventions.md`)
- Go: standard `flag` package or `cobra`/`pflag`
- Rust: `clap` (derive API)

Never hand-roll a parser.

---

## Type: `library`

Applies to: packages/crates with no binary entrypoint, consumed by other projects.

### Required behavior
- **No `process::exit` / `os.Exit` / `std::process::exit`** in library code — only return errors. Let the caller decide.
- **No global state** — no `init()` side effects (Go), no `lazy_static!` global mutations (Rust), no package-level variables that change. Library state lives in a struct the caller instantiates.
- **No logging to stdout/stderr by default** — integrate with the caller's logger (Go: accept a `slog.Logger`; Rust: use the `log` / `tracing` facade so the caller chooses the sink).
- **Semver** — public API changes follow semver strictly. Breaking changes require a major version bump and a migration guide.
- **MSRV** — declare and test against a minimum supported language version.
- **No mandatory network calls** — optional network features are behind a feature flag (Rust) or build tag (Go).
- **No panics on bad input** — return an error. Panics are reserved for logic errors that indicate a programming mistake in the caller.

---

## Type: `agent` / `worker`

Applies to: background processors, queue consumers, scheduled tasks, crawlers.

Inherits all `server` rules plus:

- **Poison-pill handling** — a single malformed message must not crash the worker; log the error, dead-letter or skip the message, continue processing.
- **Idempotent processing** — assume any message may be delivered more than once; deduplication or idempotency keys are required for destructive operations.
- **Backoff on errors** — failed jobs retry with exponential backoff + jitter, not tight retry loops.
- **Dead-letter queue** — messages that fail beyond the retry limit go to a DLQ for inspection, not silently dropped.
- **Visible progress** — log job start, completion, and failure at info level. Silent workers are impossible to monitor.
- **Shutdown drains** — on SIGTERM, finish the current item, then stop accepting new work. Do not abandon partially processed messages.
