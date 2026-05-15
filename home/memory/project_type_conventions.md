---
name: Project type conventions
description: Cross-language rules by project type — rules follow what the project IS, not what language it uses
type: user
---

## Core Principle

**Rules follow project type, not language.** A Go desktop app and a Rust desktop app share the same desktop-gui type rules. A Rust HTTP server and a Go HTTP server share the same server type rules. Language-specific files (`~/.claude/memory/go_conventions.md`, `~/.claude/memory/rust_conventions.md`) answer HOW to implement; project type answers WHAT rules apply.

## Identifying Project Type

Read `{project_dir}/IDEA.md ## Business logic` and `## Project description` to determine type. When ambiguous, ask — never guess. A project may be more than one type (e.g. a server with a CLI management tool), in which case all applicable type rules apply.

| Type | Signals in IDEA.md |
|------|--------------------|
| `server` | serves requests, listens on a port, daemon, API, webhook receiver |
| `web` | HTML UI served by a server — browser-facing pages, forms, dashboards |
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
- **Structured logging to stdout/stderr** — servers always log to stdout (access/app) and stderr (errors). Never write to files inside the container (see `~/.claude/memory/logging_conventions.md`).
- **Connection limits** — cap maximum concurrent connections and in-flight requests. Reject at the limit with `503 Service Unavailable`, not hang.
- **Backpressure** — queues and channels must be bounded. An unbounded queue is a memory leak under load.
- **Per-request context** — propagate a context/cancellation token through the entire call chain so timeouts and shutdown cancel all downstream work.
- **No ambient globals for request state** — per-request state lives in context, not package-level variables.

### Startup
- Validate all required config at startup; exit non-zero immediately if required values are missing or invalid — do not start partially configured.
- Log the listening address and version on startup.

### Observability
- **Metrics endpoint** — expose `GET /metrics` in Prometheus text format (or equivalent for the observability stack); required for any server that runs in a container or behind a load balancer
- Minimum metrics to expose: request count, request duration (histogram), error count, active connections, build version (gauge with label)

### Security (server-specific)
- Bind to `localhost` by default; require explicit config to bind to `0.0.0.0`.
- Enforce request body size limits — reject oversized payloads before parsing.
- Rate-limit all public endpoints.
- All DB queries are parameterized — no string concatenation.
- CSRF protection on any endpoint that mutates state via a browser session.

---

## Type: `web`

Applies to: browser-facing HTML UIs — server-rendered pages, forms, dashboards, admin panels. Always combined with `server` type; `web` adds the UI-facing rules.

See `~/.claude/memory/ui_ux_conventions.md` for the full design system. Key rules:

- **Server-side rendering only** — Go templates, Jinja2, ERB, etc. No React/Vue/Angular for core content.
- **Progressive enhancement** — every page works without JavaScript; JS is an enhancement only. HTMX and Alpine.js are permitted as progressive-enhancement libraries because they do not require client-side rendering or routing — they augment server-rendered HTML in place. They must not be used to bypass SSR or to move business logic to the client.
- **Mobile-first CSS** — base styles target mobile; expand with `@media (min-width: …)` breakpoints.
- **Breakpoints:** mobile (none) · tablet (`768px`) · desktop (`1024px`) · wide (`1440px`)
- **Dark-first theme** — ship dark mode first; light mode and `auto` (system preference) also required.
- **Theme via CSS custom properties** — never hardcode colors inline; use `--bg`, `--fg`, `--accent` variables.
- **WCAG 2.1 AA** — 4.5:1 contrast for normal text, 3:1 for large text; semantic HTML; keyboard navigable.
- **Touch targets minimum 44×44 px**.
- **No JavaScript `alert()` / `confirm()`** — use toast notifications or modal dialogs.
- **No inline CSS or `<style>` blocks** in templates.
- **Long strings** (IPs, tokens, hashes, UUIDs) — always apply `word-break: break-all; font-family: monospace`.
- **Every state handled** — loading, empty, error, success each have a distinct, informative UI.
- **No placeholder content** — no "coming soon", "Feature 1", or empty states without a meaningful message.

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

See `~/.claude/memory/script_conventions.md`, `~/.claude/memory/go_conventions.md`, and `~/.claude/memory/rust_conventions.md` for language-specific implementation patterns.

---

## Type: `cli`

Applies to: non-interactive command-line tools invoked once per task.

### Interface discipline
- **stdin / stdout / stderr** — stdout is program output (machine-readable); stderr is human-readable status/errors. Never mix them.
- **Exit codes** — POSIX (0 success, 1 general error, 2 misuse) + sysexits 64–78 + signal 128+N. Never invent codes outside this range.
- **`--help` / `-h`** → print help and exit `0` — never require privileges.
- **`--version` / `-v`** → print version and exit `0` — never require privileges.
- **`--color auto|yes|no`** and **`NO_COLOR`** — always honor both; see language-specific conventions.
- **Machine-readable output** — provide `--json` or `--output json` for any output that downstream scripts might consume. When `--json` is active, the exit code semantics are unchanged — errors still exit non-zero; the JSON body carries error detail in a `{"error": "..."}` field.
- **Idempotent when possible** — running twice should be safe; document when it is not.

### Argument parsing
- Shell: `getopt` / `zparseopts` / `argparse` (per `~/.claude/memory/script_conventions.md`)
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
- **Documentation generation** — all public symbols must have doc comments; run `godoc` (Go) or `cargo doc` (Rust) as part of CI and treat warnings as errors. A library with undocumented public API is incomplete.

---

## Type: `plugin` / `extension`

Applies to: dynamically loaded modules, browser extensions, editor plugins, app extensions.

- **Hardened plugin contract** — the host must define and document the exact interface (function signatures, data types, versioning) in `{project_dir}/IDEA.md` before any plugin loading is implemented
- **No ambient trust** — plugins run with the minimum necessary capability; they must not receive host credentials, internal data structures, or unrestricted filesystem access
- **Sandboxing** — prefer WASM, subprocess isolation, or capability-based APIs over raw `dlopen`/FFI; raw dynamic loading requires explicit justification in `{project_dir}/IDEA.md`
- **Versioned interface** — the plugin API is semver-versioned; breaking changes require a major version bump and a migration path
- **Signature verification** — plugins loaded from external sources must be cryptographically verified before execution; unsigned plugins are rejected by default
- **Failure isolation** — a plugin panic or crash must not crash the host; wrap plugin calls in a recovery boundary (Go: `recover()`; Rust: `catch_unwind`)

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
