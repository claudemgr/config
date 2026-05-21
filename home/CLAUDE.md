# Claude Rules

## Session Start
Before any work, sync `{project_dir}` with the remote:

1. `git status --porcelain` — check for uncommitted changes
2. If dirty: `git stash push -m "session-start auto-stash"`
3. `git pull`
4. If stashed: `git stash pop`
5. If `stash pop` conflicts: report the conflicting files and wait — never auto-resolve merge conflicts; let the user decide

If the pull fails (no remote, offline, branch diverged): report it and wait — never start work on a potentially stale tree.

## Global Memory
Read `~/.claude/memory/MEMORY.md` at session start and load referenced files as needed.

Provider-specific convention files (`github_conventions.md`, `gitlab_conventions.md`, `gitea_conventions.md`, `forgejo_conventions.md`) are loaded **on demand only** — detect the provider from `git remote get-url origin` and load only the matching file. Never pre-load all provider files.

## Compaction
Preserve: task goal · files changed · commands run · failing tests/errors · decisions · next actions.
Drop: old exploration paths · repeated logs · irrelevant discussion.

## Communication
- Truthful over agreeable — push back, correct, disagree when warranted; useful beats pleasant
- Ask if unsure; never guess or assume
- `?` ends a message → it's a question, not a command — answer it
- A message ending in `?` that contains an action verb ("Can you add X?", "Should we fix Y?", "Would it make sense to refactor Z?") is still a question — answer it, do not silently treat it as a command. Only act if the user re-sends without the `?` or explicitly says "yes" / "do it" / "go ahead"
- Multiple questions → numbered list; user replies "1: … 2: …"
- Match user's terminology exactly; never rename their domain language
- `{x}` = placeholder to substitute; `x` = literal text

## Spelling & Grammar
- Always fix clear spelling and grammar errors encountered in any file being edited — typos, missing letters, doubled letters, wrong verb forms (e.g. "not install" → "not installed", "successssful" → "successful"). Only correct when certain it is an error; never alter technical terms, intentional abbreviations, or domain-specific names.

## Drift Prevention

Drift = ignoring project-specific rules and reverting to global defaults or prior-session assumptions. It is the primary failure mode of long or compacted sessions.

**What drift looks like:**
- Reading `~/.claude/` files when inside a project that has source equivalents
- Writing outside `{project_dir}` without the user naming an external path
- Applying CI/CD syntax from a different provider than the one detected
- Using global fallback behavior because the project-specific rule was compacted away
- Expanding scope beyond what was asked ("while I'm here" changes)

**Self-check before any read or write:**
1. Is this path inside `{project_dir}`?
2. Does this project have its own version of this file (AI.md, CLAUDE.md, memory files)?
3. Am I applying a rule from THIS project's files, not a global assumption?
4. Is the working set still what the user defined — or have I quietly expanded it?

**When context has been compacted:** treat all rules as needing re-verification from the project's CLAUDE.md and AI.md. Do not assume the compacted summary preserved every constraint.

**If a SessionStart or PostCompact system message references a project_dir:** that path IS `{project_dir}` for this session — use it.

---

## Working Directory & Path Resolution

- **CWD is `$PWD`** — all relative paths (`AI.md`, `./src`, `./`) resolve from there
- **Absolute paths** (`/…`, `~…`) are taken as-is; never prepend CWD to them
- **`{project_dir}`** = `git rev-parse --show-toplevel` if inside a git repo; otherwise = the directory Claude was launched from (`$PWD` at session start)
- **`{project_name}`** = `basename {project_dir}` — always derived from the directory name, never hardcoded
- **`{project_org}`** = `basename $(dirname {project_dir})` — the parent directory of the project root
- **`{provider_name}`** = `basename $(dirname $(dirname {project_dir}))` — the provider directory two levels above the project. Projects live at `~/Projects/{provider_name}/{project_org}/{project_name}`. Known providers:
  | `{provider_name}` | `{provider_url}` | Notes |
  |---|---|---|
  | `github` | `github.com` | Use `gh` CLI |
  | `gitlab` | `gitlab.com` | Use `glab` CLI |
  | `gitbucket` | `gitbucket.com` | Use `tea` CLI |
  | `private` | `${GIT_PRIVATE_URL#*://}` | Strip scheme from env var; use `tea` CLI |
  | `local` | *(none)* | Local-only projects; may or may not be a git repo; never assume a remote |
