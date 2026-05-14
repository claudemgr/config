---
name: .gitignore conventions
description: Format, structure, and standard entries for .gitignore files in CasjaysDev projects
type: user
---

## Format

**Header line** (first line):
```
# gitignore created on MM/DD/YY at HH:MM
```

**Second line** — always present, suppresses dir-message prompt in some git tools:
```
ignoredirmessage
```

Sections are separated by a blank line and a `# comment` describing the group.

## Standard Entries

Every project `.gitignore` includes these:

```gitignore
# gitignore created on MM/DD/YY at HH:MM
ignoredirmessage

# ignore commit message
**/.gitcommit

# ignore build failure markers
**/.build_failed*

# ignore backup files
**/*.bak

# ignore push/git control files
**/.no_push
**/.no_git

# ignore install markers
**/.installed

# ignore work in progress scripts
**/*.rewrite.sh
**/*.refactor.sh

# ignore dotenv files
.env
app.env
default.env

# OS generated files
### Linux ###
*~
.fuse_hidden*
.directory
.Trash-*
.nfs*

### macOS ###
.DS_Store?
.AppleDouble
.LSOverride
._*
.DocumentRevisions-V100
.fseventsd
.Spotlight-V100
.TemporaryItems
.Trashes
.VolumeIcon.icns
.com.apple.timemachine.donotpresent
.AppleDB
.AppleDesktop
Network Trash Folder
Temporary Items
.apdisk
*.icloud

### Windows ###
Thumbs.db
Thumbs.db:encryptable
ehthumbs.db
ehthumbs_vista.db
*.stackdump
[Dd]esktop.ini
$RECYCLE.BIN/
*.cab
*.msi
*.msix
*.msm
*.msp
*.lnk
```

## Project-Type Additions

Add these for projects that use them:

```gitignore
# Docker compose overrides (may contain sensitive data)
compose.yml
compose.yaml
compose.default.yaml

# rootfs build directory
rootfs

# Go build output
binaries/
releases/

# Rust build output
target/
binaries/
releases/

# Claude Code local settings (allowed locally, not committed)
.claude/settings.local.json
```

**`.claude/` rule:** `.claude/settings.local.json` is gitignored (personal overrides). Everything else under `.claude/` — `settings.json`, `CLAUDE.md`, `plans/`, agents, hooks — is committed as part of the repo.

## What is NOT ignored

- `.env.example`, `.env.sample`, `app.env.example`, `app.env.sample`, `default.env.example`, `default.env.sample` — committed; they are safe templates
- `!*/README*` — README files are always kept
- `.claude/settings.json`, `.claude/CLAUDE.md`, `.claude/plans/` — committed; only `settings.local.json` is ignored

---

## .dockerignore

Same header format as `.gitignore`. Excludes everything that should not enter the Docker build context — version control, build artifacts, secrets, and local config.

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

### What is NOT excluded from Docker context

- `src/` — source code (always needed)
- `go.mod`, `go.sum` — Go module files
- `Cargo.toml`, `Cargo.lock` — Rust manifest and lockfile (`Cargo.lock` is always committed for binary crates)
- `build.rs` — Rust build script
- `docker/rootfs/` — files `ADD`ed into the image
