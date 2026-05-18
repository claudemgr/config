---
name: Dockerfile conventions
description: Structure, annotations, and patterns for CasjaysDev Dockerfiles
type: user
---

## Location

Always at `docker/Dockerfile` (and `docker/Dockerfile.dev` for dev variant, `docker/Dockerfile.build` for the toolchain image). Never in the repo root — that is a forbidden location per `~/.claude/memory/project_files.md`.

## Dockerfile.build — Toolchain Image

`docker/Dockerfile.build` is the toolchain image. It is tagged `{project_org}/{project_name}:build` and contains the entire toolchain required to build, test, lint, and scan the project (compiler, test runner, linter, vulnerability scanner, SBOM tool, etc.).

### Rules

- **Built monthly** via a dedicated `.github/workflows/build-toolchain.yml` (and equivalent on other providers). Pushed to the registry on schedule and on `workflow_dispatch`.
- **Must exist before any workflow runs.** CI workflows do NOT install tools inline — they pull this image. If the build image is absent, workflows fail fast with a clear error. Never install the toolchain in a workflow step; put it in this image.
- **Tag is always `:build`** — never pinned to a version tag; always the latest monthly build.
- **Fork-portable** — the workflow that builds this image uses `github.repository_owner` / `github.event.repository.name` (or equivalent provider variables), never hardcoded org or project name.

### Minimum Dockerfile.build structure

```dockerfile
FROM golang:alpine

RUN apk add --no-cache \
    bash \
    git \
    make \
    && go install golang.org/x/vuln/cmd/govulncheck@latest \
    && go install github.com/cyclonedx/cyclonedx-gomod/cmd/cyclonedx-gomod@latest

WORKDIR /build
```

Swap `golang:alpine` for `rust:alpine` (plus `cargo-audit`, `cargo-cyclonedx`) on Rust projects. Every tool the project's CI uses must be pre-installed here.

### Monthly build workflow (GitHub Actions pattern)

```yaml
name: Build Toolchain Image
on:
  schedule:
    - cron: '0 4 1 * *'  # 1st of each month at 04:00 UTC
  workflow_dispatch:

permissions:
  contents: read
  packages: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd  # v6.0.2

      - uses: docker/login-action@4907a6ddec9925e35a0a9e82d7399ccc52663121  # v4.1.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/setup-buildx-action@4d04d5d9486b7bd6fa91e7baf45bbb4f8b9deedd  # v4.0.0

      - uses: docker/build-push-action@bcafcacb16a39f128d818304e6c9c0c18556b85f  # v7.1.0
        with:
          context: .
          file: docker/Dockerfile.build
          push: true
          tags: ghcr.io/${{ github.repository_owner }}/${{ github.event.repository.name }}:build
```

---

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
```

**No `LABEL` blocks in the Dockerfile.** Metadata is applied as OCI annotations at build time — see [OCI Annotations](#oci-annotations) below. `LABEL` applies only to the individual per-platform image layer; multiarch manifest indexes do not inherit labels, so they appear missing on multiarch pulls. Annotations are the correct mechanism for multiarch image metadata.

## OCI Annotations

All image metadata uses OCI annotations applied via `--annotation` flags on `docker buildx build`, not `LABEL` in the Dockerfile. Annotations attach to the manifest index (the multiarch top-level manifest) and are visible on all platforms.

### Annotations passed at build time

Split into static (names, URLs) and dynamic (version, date, revision) — pass both sets to every `docker buildx build` invocation:

**Static annotations** (substituted from build-time variables — never hardcoded):
```
--annotation "maintainer={project_org} <{project_org}@casjay.pro>"
--annotation "org.opencontainers.image.vendor={project_org}"
--annotation "org.opencontainers.image.authors={project_org}"
--annotation "org.opencontainers.image.title={project_name}"
--annotation "org.opencontainers.image.base.name={project_name}"
--annotation "org.opencontainers.image.description=Containerized version of {project_name}"
--annotation "org.opencontainers.image.url=https://github.com/{project_org}/{project_name}"
--annotation "org.opencontainers.image.source=https://github.com/{project_org}/{project_name}"
--annotation "org.opencontainers.image.documentation=https://github.com/{project_org}/{project_name}"
--annotation "org.opencontainers.image.vcs-type=Git"
--annotation "com.github.containers.toolbox=false"
```

**Dynamic annotations** (from build-time environment):
```
--annotation "org.opencontainers.image.licenses=${LICENSE}"
--annotation "org.opencontainers.image.created=${BUILD_DATE}"
--annotation "org.opencontainers.image.version=${VERSION}"
--annotation "org.opencontainers.image.schema-version=${VERSION}"
--annotation "org.opencontainers.image.revision=${VCS_REF}"
```

### In GitHub Actions — use `docker/metadata-action` annotations output

```yaml
- uses: docker/metadata-action@030e881283bb7a6894de51c315a6bfe6a94e05cf  # v6.0.0
  id: meta
  with:
    images: ghcr.io/${{ github.repository_owner }}/${{ github.event.repository.name }}
    annotations: |
      maintainer=${{ github.repository_owner }} <${{ github.repository_owner }}@casjay.pro>
      org.opencontainers.image.vendor=${{ github.repository_owner }}
      org.opencontainers.image.authors=${{ github.repository_owner }}
      org.opencontainers.image.title=${{ github.event.repository.name }}
      org.opencontainers.image.description=Containerized version of ${{ github.event.repository.name }}
      org.opencontainers.image.url=${{ github.event.repository.html_url }}
      org.opencontainers.image.source=${{ github.event.repository.html_url }}
      org.opencontainers.image.documentation=${{ github.event.repository.html_url }}
      org.opencontainers.image.vcs-type=Git
      com.github.containers.toolbox=false

