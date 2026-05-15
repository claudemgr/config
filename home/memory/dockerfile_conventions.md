---
name: Dockerfile conventions
description: Structure, labels, and patterns for CasjaysDev Dockerfiles
type: user
---

## Location

Always at `docker/Dockerfile` (and `docker/Dockerfile.dev` for dev variant). Never in the repo root — that is a forbidden location per `~/.claude/memory/project_forbidden_files.md`.

## Structure

Two-stage build: `builder` compiles the binary; runtime stage is minimal Alpine.

Section headers use `=` fence comments:
```dockerfile
# =============================================================================
# Build Stage - Compile Go binary
# =============================================================================
```

## Build Stage

```dockerfile
FROM golang:alpine AS builder

ARG TARGETARCH
ARG VERSION=dev
ARG BUILD_DATE
ARG VCS_REF

WORKDIR /build

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} go build \
    -ldflags "-s -w -X 'main.Version=${VERSION}' -X 'main.CommitID=${VCS_REF}' -X 'main.BuildDate=${BUILD_DATE}'" \
    -o /app ./src
```

- Always pass `TARGETARCH` for multi-arch builds
- `CGO_ENABLED=0` always (no exceptions — see NEVER rules)
- Rolling `golang:alpine` tag (never pinned for dev tooling)

## Runtime Stage

```dockerfile
FROM alpine:latest

ARG VERSION=dev
ARG BUILD_DATE
ARG VCS_REF
ARG LICENSE=MIT

# Static labels
LABEL maintainer="{org} <{org}@casjay.pro>" \
      org.opencontainers.image.vendor="{org}" \
      org.opencontainers.image.authors="{org}" \
      org.opencontainers.image.title="{name}" \
      org.opencontainers.image.base.name="{name}" \
      org.opencontainers.image.description="Containerized version of {name}" \
      org.opencontainers.image.url="https://github.com/{org}/{name}" \
      org.opencontainers.image.source="https://github.com/{org}/{name}" \
      org.opencontainers.image.documentation="https://github.com/{org}/{name}" \
      org.opencontainers.image.vcs-type="Git" \
      com.github.containers.toolbox="false"

# Dynamic labels (from ARGs)
LABEL org.opencontainers.image.licenses="${LICENSE}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.schema-version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}"
```

Static labels (names, URLs) and dynamic labels (version, date, revision) are always split into two separate `LABEL` blocks.

## Required Patterns

```dockerfile
# Install packages
RUN apk add --no-cache bash tini ...

# Create runtime directories
RUN mkdir -p /config /data/...

# Copy binary from builder
COPY --from=builder /app /usr/local/bin/{name}

# Copy rootfs overlay (mirrors Linux FHS)
COPY docker/rootfs/ /

# Copy Dockerfile into image for reference
COPY docker/Dockerfile /root/Dockerfile

# Make all binaries executable
RUN chmod 755 /usr/local/bin/*

# Expose internal port (always 80 internally)
EXPOSE 80

# Graceful shutdown signal
STOPSIGNAL SIGRTMIN+3

# Health check
HEALTHCHECK --start-period=10m --interval=5m --timeout=15s --retries=3 \
    CMD /usr/local/bin/{name} --status || exit 1

# tini as PID 1 with SIGTERM propagation
ENTRYPOINT [ "tini", "-p", "SIGTERM", "--", "/usr/local/bin/entrypoint.sh" ]
```

## Rules

- `tini` is always PID 1 — never use bare binary as entrypoint
- `ENTRYPOINT` always delegates to `entrypoint.sh` — never bypass (see NEVER rules)
- Internal port is always 80; host mapping is in `docker-compose.yml`
- `docker/rootfs/` mirrors Linux FHS — files placed there are `COPY`'d into the image at `/`
- `apk add --no-cache` — never without `--no-cache`
- No secrets, credentials, or `.env` values baked into the image

## Non-root User

Containers must not run as root unless the process genuinely requires it. Add to the runtime stage after `chmod`:

