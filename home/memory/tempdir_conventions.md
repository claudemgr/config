---
name: Temp directory conventions
description: Rules for creating and using temporary directories in all languages; project directory is source code only
type: user
---

## Core Rule

**The project directory is for SOURCE CODE ONLY.** All runtime data, test data, and build artifacts go to the OS temp directory. Never write runtime or test output into the project tree.

## Required Pattern

The ONLY acceptable temp directory structure:

```
${TMPDIR:-/tmp}/{project_org}/{internal_name}-XXXXXX/
```

- `${TMPDIR:-/tmp}` — always use the OS env var; never hardcode `/tmp`
- `{project_org}/` — organization prefix so dirs are identifiable and cleanable by project
- `{internal_name}-XXXXXX` — project name + random suffix from `mktemp`

`{internal_name}` is used (not `{project_name}`) because it is frozen and never changes even if the project renames.

## FORBIDDEN

| Pattern | Why |
|---------|-----|
| `/tmp/myfile` | Bare root tmp — unidentifiable, collides |
| `/tmp/{project_name}` | Missing org prefix |
| `mktemp -d` | No org/project structure |
| `/tmp/test-data/` | Generic path — not namespaced |
| Hardcoded org name | Must be detected, never hardcoded |
| Writing test/runtime data into project dir | Project dir = source code only |

## Creating Temp Directories — Per Language

### Shell / Bash

```bash
mkdir -p "${TMPDIR:-/tmp}/${PROJECT_ORG}"
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/${PROJECT_ORG}/${PROJECT_NAME}-XXXXXX")
```

### Go

```go
base := filepath.Join(os.TempDir(), projectOrg)
os.MkdirAll(base, 0755)
dir, err := os.MkdirTemp(base, projectName+"-")
```

Never call `os.TempDir()` alone — always nest under `{project_org}/`.

### Rust

```rust
let base = std::env::temp_dir().join(&project_org);
std::fs::create_dir_all(&base)?;
// tempfile crate:
let dir = tempfile::Builder::new()
    .prefix(&format!("{}-", project_name))
    .tempdir_in(&base)?;
```

Or without the `tempfile` crate:

```rust
let base = std::env::temp_dir().join(&project_org);
std::fs::create_dir_all(&base)?;
let dir = base.join(format!("{}-{}", project_name, random_suffix()));
std::fs::create_dir_all(&dir)?;
```

Never call `std::env::temp_dir()` alone — always nest under `{project_org}/`.

## OS Temp Directories

| OS | Default | Env var |
|----|---------|---------|
| Linux | `/tmp` | `$TMPDIR` |
| macOS | `/var/folders/…/T/` | `$TMPDIR` |
| Windows | `%LocalAppData%\Temp` | `%TEMP%` |
| FreeBSD | `/tmp` | `$TMPDIR` |

Always use `${TMPDIR:-/tmp}` (shell) or `os.TempDir()` / `std::env::temp_dir()` — never hardcode the path.

## Directory Structure Inside the Temp Root

| Purpose | Pattern |
|---------|---------|
| Dev / test runtime | `{tempdir}/{project_org}/{internal_name}-XXXXXX/` |
| Config volume | `{tempdir}/{project_org}/{internal_name}-XXXXXX/volumes/config/` |
| Data volume | `{tempdir}/{project_org}/{internal_name}-XXXXXX/volumes/data/` |
| DB volume | `{tempdir}/{project_org}/{internal_name}-XXXXXX/volumes/db/` |
| Screenshots / downloads | `{tempdir}/{project_org}/{internal_name}-XXXXXX/` with filename |

## Cleanup

```bash
# List all temp dirs for this org
ls -la "${TMPDIR:-/tmp}/${PROJECT_ORG}/"

# Remove all temp dirs for this project
rm -rf "${TMPDIR:-/tmp}/${PROJECT_ORG}/${PROJECT_NAME}-"*

# Remove entire org temp tree (only when certain nothing else uses it)
rm -rf "${TMPDIR:-/tmp}/${PROJECT_ORG}/"
```

## AI-Specific Rules

- **NEVER** run `docker compose up` with `docker-compose.yml` or `docker-compose.dev.yml` — those are human-only
- **NEVER** mount `./volumes/` or any project-directory path at runtime
- For automated testing: copy `docker/docker-compose.test.yml` to a temp dir and run from there — `./volumes` then resolves to `{tempdir}/volumes/`
- **NEVER** create or modify files in the project directory during testing

Full AI Docker Compose workflow is in `claudemgr/go/TEMPLATE.md § AI Docker Compose Rules`.
