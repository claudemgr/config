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
| No `.env` files, no Dockerfile in root | `project_forbidden_files.md` |

---

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
