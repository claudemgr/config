---
name: Rust conventions
description: Build system, project layout, Makefile targets, Cargo profile, and code rules for CasjaysDev Rust projects
type: user
---

## Project Layout

```
{project_name}/
├── src/            # Rust source files
├── tests/          # integration and unit tests
├── binaries/       # compiled output — gitignored
├── releases/       # release archives — gitignored
├── build.rs        # build script (if needed)
├── Cargo.toml
├── Cargo.lock      # always committed (binary crate)
├── Makefile
├── release.txt     # current version string (e.g. 0.1.0)
└── AI.md
```

## Makefile — Standard Variables

```makefile
PROJECT_NAME  := {project_name}
ORGANIZATION  := {project_org}
VERSION       := $(shell cat release.txt 2>/dev/null || echo "devel")
COMMIT_ID     := $(shell git rev-parse --short HEAD 2>/dev/null || echo "N/A")
PLATFORMS     ?= linux/amd64,linux/arm64
DOCKER_IMAGE  := rust:alpine
BINARIES_DIR  := ./binaries
RELEASES_DIR  := ./releases

CARGO_HOME     ?= $(HOME)/.cargo
CARGO_REGISTRY ?= $(CARGO_HOME)/registry
CARGO_GIT      ?= $(CARGO_HOME)/git

RUST_DOCKER := docker run --rm -it \
	--name $(PROJECT_NAME)-$$(tr -dc 'a-z0-9' </dev/urandom | head -c8) \
	-v "$(PWD)":/workspace \
	-v $(CARGO_REGISTRY):/usr/local/cargo/registry \
	-v $(CARGO_GIT):/usr/local/cargo/git \
	-w /workspace \
	$(DOCKER_IMAGE)
```

- `rust:alpine` rolling tag — never pinned
- `PROJECT_NAME` and `ORGANIZATION` are literal here (not inferred from git); keep in sync with `Cargo.toml`
- `CARGO_HOME`, `CARGO_REGISTRY`, `CARGO_GIT` use `?=` so host environment values (e.g. custom `CARGO_HOME` in CI) are respected; defaults cover the standard `~/.cargo` location on Linux/macOS
- In `rust:alpine`, Cargo's home is `/usr/local/cargo` — registry and git dirs are mounted there so downloads persist to the host

## Makefile — Standard Targets

| Target | What it does |
|--------|-------------|
| `build` | Builds all platforms inside Docker; outputs to `binaries/` |
| `release` | Prepares release archives in `releases/` |
| `test` | Runs `cargo fmt --check`, `cargo clippy -- -D warnings`, then `cargo test --lib --no-fail-fast` inside Docker |
| `clean` | Removes `binaries/`, `releases/`, and `target/` |
| `help` | Prints target list and current version |

## Build Pattern

All cargo invocations run inside Docker — never directly on host. Every target must `@mkdir -p $(CARGO_REGISTRY) $(CARGO_GIT)` before the docker run:

```makefile
build:
	@mkdir -p $(CARGO_REGISTRY) $(CARGO_GIT)
	@docker run --rm -it --platform linux/amd64 \
		--name $(PROJECT_NAME)-$$(tr -dc 'a-z0-9' </dev/urandom | head -c8) \
	    -v "$(PWD)":/workspace \
	    -v "$(PWD)/binaries":/output \
	    -v $(CARGO_REGISTRY):/usr/local/cargo/registry \
	    -v $(CARGO_GIT):/usr/local/cargo/git \
	    -w /workspace $(DOCKER_IMAGE) bash -c ' \
	    cargo build --release && \
	    strip target/release/$(PROJECT_NAME) 2>/dev/null || true && \
	    cp target/release/$(PROJECT_NAME) /output/$(PROJECT_NAME)-{os}-{arch} && \
	    chmod 755 /output/$(PROJECT_NAME)-{os}-{arch}'
```

Binary naming: `{project_name}-{os}-{arch}` (e.g. `cascolor-linux-x86_64`).

