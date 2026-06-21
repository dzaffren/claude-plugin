---
name: skill-edits-self-referential-build
description: Editing forge's own skills has no automated tests, and the active plugin loads from the install cache (not the worktree) — so even a fresh session won't exercise repo edits without a dev-install
type: blocker
captured: 2026-06-21
source: /build + /ship — Story 3 plain-language-trust-layer (forge editing forge)
scope: project-specific
---

This repo *is* the forge plugin, so a `/build` here edits forge's own `SKILL.md`
and reference markdown. Two consequences that do not hold for a normal product
repo:

1. **No automated tests to write.** Skill-definition markdown has no unit or E2E
   surface, so `/build`'s feature-builder TDD agents, the `verifier`, and the
   `e2e` skill add nothing — `verifier` returns "unknown stack" and runs only
   basic checks. The right-sized approach is direct edits plus a manual dry-run
   of the changed skill.
2. **The active plugin runs from the install cache, not the worktree.** The
   forge skills currently executing load from
   `.claude/plugins/cache/mjolnir/forge/<version>/` (e.g. `0.5.0/` this session),
   NOT the repo working tree. So a fresh session — the usual workaround in
   [[skills-load-at-session-start]] — still loads the cached release, not your
   edits.

**Why:** Trusting "/build verifier passed" or "start a fresh session to test"
gives false coverage here. The edits look merged on disk and the session reports
green, but nothing actually exercised the new skill content.

**How to apply:** When the build target is forge's own skills:

1. Skip the TDD/verifier expectation; plan for direct edits + a manual dry-run.
2. To actually test edited skill behavior, dev-install the branch over the cache
   path (or release first, then update) — not just a fresh session.
3. See also [[skills-load-at-session-start]] — this extends it: the cache, not
   just session timing, is why repo edits don't take.

**What was tried:** Story 3 was built by direct markdown edits (not the TDD
subagent pipeline) and shipped; behavioral verification was deferred to a
post-release dry-run because the running session loaded the cached 0.5.0 forge,
not the branch's edits.