```dockerfile
# Create a non-root user for runtime
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
```

If the app must bind to port 80 (or other privileged ports): use `tini` + `setcap` or remap to an unprivileged port (≥1024) inside the container and map externally via `docker-compose.yml`. Exceptions (filesystem mounts, device access, service management) must be documented in `{project_dir}/IDEA.md`.

## entrypoint.sh

`docker/rootfs/usr/local/bin/entrypoint.sh` is the only file that should live between `tini` and the application binary. Minimum required content:

```bash
#!/usr/bin/env bash
# shellcheck shell=bash
# entrypoint.sh — container startup script
# Called by: tini → entrypoint.sh → app
# Add pre-start setup here (env checks, migrations, etc.)
exec "$@"
```

Rules:
- Must end with `exec "$@"` — replaces the shell process with the app so PID 1 signal handling is preserved
- Never `source` secrets or credentials — use environment variables injected at runtime
- Always executable (`chmod 755`)

## Dockerfile.dev

`docker/Dockerfile.dev` is the development variant. It shares the same base as the production build but adds dev tooling and omits release optimizations. Minimum required differences from `docker/Dockerfile`:

- Uses the builder stage image directly (`FROM golang:alpine` / `FROM rust:alpine`) — no separate runtime stage
- Includes dev dependencies (debugger, test runner, linter)
- Mounts source at runtime via compose volume — does not `COPY . .` for source (only for deps)
- Never pushed to a registry; for local use only
- No `USER` restriction needed (dev containers often need write access to the mounted source)

---

## Docker Compose

### File locations

All compose files live in `docker/`:
- `docker/docker-compose.yml` — production/human runtime
- `docker/docker-compose.dev.yml` — human development
- `docker/docker-compose.test.yml` — automated testing (the only one AI may use directly)

### Volumes — path resolution

Compose files always use `./volumes` for bind-mount paths. `./volumes` is **relative to the compose file's location** — so it resolves to `docker/volumes/` when the compose file lives in `docker/`. In standalone deployment the compose file is copied to a separate directory and `./volumes` resolves there.

Both `volumes/` and `docker/volumes/` are gitignored — runtime data is never committed.

### AI Docker Compose rules

- **NEVER** run `docker compose up` with `docker-compose.yml` or `docker-compose.dev.yml` — those are human-only
- **NEVER** mount `./volumes/` or any project-directory path at runtime when testing
- For automated testing: copy `docker/docker-compose.test.yml` to a temp dir and run from there — `./volumes` then resolves to `{tempdir}/volumes/`
- **NEVER** create or modify files in the project directory during testing

---

## .dockerignore

Same header format as `.gitignore`. Excludes everything that should not enter the Docker build context — version control, build artifacts, secrets, and local config.

**Build context is always the project root** — `docker build -f docker/Dockerfile .`. The `docker/` directory contains the Dockerfile and `rootfs/`; it is **never excluded** from the build context.

**Header:**
```
# .dockerignore created on MM/DD/YY at HH:MM
```

### Standard entries (all projects)

```dockerignore
# .dockerignore created on MM/DD/YY at HH:MM

# version control
.git/
.gitignore
.gitattributes

# local and secret config
.env
app.env
default.env
.claude/

# build artifacts
binaries/
releases/

# runtime volume data (never in image)
volumes/
docker/volumes/

# OS files
.DS_Store
Thumbs.db

# docs and meta (not needed in image)
*.md
LICENSE*
```

### Go project additions

```dockerignore
# Go toolchain cache (mounted at build time, not baked in)
vendor/
```

### Rust project additions

```dockerignore
# Rust build cache (rebuilt inside container)
target/
```

### What is NEVER excluded from Docker context

- `docker/` — contains the Dockerfile and `rootfs/`; always included, never excluded
- `src/` — all source code
- `go.mod`, `go.sum` — Go module files
- `Cargo.toml`, `Cargo.lock` — Rust manifest and lockfile
- `build.rs` — Rust build script
- `release.txt` — version string read at build time