- uses: docker/build-push-action@bcafcacb16a39f128d818304e6c9c0c18556b85f  # v7.1.0
  with:
    annotations: ${{ steps.meta.outputs.annotations }}
    labels: ""   # no labels — annotations only
    tags: ${{ steps.meta.outputs.tags }}
```

Note: `github.repository_owner`, `github.event.repository.name`, and `github.event.repository.html_url` are dynamic — they work correctly after a fork without any changes.

## Portability Rule

**No hardcoded org, project name, site, or registry values anywhere in Dockerfiles, workflows, or Makefiles** (comments and license files exempt). Use build-time ARGs, environment variables, or provider-supplied context variables:

| Context | How to reference |
|---------|-----------------|
| Dockerfile | `ARG PROJECT_ORG` / `ARG PROJECT_NAME` — passed via `--build-arg` |
| GitHub Actions | `${{ github.repository_owner }}` / `${{ github.event.repository.name }}` |
| GitLab CI | `$CI_REGISTRY_IMAGE`, `$CI_PROJECT_NAMESPACE`, `$CI_PROJECT_NAME` |
| Jenkinsfile | `${env.JOB_NAME}`, `${env.GIT_URL}` — parse org/name from these |
| Makefile | `PROJECT_ORG ?= $(shell git remote get-url origin | ...)` |

This ensures workflows function correctly after a fork without editing any values.

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

### Dev Compose (`docker-compose.dev.yml`)

```yaml
services:
  {name}:
    build:
      context: ..
      dockerfile: docker/Dockerfile.dev
    volumes:
      - ..:/build                   # source mounted for hot-reload
      - /build/node_modules         # anonymous volume keeps deps inside container (Node only)
    environment:
      - DEBUG=1
    ports:
      - "8080:80"
    networks:
      - {name}-dev

networks:
  {name}-dev:
    driver: bridge
```

### Production Compose (`docker-compose.yml`)

```yaml
services:
  {name}:
    image: ghcr.io/{org}/{name}:latest   # replace with provider registry at deploy time
    restart: unless-stopped
    volumes:
      - ./volumes/data:/data
      - ./volumes/config:/config
    ports:
      - "8080:80"
    networks:
      - {name}-net

networks:
  {name}-net:
    driver: bridge
```

### Test Compose (`docker-compose.test.yml`)

```yaml
services:
  {name}:
    build:
      context: ..
      dockerfile: docker/Dockerfile
    environment:
      - TEST_MODE=1
    networks:
      - {name}-test

  db-test:                             # include only when the project needs a DB
    image: postgres:alpine
    environment:
      - POSTGRES_PASSWORD=test
    tmpfs:
      - /var/lib/postgresql/data       # ephemeral — always clean state
    networks:
      - {name}-test

networks:
  {name}-test:
    driver: bridge
    name: {name}-test                  # explicit name for reliable cleanup
```

Test Compose rules:
- AI copies `docker-compose.test.yml` to a temp dir before running — `./volumes` resolves to `{tempdir}/volumes/`
- Named bridge network for all test services — never `--network host` or default bridge
- Database services use `tmpfs` — no persistent volume, always starts clean
- Network name is explicit so `docker network rm {name}-test` cleans up reliably
- Never mount `./volumes/` or any project directory path at runtime during tests

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