**Rule — any `docker run` with a Rust/Cargo image** must include the cache volume mounts and the preceding mkdir. Never omit them — every invocation that fetches or compiles crates must persist results to the host.

## Platform Targets and Binary Naming

Uses simplified OS name + GNU arch (not the full Rust target triple) for the output filename:

| Rust target triple | Output binary | Notes |
|-------------------|--------------|-------|
| `x86_64-unknown-linux-gnu` | `{name}-linux-x86_64` | Docker Linux/amd64 |
| `aarch64-unknown-linux-gnu` | `{name}-linux-aarch64` | Requires native ARM64 or QEMU |
| `x86_64-pc-windows-gnu` | `{name}-windows-x86_64.exe` | MinGW cross (GTK4 not supported via MinGW) |
| `x86_64-apple-darwin` | `{name}-macos-x86_64` | macOS host required |
| `aarch64-apple-darwin` | `{name}-macos-aarch64` | macOS host required |
| `x86_64-unknown-freebsd` | `{name}-freebsd-x86_64` | FreeBSD host required |

Schema: **`{project_name}-{os}-{arch}`** where:
- OS: `linux` / `macos` / `windows` / `freebsd` (simplified — never the full triple)
- Arch: `x86_64` / `aarch64` (GNU arch terms — not Go's `amd64`/`arm64`)
- Windows appends `.exe`

**Rust uses `macos`, Go uses `darwin`** — they differ deliberately; each follows its own ecosystem's convention.

macOS and FreeBSD cross-compilation from Linux is generally not supported — document as skipped with a note in the Makefile output.

## Test Target Pattern

```makefile
test:
	@mkdir -p $(CARGO_REGISTRY) $(CARGO_GIT)
	@docker run --rm -it \
		--name $(PROJECT_NAME)-$$(tr -dc 'a-z0-9' </dev/urandom | head -c8) \
	    -v "$(PWD)":/workspace \
	    -v $(CARGO_REGISTRY):/usr/local/cargo/registry \
	    -v $(CARGO_GIT):/usr/local/cargo/git \
	    -w /workspace $(DOCKER_IMAGE) bash -c \
	    'cargo fmt --check && cargo clippy -- -D warnings && cargo test --lib --no-fail-fast'
```

Always inside Docker. Never `cargo test` directly on host.

## Cargo.toml — Release Profile (NON-NEGOTIABLE)

```toml
[profile.release]
opt-level     = "z"   # optimize for size
lto           = true
codegen-units = 1
strip         = true
panic         = "abort"
```

Always optimize for size (`opt-level = "z"`), always strip, always LTO — for release builds only. Dev/debug builds use Cargo defaults (no stripping, debug symbols preserved).

## Cargo.toml — Package Fields

```toml
[package]
name        = "{project_name}"
version     = "0.1.0"
edition     = "2021"
rust-version = "1.70"
authors     = ["{project_org}"]
license     = "MIT"
description = "..."
repository  = "https://github.com/{project_org}/{project_name}"
```

- Edition is always `2021`
- `rust-version` (MSRV) is required; set to the oldest Rust release the code compiles against; CI must test against this version
- `Cargo.lock` is always committed for binary crates; library crates should NOT commit `Cargo.lock` (allows consumers to use their own resolution)

## Exit Codes

Use standard POSIX / sysexits codes — never invent custom schemes. Full table is in `~/.claude/memory/script_conventions.md`. `--help` and `--version` always exit `0`; signal exits are `128 + signal` (SIGINT=130, SIGTERM=143).

For Rust, use the `sysexits` crate or define constants locally. `clap` exits `2` on parse errors automatically — do not override this. Use `std::process::ExitCode` (stable since 1.61) over `std::process::exit()` where possible to allow destructors to run.

## CLI Flags — Standard Interface

### Standard flags (all Rust TUI/CLI binaries)

| Flag | Short | Values | Behavior |
|------|-------|--------|----------|
| `--help` | `-h` | — | Print help and exit 0 — never escalate privileges |
| `--version` | `-v` | — | Print version and exit 0 — never escalate privileges |
| `--debug` | — | — | Enable debug output |
| `--color` | — | `auto` / `yes` / `no` | Control color output |

- `--color auto` detects terminal capability (default); `yes` forces color; `no` disables it and removes emojis from output.
- Both `--color auto` and `--color=auto` must work — clap handles this natively.
- `--help` and `--version` must never require root — always exit immediately with the requested output.

### NO_COLOR support

Every Rust TUI/CLI binary must honor the `NO_COLOR` environment variable ([no-color.org](https://no-color.org/)):

```rust
// Color resolution order (highest precedence first):
// 1. --color=no  or  --color=yes
// 2. NO_COLOR env var present (any value) → disable color and emojis
// 3. --color=auto → check atty::is(Stream::Stdout)
fn resolve_color(flag: &str) -> bool {
    match flag {
        "yes" => true,
        "no"  => false,
        _     => { // "auto"
            if std::env::var_os("NO_COLOR").is_some() {
                return false;
            }
            atty::is(atty::Stream::Stdout)
        }
    }
}
```

### Flag parsing — use `clap`

Use `clap` (derive API) for all argument parsing — never hand-roll. `clap` supports `--flag=value` and `--flag value` natively; `--help` and `--version` are generated automatically.

```rust
#[derive(Parser)]
#[command(name = env!("CARGO_PKG_NAME"), version, about, long_about = None)]
struct Cli {
    /// Color output: auto, yes, no
    #[arg(long, default_value = "auto", value_parser = ["auto", "yes", "no"])]
    color: String,

    /// Enable debug output
    #[arg(long)]
    debug: bool,
}
```

`clap` derive generates `-h`/`--help` and `-V`/`--version` by default. Override `-V` to `-v` with `#[command(version, short_flag = 'v')]` if needed to match the convention.

## Terminal Display — Alt Buffer and Crossterm

Any Rust binary that is a TUI or acts as a TUI must use the alternate screen buffer. Use `crossterm` — never write raw ANSI strings or shell out to `tput`.

Add to `Cargo.toml`:
```toml
crossterm = "0.28"
```

### Enter / leave functions

```rust
use crossterm::{
    cursor, execute,
    terminal::{self, EnterAlternateScreen, LeaveAlternateScreen},
};
use std::io::{self, Write};

fn enter_tui() -> io::Result<()> {
    terminal::enable_raw_mode()?;
    execute!(
        io::stdout(),
        EnterAlternateScreen,
        cursor::SetCursorStyle::BlinkingBar,
    )
}

fn leave_tui() -> io::Result<()> {
    execute!(
        io::stdout(),
        LeaveAlternateScreen,
        cursor::SetCursorStyle::DefaultUserShape,
    )?;
    terminal::disable_raw_mode()
}
```

`SetCursorStyle::BlinkingBar` is the I-beam blinking cursor. `DefaultUserShape` restores the terminal's configured default on exit.

### Cleanup guard

Implement `Drop` so the terminal is always restored, including on panic:

```rust
struct TuiGuard;

impl Drop for TuiGuard {
    fn drop(&mut self) {
        let _ = leave_tui();
    }
}
```

Call `enter_tui()` once at startup, then bind `let _guard = TuiGuard;` — the guard restores the terminal when it drops, regardless of exit path.

### ratatui shortcut

If using `ratatui`, use its init/restore helpers — they wrap crossterm and handle alt buffer, raw mode, and cursor automatically:

```rust
let mut terminal = ratatui::init();
// ... run app ...
ratatui::restore();
```

Do not manually call `enter_tui`/`leave_tui` when using ratatui — it manages setup and teardown.

### NO_COLOR

Suppress all terminal styling (colors, cursor changes) when `NO_COLOR` is set or `--color=no` is in effect. Check before emitting any `SetForegroundColor`, `SetAttribute`, or cursor style command. Use the `resolve_color` function from the CLI Flags section.

---

## Dependency Rules

- **No `*-sys` dynamic linkage** — vendored C deps must be statically linked; no `.so`/`.dylib`/`.dll` at runtime
- **No GPL/AGPL/LGPL without exception** — static linking would relicense the binary; requires explicit `{project_dir}/IDEA.md` exception
- **No `dlopen` or runtime extension loading** — unless `{project_dir}/IDEA.md` defines a hardened plugin contract
- **No CDN/network fetch on first run** — all assets embedded at build time; binary works air-gapped
- **`ring` is pre-approved** as a C-vendored exception (crypto)
- Prefer `rustls` over OpenSSL: `reqwest = { ..., features = ["rustls-tls"], default-features = false }`

## GUI Rules

GUI surfaces must support **both X11 and Wayland** as first-class backends — not one as fallback:
- Linux: GTK4 + libadwaita (`gtk4`, `libadwaita` crates)
- macOS: system frameworks (Cocoa/AppKit)
- Windows: Win32 or WinUI

## Static Binary Rules

- Linux: musl target for fully static binary (`x86_64-unknown-linux-musl`) where no native libs needed
- Windows: static CRT (MSVC or MinGW)
- macOS: link against system frameworks — no dylib vendoring
- `strip = true` in release profile handles symbol stripping

## Linting & Formatting

- **`cargo fmt`** — enforced; run `cargo fmt --check` in CI; a format failure is a build failure. Commit `rustfmt.toml` at project root if non-default settings are needed.
- **`cargo clippy`** — enforced; always run with `-D warnings` (warnings are errors); no `#[allow(...)]` suppressions without an explanatory comment on the line above
- Never suppress a clippy lint project-wide in `Cargo.toml` without documenting the reason in `{project_dir}/IDEA.md`

## Error Handling

- **`anyhow` for application (binary) crates** — use `anyhow::Result` as the return type in `main()` and internal functions that aren't public API; `context()` / `with_context()` to annotate errors with call-site meaning
- **`thiserror` for library crates** — define custom error types with `#[derive(thiserror::Error)]`; each variant carries a human-readable `#[error("...")]` message; no `anyhow` in library public API
- **No `unwrap()` or `expect()` in library or production hot-path code** — return `Result` instead; `unwrap()`/`expect()` are only acceptable in tests, examples, and build scripts where a panic is the right failure mode
- **`?` for propagation** — always use `?` to propagate errors up the call stack; never `.unwrap()` where a `?` would work
- **`Box<dyn Error>` is acceptable only in tests and throwaway scripts** — never in library public API or long-lived production code
- **Structured error context** — add context at every boundary crossing (IO, network, DB, subprocess); bare errors like `"No such file or directory"` are useless without context: prefer `fs::read(&path).with_context(|| format!("reading config from {path:?}"))`
- **No silent error swallowing** — never `let _ = fallible_call()` unless the error is genuinely irrelevant; document why with a comment when it is

```toml
# Cargo.toml — standard error handling deps
[dependencies]
anyhow  = "1"      # application crates
thiserror = "2"    # library crates (pick one, not both)
```

---

## Code Rules

- **No bare `cargo` on host** — all cargo invocations run inside Docker
- **Strip release binaries** — `strip = true` in `[profile.release]` (handled by Cargo) plus an explicit `strip {binary} 2>/dev/null || true` in the Makefile after copy, for toolchains that ignore the profile flag. Debug/dev builds (`cargo build` without `--release`) are never stripped — debug symbols are preserved intentionally
- **No `-musl` suffix** — never include `-musl` in the output binary name; schema is `{name}-{os}-{arch}` regardless of target triple (e.g. `x86_64-unknown-linux-musl` still outputs `{name}-linux-x86_64`)
- **Rust-only source** — no C/C++ in the binary (ring is the pre-approved exception)
- **Embed assets at build time** — use `include_bytes!`, `include_str!`, or the `built` crate; never load from filesystem at runtime
- **No hardcoded temp paths** — use `std::env::temp_dir()` and always prefix with `{project_org}/{internal_name}-XXXXXX` (`{internal_name}` is the frozen on-disk identifier; never `{project_name}` which may change). See `tempdir_conventions.md`.
