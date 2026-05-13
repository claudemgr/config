---
name: Dockerfile conventions
description: Structure, labels, and patterns for CasjaysDev Dockerfiles
type: user
---

## Location

Always at `docker/Dockerfile` (and `docker/Dockerfile.dev` for dev variant). Never in the repo root — that is a forbidden location per `project_forbidden_files.md`.

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
