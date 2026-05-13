---
name: Logging conventions
description: Log file format, content rules, and log-type standards for all CasjaysDev projects (scripts, Go, Rust)
type: user
---

## Universal Rules

- **Log files are always pure raw text** — no ANSI escape codes, no emojis, no Unicode decorations, no terminal control sequences. Ever.
- Color and emojis are for terminal output only. The log file path and the terminal output path must be separate code paths.
- Log files must be human-readable with standard tools: `cat`, `grep`, `tail -f`, `awk`, `fail2ban`, `logwatch`, syslog parsers.
- **Timestamps are always ISO 8601** (`2026-05-13T10:58:00-04:00`) or syslog format (`May 13 10:58:00`) — never free-form date strings.
- Log lines are **one line per event** — no multi-line log entries unless the format explicitly defines them (e.g. stack traces in an error log must be indented continuation lines, not embedded newlines in the first field).

## Log Types and Formats

### access.log — HTTP request log

Apache Combined Log Format:

```
{remote_host} {ident} {auth_user} [{day}/{month}/{year}:{hour}:{min}:{sec} {tz}] "{method} {path} {protocol}" {status} {bytes} "{referer}" "{user_agent}"
```

Example:
```
192.168.1.1 - - [13/May/2026:10:58:00 -0400] "GET /api/health HTTP/1.1" 200 42 "-" "curl/8.5.0"
```

Use this format for any HTTP-facing service. Keeps compatibility with `fail2ban`, `goaccess`, `awstats`, and standard log analysis tools.

### auth.log — Authentication events

Syslog format:

```
{Month} {DD} {HH}:{MM}:{SS} {hostname} {program}[{pid}]: {message}
```

Example:
```
May 13 10:58:00 myhost casci[1234]: Failed login for user admin from 192.168.1.50
May 13 10:58:05 myhost casci[1234]: Successful login for user admin from 192.168.1.1
```

Log: failed logins, successful logins, token issuance, privilege escalation, password changes, lockouts. This format is recognized by `fail2ban` and OS log aggregators.

### error.log — Application errors

```
{ISO8601} [{LEVEL}] {message}
```

Example:
```
2026-05-13T10:58:00-04:00 [ERROR] database connection failed: dial tcp 127.0.0.1:5432: connection refused
2026-05-13T10:58:01-04:00 [WARN]  retrying in 5s (attempt 2/3)
```

Levels (uppercase, bracket-wrapped): `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL`.

### application.log / {name}.log — General structured log

logfmt (key=value pairs) — machine-readable, human-scannable, grep-friendly:

```
time=2026-05-13T10:58:00-04:00 level=INFO msg="server started" addr=:8080 version=1.2.0
time=2026-05-13T10:58:05-04:00 level=WARN msg="rate limit hit" ip=10.0.0.5 path=/api/upload
```

Alternatively, plain timestamped lines for simpler scripts:

```
2026-05-13T10:58:00-04:00 INFO  server started on :8080
2026-05-13T10:58:05-04:00 WARN  rate limit hit for 10.0.0.5
```

### syslog / journald passthrough

When writing to syslog or journald directly (via `logger`, Go's `log/syslog`, or Rust's `syslog` crate), omit the timestamp and hostname — the journal adds them. Message only:

```
casci[1234]: Failed login for user admin from 192.168.1.50
```

## What Belongs in Each Log

| Log file | What to log | What NOT to log |
|----------|------------|-----------------|
| `access.log` | Every HTTP request/response | Request bodies, passwords, tokens |
| `auth.log` | Login attempts, token events, lockouts | Passwords, raw tokens, session keys |
| `error.log` | Errors, warnings, panics, retries | Debug noise in production, PII |
| `app.log` | Startup, shutdown, config reload, background jobs | Verbose per-request debug in production |

**Never log:** passwords, raw tokens, API keys, session cookies, credit card numbers, SSNs, or any credential. Log a masked representation (`[REDACTED]`, `sha256:abc123`, last 4 chars) if the event itself must be recorded.

## Log File Location

Follow XDG / OS conventions:

| Context | Path |
|---------|------|
| System service | `/var/log/{project_org}/{project_name}/` |
| User-mode / XDG | `${XDG_STATE_HOME:-~/.local/state}/{project_name}/` |
| Docker container | stdout/stderr (no file) — let the container runtime collect logs |
| Scripts (one-off) | `/tmp/{project_org}/{internal_name}-XXXXXX/` (temp, not committed) |

In Docker: write to stdout (access, app) and stderr (errors) — never to a file inside the container. The runtime collects and rotates.

## Log Rotation

System services must ship a `logrotate` config at `docker/rootfs/etc/logrotate.d/{project_name}`:

```
/var/log/{project_org}/{project_name}/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    sharedscripts
    postrotate
        systemctl kill -s HUP {project_name}.service 2>/dev/null || true
    endscript
}
```

## Implementation Notes

### Scripts

```bash
# BAD — ANSI leaks into log
echo -e "\e[31mERROR\e[0m: something failed" | tee -a /var/log/myapp/error.log

# GOOD — strip color for log, keep for terminal
__log_error() {
  local msg="$1"
  # always plain text to log file
  printf '%s [ERROR] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${msg}" >> "${MYAPP_LOG_FILE}"
  # color only when going to a terminal
  if [[ -t 2 && -z "${NO_COLOR}" ]]; then
    printf '\e[31m[ERROR]\e[0m %s\n' "${msg}" >&2
  else
    printf '[ERROR] %s\n' "${msg}" >&2
  fi
}
```

### Go

Use `log/slog` (stdlib, Go 1.21+) with a plain text handler for files and an optional color handler for terminal:

```go
// File handler — plain text, no color
fileHandler := slog.NewTextHandler(logFile, &slog.HandlerOptions{Level: slog.LevelInfo})

// Terminal handler — can use a color-capable handler; falls back to plain when NO_COLOR set
slog.SetDefault(slog.New(fileHandler))
```

Never write ANSI codes into the `slog` message or attributes — they end up in the log file.

### Rust

Use `tracing` + `tracing-subscriber` with a plain formatter for file output:

```rust
// File appender — always plain text
let file_appender = tracing_appender::rolling::daily("/var/log/myapp", "app.log");
let (non_blocking, _guard) = tracing_appender::non_blocking(file_appender);

tracing_subscriber::fmt()
    .with_ansi(false)   // no ANSI in log file — ever
    .with_writer(non_blocking)
    .init();
```

For terminal output, `with_ansi(true)` only when color is enabled (check `NO_COLOR` + isatty first).
