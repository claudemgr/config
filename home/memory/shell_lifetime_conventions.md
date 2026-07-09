---
name: Shell lifetime conventions
description: Timeout tiers, polling rules, background-process ownership, and follow-mode bounds for every shell command — enforced by bound-shell-lifetime.sh
type: user
---

Every shell command must be bounded to its operation — enforced by `bound-shell-lifetime.sh`.

## Timeout Tiers

- Lookups/status ≤30s · network/package ops ≤120s · builds/tests ≤600s; pass an explicit `timeout` on every Bash call sized to the tier
- **The Bash tool `timeout` parameter is in MILLISECONDS** — 30s = `30000`, 120s = `120000`, 600s = `600000`. Passing a seconds value (e.g. `30`) means 30 ms and kills the command instantly with exit 143 "timed out after 0s". Never pass a raw seconds number

## Polling and Waiting

- **Never poll for harness-tracked work** — subagents and background tasks deliver a task-notification on completion; a sentinel-file poll loop (`until [ -f *.done ]; do sleep N; done`) is forbidden — end the turn and let the notification resume it
- **Polling external state must be bounded** — wrap the loop in `timeout {n}` or add an iteration cap; `while true`/`until` + `sleep` with no bound is forbidden
- **No open-ended sleeps** — `sleep infinity` and any single sleep >600s are forbidden; for longer waits, end the turn or use a scheduler

## Detachment and Background Processes

- **No detachment** — `nohup`, `setsid`, `disown` escape both timeouts and task tracking; use run_in_background (tracked, notifies on exit, stoppable)
- **`&` requires ownership** — capture `PID=$!` at launch or close with `wait`; stop every background shell as soon as its output is consumed

## Follow Modes

- **Follow modes are bounded** — `tail -f` / `watch` only inside `timeout {n}`; otherwise read the file once

## Exemptions

- Anything already under `timeout {n}`
- Container-mediated payloads (container lifetime is governed by the Cleanup rules and `enforce-docker-rm.sh`)
