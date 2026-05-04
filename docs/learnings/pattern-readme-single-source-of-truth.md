---
name: readme-single-source-of-truth
description: README.md is evergreen with one machine-readable `**Current version:**` line; no version-specific prose; CHANGELOG owns release history
type: pattern
captured: 2026-05-04
source: /learn — explicit capture after observed v0.3/v0.4 README drift
---

Forge's `README.md` should follow the single-source-of-truth principle for
versioning and release information:

- **Evergreen prose only.** No `## What's in v0.3-alpha`, `### What's new in
v0.3-alpha`, `### From v0.2-alpha`, or similar version-scoped sections.
  Those belong in `CHANGELOG.md`.
- **One machine-readable version line** near the top:
  `**Current version:** <x.y.z>`. That line is the single README-side
  representation of the current version — everything else that needs to
  know about releases references `CHANGELOG.md`.
- **One link-through for history:** replace version-specific prose with
  `See [CHANGELOG.md](CHANGELOG.md) for release history.`

For any fact, exactly one file owns it:

- Version number → `plugins/forge/.claude-plugin/plugin.json` (source of
  truth); README derives.
- Release history → `CHANGELOG.md` owns it; README links.
- Evergreen description, workflow, install instructions → README owns.
- Architecture details → `docs/` owns.

**Why:** Version-specific README sections duplicate CHANGELOG content, rot
on every release, and erode user trust. Observed on 2026-05-04: `main` was
at v0.4.0 per `plugin.json` and `marketplace.json`, but `README.md` still
said "What's in v0.3-alpha" because PR #6's spec explicitly deferred README
refresh ("README does not carry a machine-readable version line today;
leave README freshness as a manual cadence decision"). The user found the
drift themselves. The right fix isn't to extend automation to rewrite
README prose (prose cannot be safely auto-rewritten — a script cannot
invent narrative), it's to restructure the README so it holds no
version-specific prose in the first place.

**How to apply:** Three coupled changes, to be done together in a future
session when the user asks for them. Do NOT action proactively — the user
deliberately parked this on 2026-05-04 with "we'll come back to this some
other day":

1. **Restructure `README.md`**
   - Delete any `## What's in vX` / `### What's new in vX` / `### From vY`
     section.
   - Add a line near the top: `**Current version:** <x.y.z>` matching the
     current `plugin.json` version.
   - Replace release-specific prose with the single line
     `See [CHANGELOG.md](CHANGELOG.md) for release history.`
   - Keep the evergreen sections: Install, Prerequisites, Skills list,
     Workflow diagram, Contributing.

2. **Extend `plugins/forge/skills/ship/scripts/bump-semver.sh`** so both
   `--apply` arms (the standard-manifest cases for `package.json`,
   `Cargo.toml`, etc., and the `claude-plugin:*` arm added in PR #6) also
   rewrite the `**Current version:**` line in `README.md` when a non-zero
   bump applies. One `sed -i` substitution matching
   `\*\*Current version:\*\* [0-9a-zA-Z.-]+` is enough. Graceful skip if
   `README.md` does not exist or does not contain the line.

3. **Add a harness assertion** in
   `plugins/forge/skills/ship/scripts/__verify__/` (either extending
   `bump-semver-scenarios.sh` or adding a fourth script) covering: after
   `--apply` on a scratch repo whose `README.md` contains
   `**Current version:** 0.3.0`, the line reads `**Current version:**
<new>` with a bumped value.

When those three land, README drift stops being a per-release chore.

**Trigger phrases for resuming this work** (watch for them in future
sessions; treat as explicit permission to execute the plan above):

- "let's fix the README drift"
- "let's do that thing we deferred"
- "clean up the README"
- "restructure the README"
- "implement the readme single-source-of-truth plan"

**Counter-example — do NOT do:** Do not add "What's new in v0.5.x" or
similar version-scoped sections to README, even when shipping a large
release. That content belongs in the `[0.5.x]` block of `CHANGELOG.md`,
which the `/forge:ship` Step 3e flow already rotates automatically.