- **Git gate** — if `{project_dir}/.git` does not exist, this is not a git repo. Never run any git operation (`git add`, `git commit`, `git status`, `git init`, etc.) on a non-git directory. Check for `.git` before any git command. `local` provider projects follow the same rule — `.git` must exist before any git op.
- **Project files override global**: if `{project_dir}/CLAUDE.md` or `{project_dir}/AI.md` exists, it is the source of truth and supersedes the global `~/.claude/CLAUDE.md` equivalent for that session
- **Stay inside `{project_dir}`** — all writes and edits must target paths within `{project_dir}` unless the user explicitly names an external path. Never reach outside the project tree (e.g. `~/.claude/`, `/etc/`, another repo) on your own initiative, even when a file there "should" be updated as a side effect of the task

## Code & Files
- **`cd` always uses absolute paths in executable contexts** — in scripts, Makefiles, CI steps, and Claude's own Bash tool calls always use `cd /full/path/to/dir`, never `cd relative/path` or `cd ../foo`. Exception: user-facing documentation (README, IDEA.md, inline examples) where a relative or `~/`-based path is clearer and more natural for the reader.
- **External commands always use `\command` (or `command cmd` in fish)** — prefix every external command invocation with `\` to bypass aliases and shell functions and call the real binary: `\curl`, `\git`, `\grep`, `\sed`, `\awk`, `\chmod`, etc. In fish shell use `command curl` (fish does not support `\` bypass). Applies in scripts, docs, AI.md examples, skill steps, and Claude's own Bash tool calls — everywhere an external command is invoked. This ensures the intended binary runs regardless of the user's shell aliases or wrapper functions.
- Read current file state before any edit
- Stay in scope — no unrequested refactors, reformats, or extras
- **Working-set discipline** — the active working set is established when the user says "we are working on X" or names a directory/file group. It stays in force until the user explicitly redirects. Never expand scope on your own initiative — not for related fixes, not for consistency, not for "while we're here" improvements. If a related issue is spotted outside the working set, note it but don't act on it. Exception: spelling/grammar fixes in files already being edited are always permitted
- **Fix completeness — propagate every fix** — when a pattern, convention, tool, or value is changed anywhere in the working set, find and fix ALL instances of it across the working set before committing. Use `grep -rn` to locate every occurrence. A fix that leaves surviving instances of the old pattern is a new bug, not a completed fix. This is NOT scope expansion — it is required completeness. The distinction: working-set discipline prevents adding new features or touching unrelated code; fix propagation requires that a change is applied everywhere it applies within scope. Partial fixes are worse than no fix because they create inconsistency.
- Match surrounding style: naming, indentation, patterns
- Use ecosystem idioms; run the community linter/formatter
- Use existing standards (POSIX exit codes, HTTP status codes, RFCs, semver, ISO 8601) — never invent wire protocols or error schemes
- Targeted edits only; full rewrites only when asked
- Required deps: just add them. Real choice between alternatives: ask first
- **No partially implemented code** — never commit a stub, a `TODO` placeholder inside logic, an unimplemented interface method, or code that calls a function that does not exist yet. Every line of committed code must work as written. If full implementation requires more scope than the current task allows, stop and discuss — do not commit partial work and move on.
- **No TODO/FIXME/HACK in committed code** — resolve before committing or open a tracked issue and reference it; never commit a reminder to future-you
- **No commented-out code** — delete it; git history is the undo mechanism
- **No comments in JSON** — JSON has no comment syntax; they break parsers
- **Singular directory names** — `handler/`, `model/`, `middleware/` not `handlers/`/`models/`; exception: tooling dirs follow community convention (`scripts/`, `tests/`, `completions/`)
- **Search before write** — any code that adds a value, entry, or setting to a file must first search for an existing occurrence across all candidate locations (base file + any drop-in directories). Replace in place if found; only create/append if not found anywhere. Exception: operations that explicitly overwrite the entire file are exempt. Applies to all languages and contexts — shell, Go, Rust, Python, Node, config management, CI scripts, everything. See `script_conventions.md` for the drop-in pattern reference table and shell examples.
- **Create parent directories before writing** — any code that creates or writes a file must ensure the parent directory exists first. A "no such file or directory" error from a missing parent is always a bug. Use the appropriate call for the language: `mkdir -p "$(dirname -- "$f")"` (shell) · `os.MkdirAll(filepath.Dir(p), 0o755)` (Go) · `fs::create_dir_all(p.parent().unwrap())?` (Rust) · `path.parent.mkdir(parents=True, exist_ok=True)` (Python) · `fs.mkdirSync(path.dirname(f), { recursive: true })` (Node).

## Sensitive Data
**Never add tokens, API keys, passwords, private keys, internal hostnames, or any credentials to a git repo** unless the user explicitly instructs it or has already committed them manually.

All git repos are treated as public by default — even private ones. The only exception is a personal dotfiles repo that is explicitly designated private and intended to hold credentials (env files, SSH keys, etc.). Context determines this — do not assume; if unclear, ask.

When credentials are needed at runtime: use environment variables, mounted secrets, or a secrets manager. Never hardcode. Never store in source.

**Paste services** (pastebin, GitHub Gist, paste.rs, etc.) are treated identically to public git repos — "private" pastes are still public. Never paste credentials, keys, internal config, or PII. Apply the same pre-flight check as a `git push` before posting anything.

- **Never store tokens in plaintext** — hash with SHA-256 before storing; never log raw tokens
- **System environment variables — read freely, overwrite by category** — reading is always fine and expected; use system vars as fallbacks anywhere (`RUN_USER="${SUDO_USER:-$USER}"`, `MYSCRIPT_FQDN="${MYSCRIPT_FQDN:-$HOSTNAME}"`). Use `{PROJECT_NAME}_VARNAME` for project-specific values — never generic `APP_`, `MY_`, etc. Overwriting rules by category:
  - **Shell mechanics — never overwrite:** `PS1`–`PS4`, `OPTIND`, `OPTARG`, `SHLVL`, and all `BASH_*`/`ZSH_*`/`FISH_*` vars. Exception: `IFS` may be temporarily changed — always save and restore, or scope to a subshell: `old_IFS="$IFS"; IFS=:; …; IFS="$old_IFS"` or `( IFS=:; … )`.
  - **Process identity — never overwrite:** `HOME`, `USER`, `LOGNAME`, `SHELL`, `UID`, `EUID`, `GID`, `PATH`, `PWD`, `OLDPWD`.
  - **Environment preferences — overwrite only when intentional:** `LANG`, `TZ`, `TERM`, `EDITOR`, `VISUAL`, `PAGER`, `HOSTNAME`, `HOST`. Store the value in a project-prefixed var first, then assign the system var from it when downstream processes must inherit it: `MYSCRIPT_LANG="${MYSCRIPT_LANG:-en_US.UTF-8}"; export LANG="${MYSCRIPT_LANG}"`. Never hardcode directly into the system var.
  - Full list in `script_conventions.md`.
- **Sane fallbacks** — every project var should have a sane default via `${VAR:-default}`; build compound defaults from earlier vars where it makes sense (`MYSCRIPT_ADMIN_EMAIL="${MYSCRIPT_ADMIN_EMAIL:-${MYSCRIPT_ADMIN_NAME}@${MYSCRIPT_FQDN}}"`). Exceptions — no `${VAR:-literal}` fallback: **secrets/credentials** (`MYSCRIPT_DB_PASSWORD`, `MYSCRIPT_API_KEY`, etc.) — generate with `__random_password`; if idempotent, save with `__save_credential` (perms `600`, `$RUN_USER:$RUN_USER` or `root:root`) and show once on first generation; **destructive targets** (`MYSCRIPT_BACKUP_DEST`, `MYSCRIPT_DEPLOY_TARGET`) and **multi-env service addresses** (`MYSCRIPT_DB_HOST`) — script must `exit 1` with a clear error if unset. Full patterns in `script_conventions.md`.
- **Exporting vars for external tools** — when an external app, library, or tool expects a specific variable name (e.g. `DATABASE_URL`, `PGPASSWORD`), bridge from the project var: `EXPECTED_APP_VAR="${PROJECT_NAME}_VAR"` and `export` only if required. Set the adapter immediately before the call that needs it — never at top-level unless the entire script is a thin wrapper.
- **Never hardcode machine-specific values** — hostname, IP, CPU count, memory size — always detect at runtime on the target machine. For **host** paths: never hardcode `/root`, `/home/jason`, or any specific username — use `$HOME`/`~/` in shell, `$(HOME)` in Makefile, `os.UserHomeDir()` in Go, `dirs::home_dir()` in Rust. Exception: paths inside containers or VMs where the user is known and fixed (e.g. `golang:alpine` always runs as root, so `/root/.cache/go-build` is correct inside that container).
- **Credential masking** — when displaying or logging a credential, preserve the key name and replace the value with `xxxxx`; never log partial values

## Project Files & Naming
- See `~/.claude/memory/project_conventions.md` for `{project_dir}/AI.md` / `{project_dir}/IDEA.md` / `{project_dir}/CLAUDE.md` roles, placeholder system, first-time setup flow, and directory layout
- See `~/.claude/memory/project_files.md` for file/directory rules including README.md content requirements (multi-platform install coverage), LICENSE.md naming, allowed root files, and what must never be created
- **`TODO.AI.md` hygiene** — complete each item fully — code working, tests passing, committed — before removing it and starting the next. Never clear an item while its work is still in progress, and never start a new item while the current one is incomplete. Remove items only when done; never leave them marked done and accumulating. **`PLAN.AI.md` hygiene** — delete the file once the work it describes is fully committed
- **`TODO.AI.md` PART loading** — each item carries a `Read:` line naming its source PART (e.g. `Read: AI.md PART 14`). Before starting any item: `grep -n "^# PART 14" AI.md` to get the start line, `grep -n "^# PART 15" AI.md` for the end, then read only that slice with `offset`/`limit`. Never load the full spec file to implement one item.

## Cleanup
- **Clean up immediately** — stop/remove every container, VM, volume, network, and temp file as soon as it is no longer needed; never leave them running until session end
- **Track what you start** — note name/ID before spinning anything up; cleanup is part of the same task
- Only remove project-specific resources; never broad sweeps (`docker system prune`, `rm -rf /tmp/*`)
- Full rules: `~/.claude/memory/execution_hierarchy.md`

## Verification & Safety
- Confirm before: `rm -rf`, force pushes, dropping tables/branches, anything irreversible
- **Never run unrequested destructive ops, even to "fix"** — stop and ask. (Ref: April 2026 PocketOS incident — agent wiped prod DB + 3 months of backups in 9s "fixing" a staging credential issue)
- **Never auto-bypass a hook block** — if a PreToolUse hook returns `BLOCKED:`, do NOT retry the same command. Tell the user what was blocked and what it would destroy; only the user decides whether to proceed
- Verify APIs/flags exist before using them; cite file:line for any code reference
- Run code before calling it done; iterate until verification actually passes
- **kill scoping** — `kill $PID` is only allowed when `$PID` was explicitly captured at launch (`PID=$!` or equivalent) in the current task. `pkill`/`killall` and `kill $(pgrep ...)` are always blocked by `protect-host.sh` — they target processes by name and can hit unrelated host processes. If you need to stop a process you didn't launch, stop and tell the user.
- **systemctl gate** — `systemctl status`, `is-active`, `is-enabled`, `cat`, `show`, and all `--user` variants are always OK without confirmation. `systemctl restart/stop/start/reload/disable/enable/mask` on host services (without `--user`) require explicit user confirmation before running — these affect running services and can disrupt other workloads. `protect-host.sh` blocks these automatically.

**Memory Safety — these apply to every line of code in every language:**
- `unsafe` (Rust) / `import "unsafe"` (Go) requires a justification comment at the call site and a note in `{project_dir}/IDEA.md`
- Never spawn unbounded goroutines/threads — always cap with a semaphore, worker pool, or context cancellation
- Never spawn processes inside an unthrottled loop — every subprocess spawn must have a concurrency limit
- Never call `ulimit -u unlimited`, `setrlimit(RLIM_INFINITY)`, or equivalent — raise limits to a specific documented ceiling only
- Every network call, DB query, subprocess wait, channel receive, and lock acquisition must have a timeout or deadline — infinite block = eventual hang
- Every opened file, socket, or pipe must be closed — `defer f.Close()` (Go), RAII/`Drop` (Rust), `trap`/explicit close (shell)
- Never `rm -rf "$VAR/"` without a `[ -n "$VAR" ]` guard; never `DROP TABLE` or `DELETE FROM` without a `WHERE`
- Size-cap all untrusted input before buffering — no `ReadAll`/`read_to_string` on an unbounded network stream without a `LimitedReader`/`take()` guard

## Self-Validation
- **Verify against ground truth** — UI: compare to design/screenshot. Logic: compare to expected output. Data: spot-check a sample
- **Iterate until passing** — don't stop at "compiles"; keep going until success criteria are met
- **Define success up front** — before non-trivial work, state what "done" looks like (test passes, output matches, lint clean)
- **Add tests for new behavior** — for non-trivial functionality: add a test that fails before and passes after, then run it
- **One run, then fix** — run build/test once per change; don't loop on flaky failures without a hypothesis

## Build & Execution
- **Project toolchain image first** — before running any build, test, lint, or tool command, check whether the project has a `docker/Dockerfile.build`. If it does, the project ships a toolchain image tagged `{project_org}/{project_name}:build` (typically `ghcr.io/{org}/{name}:build`). Pull and run inside that image — never on the host, never in a generic `golang:alpine` / `rust:alpine` / `node:alpine` container. Generic alpine variants are only fallback for projects without `docker/Dockerfile.build`. This is consistent with the "no host toolchain" rule below. If the image is not in the registry, do not build it inline — stop and tell the user to trigger `build-toolchain.yml` via `workflow_dispatch`.
- **Dockerfile.build bootstrap order** — when adding `docker/Dockerfile.build` to a project: commit it alone first, trigger `build-toolchain.yml` via `workflow_dispatch`, verify the image is in the registry, then commit `ci.yml`/`release.yml`. Never commit a CI workflow that uses the build image before the image exists.
- Execution hierarchy: QEMU/KVM > Incus > Docker > host — Docker uses the project's `:build` toolchain image when present, otherwise official alpine variants (`golang:alpine`, `rust:alpine`); Incus for systemd/distro tests; QEMU/KVM for full OS. See `~/.claude/memory/execution_hierarchy.md`
- Dev images: rolling tags — never pinned
- Target `linux/amd64` + `linux/arm64` by default
- Builds are reproducible in containers; nothing depends on host-installed toolchain
- **Container startup chain: `tini → entrypoint.sh → app`** — never override or bypass; all startup customization goes in `entrypoint.sh`
- `docker-compose.yml` must have hardcoded sane defaults and work with zero `.env` — users override by editing the file, not by creating `.env`
- **Port binding** — always bind to `172.17.0.1:{port}:{internal_port}` (Docker bridge gateway). Never `0.0.0.0`, `localhost`, or `127.0.0.x` — `0.0.0.0` exposes to all interfaces; `127.0.0.x` is host-only and excludes container-to-host reach. When generating a new `docker-compose.yml` or any service config, pick a random unused port in the `62000`–`64999` range using `__random_port` (detected at runtime). When the port must survive between runs — idempotent scripts, docker-compose with a reverse proxy, any service where the port must stay stable — save it to the project's config file (`.env`, `settings.conf`, `docker-compose.yml`, etc.; project decides) on first generation and reload on subsequent runs. Use `__save_credential` / `__load_credential` for `KEY=VALUE` stores. Structured files (compose, nginx config) are generated once with the chosen port and not regenerated unless explicitly requested.
- **Reverse proxy vhost** — when a service needs a host-level nginx reverse proxy, generate the vhost at `/etc/nginx/vhosts.d/{hostname}.conf` following the template in `~/.claude/memory/nginx_conventions.md`. TLS cert always at `/etc/letsencrypt/live/domain/` (literal `domain` directory). If the cert/key must be copied elsewhere, create a Let's Encrypt deploy hook — see `nginx_conventions.md`.
- Cleanup: never remove base images (`golang`, `alpine`, `ubuntu`, etc.) — only `{project_org}/{internal_name}:*` images
- Temp dirs: never hardcode `/tmp`; use `$TMPDIR`/`os.TempDir()`/`std::env::temp_dir()`; always org-prefixed — see `~/.claude/memory/tempdir_conventions.md`
- **`docker run` must use `--rm -it --name {project_name}-XXXX`** — every build/test container must self-remove on exit, be interactive-capable, and carry a traceable name; `XXXX` is a random suffix (Makefile: `$$(tr -dc 'a-z0-9' </dev/urandom | head -c8)`); no orphaned containers
- **`XXXX` vs `XXXXXX` — two different conventions, both correct.** `XXXX` (literal 4-char token in docs) denotes the 8-char random suffix produced by `tr -dc 'a-z0-9' </dev/urandom | head -c8` for docker container / incus instance names. `XXXXXX` (literal 6 X's) is the `mktemp` placeholder — `mktemp` replaces each X with a random char, so a 6-X suffix yields a 6-char random string. Different mechanisms, different contexts; do not normalize one to the other.
- **Toolchain containers must mount their package cache** — declare cache paths with `?=` (e.g. `NPM_CACHE ?= $(HOME)/.npm`) so host env vars with custom locations are honored; `@mkdir -p $(CACHE_DIR)` before every `docker run`; mount with `-v $(CACHE_DIR):/container/path`; see `~/.claude/memory/makefile_conventions.md` for the full table
- **Test container network isolation** — always create a named bridge network for tests; never use the default bridge or `--network host`

## UI/UX
- Any UI work — web, desktop, mobile, TUI — must be approached with designer-level intent. "It works" is not enough; aim for clarity, consistency, and delight.
- Dark mode is the default. Every UI must support dark / light / auto (follows OS preference). Never hardcode colors — use CSS custom properties (web) or a shared theme struct (desktop/TUI).
- For non-trivial UI tasks, invoke the `designer` agent. See `~/.claude/memory/ui_ux_conventions.md` for the full design system.

## Security by Design

Security is first-class from day one — never bolted on after. It must also be user-friendly: friction-free for honest users, hard for attackers.

- **Secure default** — the safe path is the easy path. Insecure options require explicit opt-in; never make the user work harder to be secure
- **Fail closed** — when in doubt, deny and explain clearly; never silently allow
- **Least privilege** — request only the permissions actually needed; drop them as soon as they are no longer needed
- **Explicit trust boundaries** — document what is trusted (authenticated session, signed payload, internal network) and what is not; never assume
- **No security through obscurity** — assume the attacker knows your code, your schema, and your algorithm choices; security must hold even so
- **Defense in depth** — no single control is the last line; layer authentication, authorization, input validation, output encoding, and rate limiting independently
- **Rate-limit all auth endpoints** — login, password reset, OTP, token refresh — with exponential backoff and lockout; brute force is always in scope
- **Audit log security-relevant events** — auth success/failure, permission changes, admin actions, data exports; logs are append-only and never contain raw credentials
- **No security theater** — do not impose friction that punishes honest users without meaningfully stopping attackers (e.g. forced password rotation on a schedule unrelated to breach, CAPTCHA on low-risk flows, MFA on non-sensitive pages)
- **Clear security errors** — when a request is blocked or fails a security check, tell the user what happened and what to do next; never return a bare 403 or "access denied" with no context
- **Enumeration mitigation** — identical message and timing for "wrong password" vs "no such user"; opaque IDs over sequential integers; never confirm account existence on password reset; see `~/.claude/memory/security_conventions.md`
- **GeoIP is a signal, not a gate** — country blocks are risk signals only; never use GeoIP as the sole access control; VPNs bypass it trivially; see `~/.claude/memory/security_conventions.md`
- **CVE pre-flight** — run `govulncheck` (Go) / `cargo audit` (Rust) / `npm audit` (Node) before adding any dependency and before committing; never ship a critical/high CVE in direct deps; see `~/.claude/memory/security_conventions.md`

## Project Defaults
- License: MIT · Single self-contained binary · First-run works with zero config
- No feature gating; all functionality available to all users
- Telemetry opt-in only; never hardcode tracking IDs or site keys
- Web UIs: mobile-responsive from day one
- Security in code: parameterized queries, constant-time comparison, CSRF/XSS/SSRF/IDOR/path-traversal guards
- **Password hashing: Argon2id only** — never bcrypt, never scrypt, never MD5/SHA for passwords

## Language Constraints

**Go:**
- `CGO_ENABLED=0` always — pure Go, no C, no exceptions
- No `-musl` suffix on Alpine/musl builds — omit it
- Use project `config.ParseBool()` not `strconv.ParseBool()` (handles 40+ variations)
- Never run `go` directly on host — always via `make dev` / `make test` / `make build` (Docker internally)
- Never depend on host cron or systemd timers — use a built-in scheduler (`robfig/cron`, `go-co-op/gocron`, or a ticker loop)
- Server projects: Go templates rendered server-side only — no client-side rendering

**Node / TypeScript:**
- `strict: true` in `tsconfig.json` — no `any` without a comment explaining why
- ESLint + Prettier required; `eslint --max-warnings 0` in CI — zero tolerance
- Never `require()` in TypeScript — `import` only; enable `"moduleResolution": "bundler"` or `"node16"`
- Never `process.exit()` in library code — only in CLI entry points
- `package.json` scripts must work without global installs — use `npx` or `./node_modules/.bin/`
- `npm ci` in Docker uses the `NPM_CACHE` mount (`~/.npm`) automatically — no extra flags needed; `npm install` for local dev only
- No CDN scripts in HTML — bundle all assets at build time (no `<script src="https://..."`)
- Never log `req`, `res`, or `ctx` objects — they contain credentials; log only safe fields

**Python:**
- `python3 -m venv` or `uv` for isolation — never install project deps into the system Python
- Type hints required on all function signatures; run `mypy --strict` or `pyright` in CI — type errors are build failures
- `ruff` for both linting and formatting — replaces flake8, isort, black; zero warnings in CI
- No `import *` — explicit imports only
- `pathlib.Path` over `os.path` for all filesystem operations
- No `eval()`, `exec()`, or `__import__()` with untrusted input — these are arbitrary code execution

**Rust:**
- Never run `cargo` directly on host — all cargo invocations run inside Docker
- No `*-sys` dynamic linkage — vendored C deps must be statically linked; no `.so`/`.dylib`/`.dll` at runtime
- No GPL/AGPL/LGPL dependencies without an explicit `{project_dir}/IDEA.md` exception — static linking relicenses the binary
- No `dlopen` or runtime extension loading unless `{project_dir}/IDEA.md` defines a hardened plugin contract
- No CDN or network fetch on first run — all assets embedded at build time

## Output
- No preamble, no reflexive agreement, no closing recap
- **Tight output budget** — status updates and requested summaries: 1–3 sentences max. No headers/bullets/sections unless the task requires structured output
- Show diffs, not prose retellings of changes
- No emojis in code or inline tool output unless asked
- Emojis **are appropriate** in READMEs, documentation, and commit messages where they aid readability or navigation
- **No AI attribution** — no `Co-Authored-By:`, AI-tool trailers, or "Generated with X" footers anywhere
- Next step is clear → do it. Pause only for genuine blockers or destructive-op confirmation

## Tool Preference
- Always use the right tool for the job if installed: `jq` for JSON, `yq` for YAML, `bc` for math, `grep`/`sed`/`awk` for text, `git` for version control, etc.
- **Provider CLIs** — prefer over raw `curl` for provider API operations. If not installed, download and install the binary before use — never fall back to raw `curl` for provider operations when a CLI exists for that provider:
  - `gh` (GitHub CLI, Apache-2.0) — issues, PRs, releases, repo ops on GitHub; latest release: `https://github.com/cli/cli/releases/latest`
  - `glab` (GitLab CLI, MIT) — same operations on GitLab; latest release: `https://gitlab.com/gitlab-org/cli/-/releases`
  - `tea` (Gitea CLI, MIT) — Gitea and Forgejo (compatible API); latest release: `https://gitea.com/gitea/tea/releases`
  - **Auto-install when missing** — detect arch (`uname -m`: `x86_64`→`amd64`, `aarch64`→`arm64`), download the latest Linux binary from the provider's release page, install to `/usr/local/bin` if running as root or `sudo -n true 2>/dev/null` succeeds, otherwise `~/.local/bin`. Always `mkdir -p` the target dir and `chmod +x` after download. Confirm with the user before installing to `/usr/local/bin` via sudo.
  - `curl` is acceptable when there is a reason: CLI not authenticated/configured, operation is simpler or faster without the CLI, public endpoint that needs no auth, or operation has no CLI equivalent
- **`act`** (nektos/act, MIT) — validate and run GitHub Actions workflows locally before pushing. Install: `setupmgr act`. Key uses: `act --list -W {file}` to validate a workflow file (parses YAML + resolves job graph, exits non-zero on errors); `act -j {job}` to run a specific job locally. **Required pre-commit**: if `.github/workflows/` files are staged, `act --list` must pass on each before `gitcommit` runs — the `validate-workflows.sh` hook enforces this automatically. Never use `act` to bypass CI gates — it is a pre-push verification tool only.
- Use `python3` only when no purpose-built tool can handle the task cleanly
- **curl default:** `curl -q -LSs {url}` — `-q` suppresses config file, `-L` follows redirects, `-S` shows errors, `-s` suppresses progress meter. Never add `-f`/`--fail` by default — it suppresses the response body on HTTP errors, hiding diagnostic information. Only add `-f` in scripts or Makefiles where silent failure and a non-zero exit code are explicitly the right behaviour. Only add `-#` (or drop `-s`) when a progress bar is explicitly needed.
- **wget default:** `wget -q {url}` — `-q` suppresses all output except errors. Only omit `-q` or add `--show-progress` when a progress bar is explicitly needed.
- **grep default:** always `grep {flags} -- {query}` — `--` prevents a query starting with `-` being treated as a flag. Never use `egrep`, `fgrep`, or `rgrep` — use `grep -E`, `grep -F`, `grep -r` instead. This applies to every grep invocation, including in Bash tool calls.
- **Images:** always convert before reading — max 1280px longest side, WebP target, fallback chain `convert` → `ffmpeg` → `vips` → original. URL images: curl to tempdir first, then convert, then read. See `~/.claude/memory/image_conventions.md`.

## Token & Context Discipline
- **Use the explorer subagent for broad codebase searches** — searches spanning 3+ files, unknown locations, or multiple naming conventions: dispatch via explorer. Don't grep-walk in main context — search results bloat conversation history forever. Direct grep/find is fine for one specific known target
- **Read files narrowly** — for files >500 lines: use `offset`/`limit`, or grep first to find the slice. Don't load 2000 lines when you need 50
- **No speculative reads** — only read files the current task directly requires. Do not open adjacent files because they "might be relevant." If a file turns out to be needed, read it then.
- **Don't re-read after editing** — Edit/Write errors if the change fails; no verification re-read needed. The one explicit exception: `COMMIT_MESS` must be written from the actual `git status`/`git diff` output (never from memory), then re-read once to verify it matches the diff before running `gitcommit` — a push is irreversible and COMMIT_MESS must reflect actual state, not assumptions.
- **Don't spawn agents for small tasks** — if the work fits in 2–3 direct tool calls, do it inline. Agent overhead (launch, context transfer, result relay) costs more tokens than the task itself for simple lookups, single-file edits, or short shell commands.
- **Plan mode is for genuine ambiguity, not file count** — invoke plan mode when requirements are unclear or the approach has real tradeoffs, not simply because a task touches 3+ files. Mechanical changes across many files (rename, find-replace, bulk fix) do not need a plan.
- **Parallelize independent research** — multiple independent questions: spawn agents in parallel (single message, multiple Agent calls)

## Agent Usage
- **Haiku for trivial tasks** — renames, format conversions, single-line edits, simple lookups, mechanical refactors: spawn via `Agent` with `model: "haiku"`. Reserve Sonnet for judgment, multi-file coordination, or design decisions.
- **Agents never commit** — agents make file edits and report back; the main instance reviews the actual diff, writes `COMMIT_MESS`, and runs `gitcommit`. Never instruct an agent to write a commit message or invoke `gitcommit`. An agent that autonomously commits bypasses the diff-review step that catches errors before an irreversible push.

## Autonomy
- Action commands ("fix all issues", "run the tests", "deploy") → execute fully without step-by-step confirmation
- "Run X" pre-authorizes X and its entire workflow (subcommands, loops, retries, pipes) for this session
- Write/Edit allowlists are defined in `{project_dir}/.claude/settings.json` `permissions.allow` — the following `{project_dir}/`-relative paths are pre-approved: `.git/COMMIT_MESS`, `.git/COMMIT_EDITMSG`, `CLAUDE.md`, `AI.md`, `SPEC.md`, `IDEA.md`, `TODO.AI.md`, `TODO.md`, `PLAN.AI.md`, `PLAN.md`, `.claude/settings.json`, `.claude/settings.local.json`, `.env`/`app.env`/`default.env`, and `.no_push`. Destructive Bash ops are gated separately by `protect-host.sh`

## Task Dependency Ordering
When executing a task list, dependency graph takes priority over label order. Numbered/lettered sequence is a tiebreaker only — never an execution mandate.
- Scan any task list for stated dependencies ("X before Y", "requires X", "needs X first") before starting
- Topological-sort the graph; use label order only to break ties among tasks at the same depth
- A task is only "ready" when all its prerequisites are complete
- If a dependency is ambiguous, ask — never assume order
- For non-trivial graphs (3+ dependencies), document the resolved order at the top of TODO.AI.md or PLAN.AI.md

**Example:** tasks 1, 2, 3 and a, b, c where c→2 and a→2: correct order is `1, a, c, 2, b, 3` — not `1, 2, 3, a, b, c`.

## Commit Workflow
`git commit` and `git push` are denied. `gitcommit` (resolved from PATH) is the only commit path — signs, stages, commits, and pushes in one invocation. Workflow is pre-approved; commit without asking, but verify the message first. **Never read the `gitcommit` script file** — it is pre-approved and trusted; reading it before invoking is a speculative read violation.

**Only valid invocation:** `gitcommit --dir {dir} all`
- `{dir}` = absolute path to the project root
- `all` is the only command — other subcommands commit one file at a time
- Never use `-m` / `--message` — bypasses the message file
- If the GitHub remote repo does not exist, `gitcommit` creates it automatically and sets the upstream — no manual `gh repo create` or `git remote set-url` needed

**Pre-commit sequence:**
1. `git status --porcelain` + `git diff --stat` — see actual changes
2. Write `{dir}/.git/COMMIT_MESS` directly from that output — every changed file, each change described, nothing missing. Never write from memory of what you think you changed; always derive from the diff you just ran.
3. Re-read `COMMIT_MESS` and compare against the diff — verify every changed file is listed, every description is accurate. If anything is missing or wrong, rewrite the file and re-read again.
4. Run `gitcommit --dir {dir} all` — wrapper deletes `COMMIT_MESS` on success

**Message format:** `{emoji} Title (≤64 chars) {emoji}` + blank line + body + `- path: change` bullets per file

Emoji map: ✨ feat · 🐛 fix · 📝 docs · 🎨 style · ♻️ refactor · ⚡ perf · ✅ test · 🔧 chore · 🔒 security · 🗑️ remove · 🚀 deploy · 📦 deps

**Cadence:** one logical change per commit. Unrelated subsystems → split. Mid-task inconsistent state → do NOT commit.

**Lint gate:** run the appropriate agent before committing — `script-lint` for shell, `go-lint` for Go, `rust-lint` for Rust. Do not commit if the linter reports violations.

**Workflow gate:** if `.github/workflows/` files are staged, run `act --list -W {file}` on each before writing `COMMIT_MESS`. Fix every error before proceeding. The `validate-workflows.sh` PreToolUse hook enforces this automatically and will block `gitcommit` if any staged workflow fails validation.

**CI/CD:** third-party GitHub Actions must be pinned to a full commit SHA — never a tag (`uses: actions/checkout@v4` is forbidden; `uses: actions/checkout@{sha}` is required).

**Push is immediate and irreversible.** To skip: `touch .no_push` at repo root (confirm with user first). If push fails offline: run `gitcommit push` later — do NOT recreate `COMMIT_MESS`.
