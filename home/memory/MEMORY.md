# Memory Index

- [Project file conventions](user_project_conventions.md) — AI.md=HOW, IDEA.md=WHAT, CLAUDE.md=loader, TODO.AI.md=tasks; template system in claudemgr
- [Execution hierarchy](user_execution_hierarchy.md) — VM>Incus>Docker>host; applies to everything including scriptmgr install scripts
- [Sensitive data rule](sensitive_data.md) — never add credentials to any repo; all repos public by default; personal dotfiles is the only exception
- [gitcommit path resolution](feedback_gitcommit.md) — never hardcode path; use `gitcommit` from PATH
- [Script conventions](script_conventions.md) — shebang/extension determines interpreter (bash vs sh vs zsh vs fish vs ps1 vs cmd); header template, section separators, vim modeline, `__` function prefix, `SCRIPTNAME_` variable prefix, comments above code, no UUOC, builtins over forks, grep `--` separator, exit codes (POSIX 0/1/2 + sysexits 64–78 + signal 128+N), getopt/zparseopts/argparse, NO_COLOR, documentation triple sync (help+man+completions)
- Lint agents: `script-lint` (bash/sh/zsh/fish), `go-lint` (Go projects), `rust-lint` (Rust projects) — invoke via Agent tool before committing
- [Project forbidden files](project_forbidden_files.md) — files/dirs that must never be created; README always README.md, LICENSE always LICENSE.md with 3rd-party attributions at bottom; allowed root files list
- [Standards reference](standards_reference.md) — HTTP status codes (RFC 9110), RFC 7807 error body, ISO 8601/RFC 3339 dates, semver, MIME/Content-Type, UUID v4/v7 (RFC 9562), HTTP security headers, TLS 1.2+ (RFC 8446), JWT RS256/ES256 (RFC 7519), OAuth2+PKCE (RFC 6749/7636), URL conventions (RFC 3986), pagination, Base64url (RFC 4648)
- [NEVER/ALWAYS rules](never_always_rules.md) — Argon2id/no bcrypt, no plaintext tokens, no machine-specific hardcoding, no JSON comments, singular dir names, Docker ENTRYPOINT/CI/cleanup rules, Go/Rust-specific constraints, memory safety (unsafe/fork-bomb/timeout/FD/unbounded-input rules)
- [Project type conventions](project_type_conventions.md) — rules follow project TYPE not language; server/desktop-gui/tui/cli/library/worker each have cross-language requirements; language files answer HOW, type answers WHAT
- [.gitignore conventions](gitignore_conventions.md) — header format, ignoredirmessage, standard entries (.gitcommit, .no_push, .no_git, .installed, OS files, dotenv files), project-type additions
- [Dockerfile conventions](dockerfile_conventions.md) — two-stage build, ARGs, OCI labels (static+dynamic split), tini entrypoint, rootfs overlay, chmod pattern, health check
- [Logging conventions](logging_conventions.md) — log files are pure raw text always (no ANSI, no emojis); access.log=Apache Combined, auth.log=syslog format, error.log=ISO8601+level, app.log=logfmt; Docker→stdout/stderr; logrotate config required for system services
- [Temp directory conventions](tempdir_conventions.md) — required path structure ({project_org}/{internal_name}-XXXXXX), per-language creation (shell/Go/Rust), OS vars, cleanup, AI rules
- [CI/CD conventions](cicd_conventions.md) — third-party SHA pinning, no pull_request_target, branch protection, SBOM+checksums, secret scanning, Dependabot, release integrity
- [Go conventions](go_conventions.md) — project layout (src/), Makefile targets (build/release/docker/test/dev/clean), golang:alpine rolling image, CGO_ENABLED=0, 8-platform binary naming, module cache mounts, CommitID ldflags var, ghcr.io registry
- [Rust conventions](rust_conventions.md) — project layout, Makefile targets, rust:latest rolling image, Docker-only cargo, release profile (opt-level=z/lto/strip/panic=abort), no *-sys dynamic linkage, GTK4+Wayland, rustls over OpenSSL
