---
name: NEVER/ALWAYS rules
description: Consolidated NEVER/ALWAYS rules from the Go and Rust project templates, covering only what is not already defined in CLAUDE.md or other memory files
type: user
---

## Cross-reference — already defined elsewhere

These are intentionally NOT repeated here:

| Rule | Defined in |
|------|-----------|
| No AI attribution | `CLAUDE.md` → Output |
| No plain `git commit`/`git push` | `CLAUDE.md` → Commit Workflow |
| No hardcoded credentials/secrets | `CLAUDE.md` → Sensitive Data |
| No feature gating or premium tiers | `CLAUDE.md` → Project Defaults |
| Container-only builds | `user_execution_hierarchy.md` |
| Cleanup: project resources only | `CLAUDE.md` → Cleanup |
| No `.env`/`app.env`/`default.env` committed; `.env.example`/`.env.sample` variants are allowed; no Dockerfile in root | `project_forbidden_files.md` |

---

## Memory Safety

| Rule | Detail |
|------|--------|
| **NEVER unsafe without justification** | Rust: every `unsafe` block requires a comment at the site explaining why it is sound + an IDEA.md note. Go: `import "unsafe"` requires a documented reason in IDEA.md |
| **NEVER unbounded goroutines/threads** | Always cap concurrent goroutines, threads, or worker pools — use semaphores, worker pools, or context cancellation. Unbound spawning is a fork-bomb in slow motion |
| **NEVER fork bombs** | No process spawning inside an unthrottled loop. Every subprocess spawn must have an explicit concurrency limit. The canonical shell fork bomb (`:(){ :|:& };:` or equivalent) and all its variants are absolutely forbidden |
| **NEVER remove process limits** | Never call `ulimit -u unlimited`, `ulimit -n unlimited`, `setrlimit` to RLIM_INFINITY, or equivalent. If a limit must be raised, raise it to a specific documented ceiling, not unlimited |
| **NEVER block without a timeout** | Every network call, database query, subprocess wait, channel receive, and lock acquisition must have a timeout or deadline. Infinite block = eventual hang |
| **NEVER leave file descriptors open** | Every opened file, socket, or pipe must be closed — use `defer f.Close()` (Go), RAII/`Drop` (Rust), or `trap`/explicit close (shell). FD leaks become resource exhaustion under load |
| **NEVER unnamespaced destructive paths** | `rm -rf /`, `rm -rf ~`, `rm -rf $UNSET_VAR/`, `DROP TABLE`, `DELETE FROM` with no `WHERE` — always scope to the project's own named resource. Guard with `[ -n "$VAR" ]` before any `rm -rf "$VAR/"` |
| **NEVER load untrusted input into memory unbounded** | Streams from untrusted sources must have a size cap before buffering. No `ioutil.ReadAll` / `std::io::read_to_string` on an unbounded network stream without a `LimitedReader` / `take()` guard |

## Security

| Rule | Detail |
|------|--------|
| **NEVER bcrypt** | Use **Argon2id** for all password hashing — no exceptions |
| **NEVER store tokens in plaintext** | Hash with SHA-256 before storing; never log raw tokens |
| **NEVER hardcode machine-specific values** | Hostname, IP address, CPU count, memory size — always detect at runtime on the target machine |

## Code Style

| Rule | Detail |
|------|--------|
| **NEVER add comments to JSON** | JSON has no comment syntax; comments break parsers |
| **NEVER plural directory names** | Source/package dirs are singular: `handler/`, `model/`, `middleware/` — not `handlers/`, `models/`. Exception: tooling dirs follow community convention and may be plural (`scripts/`, `tests/`, `binaries/`, `completions/`) |

## Docker

| Rule | Detail |
|------|--------|
| **NEVER modify ENTRYPOINT or CMD** | All container customization goes in `entrypoint.sh` |
| **NEVER use Makefile in CI/CD** | CI workflows use explicit commands with all env vars inlined — Makefile is for local dev only |
| **NEVER require .env files at runtime** | `docker-compose.yml` must have hardcoded sane defaults; users can override by editing the file directly, not by creating `.env` |
| **NEVER remove base images** | Only remove `{project_org}/{internal_name}:*` images; never remove `golang`, `alpine`, `ubuntu`, etc. *(Docker specialization of `CLAUDE.md → Cleanup`)* |
| **NEVER touch other projects' containers/volumes** | Only stop/remove containers named after this project *(Docker specialization of `CLAUDE.md → Cleanup`)* |

## Temp Directories

| Rule | Detail |
|------|--------|
| **NEVER hardcode `/tmp`** | Use `os.TempDir()` (Go), `std::env::temp_dir()` (Rust), or `mktemp` in scripts |
| **NEVER bare `mktemp -d`** | Always use org prefix: `mktemp -d /tmp/{project_org}/{internal_name}-XXXXXX` |
| **ALWAYS** | Structure: `/tmp/{project_org}/{internal_name}-XXXXXX/` for all temp/test/runtime data |

## Go-Specific

| Rule | Detail |
|------|--------|
| **NEVER CGO** | `CGO_ENABLED=0` always — pure Go, no exceptions |
| **NEVER `-musl` suffix** | Alpine/musl builds are not musl-specific; omit the suffix |
| **NEVER `strconv.ParseBool()`** | Use the project's `config.ParseBool()` which handles 40+ variations |
| **NEVER run `go` directly** | Always via `make dev` / `make test` / `make build` (Docker internally) |
| **NEVER external cron** | Use the built-in scheduler (see project AI.md PART 19) |
| **NEVER client-side rendering** | Server-side Go templates only |

## Rust-Specific

| Rule | Detail |
|------|--------|
| **NEVER bare `cargo` on host** | All cargo invocations run inside Docker |
| **NEVER `*-sys` dynamic linkage** | Vendored C deps must be statically linked; no system-installed `.so`/`.dylib`/`.dll` at runtime |
| **NEVER GPL/AGPL/LGPL without exception** | Static linking would relicense the binary; requires explicit IDEA.md exception |
| **NEVER `dlopen` or runtime extension loading** | Unless IDEA.md defines a hardened plugin contract |
| **NEVER CDN/network fetch on first run** | All assets embedded at build time |
