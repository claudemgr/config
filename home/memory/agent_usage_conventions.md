---
name: Agent usage conventions
description: model routing, the hard no-subagent-commit rule, why a "no edits" instruction isn't enforcement, and fork/subagent scope discipline
type: user
---

# Agent Usage Conventions

## Model Routing

Route each task to the cheapest capable model — full tier table in
`~/.claude/memory/model_routing.md`. Largest single lever on weekly-cap
consumption. Haiku for trivial tasks: renames, format conversions,
single-line edits, simple lookups, mechanical refactors.

## Agents Never Commit

**Hard rule, no exceptions.** Every agent/subagent type, including forked
agents, edits and reports back only; only the main session reviews the full
diff, writes `COMMIT_MESS`, and runs `gitcommit`. Mechanically enforced by
`no-subagent-commit.sh`; not a judgment call an agent can override.

## "No Edits" in a Prompt Is Not Enforcement

A "research-only"/"no edits" instruction in a prompt is a request the agent
can ignore, not enforcement. Any agent/fork keeps whatever tools its type
grants regardless of prompt wording — a fork or `general-purpose` agent told
not to edit still holds Edit/Write and may use them anyway. For work that
must not touch files, spawn an agent type that mechanically lacks Edit/Write
(`explorer`/`Explore`) instead of trusting phrasing — that's a tool-level
guarantee, not a hope. When a fork with write access is used anyway (e.g.
because the task might need one), treat every edit it makes as an unreviewed
proposal: diff it, verify it against the real file, and decide
keep/revise/discard yourself before it's ever part of a commit — never
assume "told not to edit" means it didn't.

## Fork/Subagent Scope Discipline

Fork/subagent scope is exactly the file(s)/task named in its prompt — no
drift, no self-directed coordination. An agent must never edit a file outside
what it was explicitly assigned, never spawn further agents on its own
initiative, and never narrate, decide for, or report on sibling agents' work
or status — orchestrating multiple agents is the invoking session's job
alone. A fork inherits the full conversation, including messages to and from
other agents, and can mistake that shared context for a mandate to act as
coordinator; it has none. Catching this mid-task means correcting it
immediately (tell the agent to stop and stay in its lane) and independently
re-verifying anything it already touched outside scope.
