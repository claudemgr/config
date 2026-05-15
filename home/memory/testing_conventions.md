---
name: Testing conventions
description: Test structure, naming, unit vs integration split, coverage gates, mock strategy, and timing rules across Go, Rust, and shell projects
type: user
---

## Core Principle

Tests are written in the same work pass as the code they cover — never deferred to the end. If you add or change logic in a package, update the matching test file before moving on.

---

## Test Types and Where They Live

| Type | Location | Purpose | Measured by |
|------|----------|---------|-------------|
| **Unit tests** (Go) | `*_test.go` alongside source | Pure logic, validation, parsing, config, transforms, error mapping, handler logic with mocks/httptest | `go test -cover` |
| **Integration tests** | `tests/` at repo root | Full binary behavior: routes, auth flows, content negotiation, CLI↔server interaction, service installs | Shell scripts (`run_tests.sh`, `docker.sh`, `incus.sh`) |
| **Unit tests** (Rust) | `#[cfg(test)]` blocks in `src/` | Same scope as Go unit tests | `cargo test` |
| **Integration tests** (Rust) | `tests/` at crate root | Full binary/library integration | `cargo test --test '*'` |

### What goes where

**Unit tests test logic — not infrastructure:**
- ✓ Function inputs/outputs, edge cases, error handling
- ✓ Validation and parsing logic
- ✓ Data transformations and business rules
- ✓ Handler logic using mock requests (`httptest.NewRecorder`) or stubs
- ✗ Full HTTP requests against a running server
- ✗ Database operations against a real database
- ✗ External service calls
- ✗ Auth flows that require session state

**Integration tests test behavior — not logic:**
- ✓ Every route returns the correct status, headers, and body
- ✓ Auth flows (login, logout, 2FA, tokens)
- ✓ Content negotiation (browser → HTML, curl → text, API client → JSON)
- ✓ Rate limiting and lockout behavior
- ✓ CLI ↔ server interaction
- ✓ Docker / Incus startup and smoke-test

---

## Go Test Structure

### File naming

| File | What it covers |
|------|---------------|
| `config_test.go` | Config loading, validation, defaults |
| `server_test.go` | Route registration, middleware chain |
| `auth_handler_test.go` | Auth handler logic |
| `{feature}_test.go` | Feature-specific logic |

### Table-driven tests — always preferred

```go
func TestValidate(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        wantErr bool
    }{
        {name: "empty", input: "", wantErr: true},
        {name: "too long", input: strings.Repeat("x", 101), wantErr: true},
        {name: "valid", input: "hello", wantErr: false},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := Validate(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("Validate(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
            }
        })
    }
}
```

Rules:
- Always use `t.Run(tt.name, ...)` for sub-tests — enables `go test -run TestValidate/empty`
- Name cases clearly: `"empty"`, `"too long"`, `"valid"` — not `"case1"`, `"case2"`
- Include both happy paths and all error paths in the table

### Running Go tests

```bash
make test   # runs inside Docker; enforces coverage threshold
```

Never run `go test` directly on host — always via `make test` (Docker internally).

---

## Rust Test Structure

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_empty() {
        assert!(validate("").is_err());
    }

    #[test]
    fn test_validate_valid() {
        assert!(validate("hello").is_ok());
    }
}
```

Running Rust tests — always inside Docker:
```bash
make test   # cargo fmt --check → cargo clippy -- -D warnings → cargo test --lib --no-fail-fast
```

---

## Mock Strategy

| Dependency | How to mock |
|------------|------------|
| External HTTP service | `httptest.NewServer` (Go) / `mockito` equivalent |
| Database | Interface-based mock; never an in-memory substitute for integration tests |
| File system | `os.TempDir()` / test temp directories; clean up with `t.Cleanup` |
| Time | Inject a `clock` interface; never call `time.Now()` directly in logic under test |
| Configuration | Construct the config struct directly in the test; don't read files |

**Prefer interfaces over mocking frameworks.** Define a small interface for any dependency that needs mocking; implement it with both the real and mock versions. Mocking frameworks that generate code from interfaces are acceptable but not required.

---

## Coverage Gates

| Project type | Minimum coverage | Source |
|-------------|-----------------|--------|
| SERVER template projects | 100% Go code coverage | `go test -cover` |
| Other Go projects | 60% (override in `IDEA.md` under `## Business logic`) | CI gate |
| Rust projects | 60% (override in `IDEA.md`) | `cargo tarpaulin` or `cargo llvm-cov` |

The threshold is defined in `{project_dir}/IDEA.md`. CI fails when coverage drops below it — a passing build with uncovered code is a silent regression. If no threshold is set in `IDEA.md`, default is 60%.

Coverage is measured on unit tests only (`*_test.go` / `#[cfg(test)]`). Integration test coverage is tracked separately by verifying that every route and endpoint has at least one integration test.

---

## Test Data

- **No test data at repo root** — use `os.TempDir()` / `t.TempDir()` (auto-cleaned by Go)
- **Fixtures**: small static files go in `tests/testdata/` — never in `src/`
- **Generated data**: create in temp dirs; never commit generated test artifacts
- **Database state**: create fresh schema per test run; never share state between tests
- **Secrets in tests**: use obviously fake values (`test-api-key-xxxxx`, not real-looking strings)

---

## AI Rules

- **Never defer tests** — write the test file in the same commit as the implementation
- **Never skip tests to "ship faster"** — a feature without tests is incomplete
- **Never write tests that only test the mock** — if every assertion would pass with any implementation, the test is worthless
- **Never commit with `t.Skip()`** left in without a comment explaining why and a linked issue
- **Test every error path** — not just the happy path; coverage gates enforce this
