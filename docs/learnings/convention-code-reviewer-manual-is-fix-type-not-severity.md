---
name: code-reviewer-manual-is-fix-type-not-severity
description: code-reviewer reports severity (info/warn/fail) and a separate fix.type (auto/manual); manual is NOT a severity, and a fail+manual finding is still blocking
type: convention
captured: 2026-06-21
source: /build — Story 1 review (build-loop contract)
scope: plugin-general
---

forge's `code-reviewer` agent (`plugins/forge/agents/code-reviewer.md`, echoed in
`/ship` Step 0.5) returns each finding with a `severity` (`info` / `warn` /
`fail`) **and**, separately, a `fix.type` (`auto` / `manual`). These are
orthogonal axes — a finding can be `fail` severity with `fix.type: manual`.

**Why:** It is easy to write "`warn`/`manual`" as if `manual` were a severity
peer of `warn` — the build-loop contract, spec, and ADR-002 all did initially.
That invites treating a `fail`-severity finding whose fix happens to be `manual`
as a non-blocking judgment call, letting a blocking bug slip through to "done".

**How to apply:** Classify code-review findings by **severity only** — `fail`
blocks regardless of fix type (walk findings individually, never bulk-accept; see
[[win-code-reviewer-gate-before-commit]]), `warn` is a non-blocking judgment call,
`info` is ignored. `fix.type: manual` only means no auto-patch is available; it
never changes whether a finding is blocking.
