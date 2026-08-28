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
| `script-collection` | no compiled/interpreted-language build target (no `go.mod`/`Cargo.toml`/`package.json`/`pyproject.toml` at root); a set of standalone `bin/` shell scripts plus `install.sh`, typically with `completions/`, `man/`, `functions/`/`helpers/` |
| `spec-collection` | root is entirely Markdown (spec/template/doc files consumed by AI tooling or humans) plus README.md/LICENSE.md/.gitignore; no source code directory at all — not even scripts; e.g. `claudemgr/config`, `claudemgr/go`, `claudemgr/rust`, `claudemgr/android`, `claudemgr/docker` |
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

- **Server-side rendering only** — Go templates, Jinja2, ERB, etc. for Go/Rust/Python servers. No React/Vue/Angular for core content. Node/TypeScript web projects (Express, Fastify, Next.js SSR) follow their own conventions in `~/.claude/CLAUDE.md` — SSR is still required; client-side rendering is still forbidden.
- **Progressive enhancement** — every page works without JavaScript; JS is an enhancement only. HTMX and Alpine.js are permitted as progressive-enhancement libraries because they do not require client-side rendering or routing — they augment server-rendered HTML in place. They must not be used to bypass SSR or to move business logic to the client.
- **Mobile-first CSS** — base styles target mobile; expand with `@media (min-width: …)` breakpoints.
- **Breakpoints:** mobile (none) · tablet (`768px`) · desktop (`1024px`) · wide (`1440px`)
- **Dark-first theme** — ship dark mode first; light mode and `auto` (system preference) also required.
- **Theme via CSS custom properties** — never hardcode colors inline; use `--bg`, `--fg`, `--accent` variables.
- **WCAG 2.1 AA** — 4.5:1 contrast for normal text, 3:1 for large text; semantic HTML; keyboard navigable.
- **Touch targets minimum 44×44 px**.
- **No JavaScript `alert()` / `confirm()`** — confirmations use native `<dialog>` with `<form method="dialog">`; status messages use toast notifications.
- **No inline event handler attributes** (`onclick`, `onchange`, …) — CSP blocks them; use a native HTML mechanism first, external-JS `addEventListener` only as enhancement.
- **Native HTML/CSS over JS re-implementations** — `<details>/<summary>` accordions, native `<dialog>` modals, `loading="lazy"`, `scroll-behavior: smooth`, `position: sticky`, `<progress>`, `<button type="reset">`, CSS `:user-invalid` validation styling.
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
- Node / TypeScript: `commander`, `yargs`, or `oclif` — choose based on complexity (`commander` for simple CLIs, `oclif` for multi-command plugin-style tools)

Never hand-roll a parser.

---

## Type: `script-collection`

Applies to: repos that are a collection of standalone bash/sh/zsh/fish scripts with no compiled or interpreted-language build target — e.g. `casjay-dotfiles/scripts` and the `*mgr` repo family. Distinct from a single-script `cli` project: a `script-collection` has multiple entrypoints under `bin/` plus supporting `functions/`/`helpers/`/`sources/`, driven by one `install.sh`.

### Detection signals
- No `go.mod`, `Cargo.toml`, `package.json`, or `pyproject.toml` at the project root.
- `bin/` holding one or more standalone scripts; commonly paired with `completions/`, `man/`, `functions/`/`helpers/`, `sources/`, `applications/`.
- `install.sh` at the root is the build/deploy step — there is no separate compile stage.
- `IDEA.md ## Project description` / `## Business logic` describes a script collection, dotfiles/toolkit, or shell-based utility suite.

### What is NOT required
- **No Makefile** — `install.sh` is the build+deploy step; do not add a Makefile just to have one. (`~/.claude/memory/makefile_conventions.md` does not apply to this project type.)
- **No CI/CD workflow** — do not create `.github/workflows/`, `.gitlab-ci.yml`, or Forgejo/Gitea Actions by default; `~/.claude/memory/cicd_conventions.md` is skipped entirely for this project type unless the user explicitly asks for an automated release/publish pipeline. If one is added later, it must still follow that file's rules (SHA-pinned third-party actions, etc.) — the exemption is "not required by default," not "forbidden."
- **No language-specific build/test tooling** (`go test`, `cargo test`, `npm test`) — there is no compiled/interpreted-language runtime to invoke it against.

### What replaces the standard gates
- **Test/lint gate:** `bash -n bin/{script}` (syntax check) + `script-lint bin/{script}` — this is this project type's equivalent of `make test` in the Commit Workflow pre-commit sequence. If `script-lint` is absent, fall back to `bash -n` plus `shellcheck` when available.
- **Documentation:** the Documentation Triple Sync (`__help()` output, man page, shell completions — see the `doc-sync` agent) replaces language-doc-generation (`godoc`/`cargo doc`) as the doc-completeness requirement.
- Full per-script code-style rules: `~/.claude/memory/script_conventions.md`.

---

## Type: `spec-collection`

Applies to: repos whose entire content is Markdown specification/template/documentation files — no source code, not even scripts. Distinct from `script-collection`: there is nothing to lint or syntax-check because there is no code, only prose/spec files consumed by AI tooling (e.g. copied verbatim into a generated project as its `AI.md`) or read by humans. Example: the `claudemgr` template repos (`config`, `go`, `rust`, `android`, `docker`) — each root holds only `.md` spec files plus `README.md`/`LICENSE.md`/`.gitignore`, and `config` additionally ships a single `install.sh` whose job is to copy files into place, not to build anything.

### Detection signals
- Root directory contains only `.md` files plus standard repo metadata (`README.md`, `LICENSE.md`, `.gitignore`, `.gitattributes`) — no `src/`, `bin/`, `cmd/`, `lib/`, or any language manifest (`go.mod`, `Cargo.toml`, `package.json`, `pyproject.toml`).
- An `install.sh`, if present, only copies/deploys files (no compile step) — this alone does not disqualify the repo from `spec-collection`.
- `IDEA.md`/`README.md` describes the repo as a spec, template, prompt library, or documentation set — not an executable tool.

### What is NOT required
- **No Makefile** — there is nothing to build.
- **No CI/CD workflow** — do not create `.github/workflows/`, `.gitlab-ci.yml`, or Forgejo/Gitea Actions by default; `~/.claude/memory/cicd_conventions.md` is skipped entirely unless the user explicitly asks for one (e.g. a link-checker or markdown-lint pipeline).
- **No test suite** — there is no runtime to exercise.

### What replaces the standard gates
- **Verification:** re-read the edited file(s) and diff against the intended content per the Self-Validation rule — the "test" for a spec repo is that the prose is correct and internally consistent (cross-references resolve, terminology matches across sibling files), not that a command exits 0.
- **Consistency sweep:** when a rule changes in one file that has sibling copies (e.g. a `home/**` rule that also appears in `{lang}/AI.md` templates), grep every sibling for the same pattern and update them together — see `~/Projects/github/claudemgr/config/AI.md § Part 9` for the claudemgr-specific alignment rule.
- If `install.sh` exists, it still follows `~/.claude/memory/script_conventions.md` for its own code style, but that does not make the surrounding repo a `script-collection`.

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
