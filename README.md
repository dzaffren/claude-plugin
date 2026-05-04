# Forge — a Claude Code workflow plugin

Installed from the **mjolnir** marketplace. Forge delivers a spec-driven, test-disciplined coding workflow with system-design consciousness and security awareness baked in.

## What's in v0.3-alpha

The current release covers the full dev pipeline end-to-end: discovery → PRD → technical refine → build → ship → fix → learn. Ship and fix both run security-review and code-review gates; learn captures team lessons that surface back at the entry of future `/prd`, `/prd-refine`, and `/build` runs.

- Skills: `/forge:product-discovery`, `/forge:poc`, `/forge:prd`, `/forge:prd-refine`, `/forge:grill-me`, `/forge:build`, `/forge:tdd`, `/forge:e2e-create`, `/forge:e2e`, `/forge:verifier`, `/forge:ship`, `/forge:fix`, `/forge:security-review`, `/forge:doc-architect`, `/forge:learn`
- Agents: `feature-builder`, `reviewer` (scope-only, used by `/build`), `code-reviewer` (quality review, used by `/ship`), `prd-story-writer`, `learning-capturer`
- Hooks: `block-dangerous`, `changelog-guard`, `auto-format`, `stop-verify`, `secret-scan`
- Statusline: model · tokens · cost · context bar · cwd + git branch

### What's new in v0.3-alpha

- `/forge:ship` **Step 0.5 — Code Review** gate with the new `code-reviewer` agent (dead code, obvious bugs, style drift, missing tests, readability). Auto-applies safe patches; surfaces `manual` / `fail` findings via multi-choice; uses `git apply -R` on rollback so unrelated uncommitted work survives.
- `/forge:ship` **Step 8 — Sync learnings into CHANGELOG** — runs after capture and pushes a follow-on commit to the open PR.
- `/forge:learn` gains a **`win`** learning type (positive counterpart to `blocker`) and a `retro [--days N]` mode for "going right / going wrong" digests.
- `/forge:prd`, `/forge:prd-refine`, and `/forge:build` each read `docs/learnings/INDEX.md` at entry and surface relevant prior learnings before the first question — closing the feedback loop.
- `/forge:product-discovery` questions rewritten in plain language; embedded `/grill-me` delegation replaced with a short inline pressure-test.

### From v0.2-alpha

- `/forge:security-review`, `/forge:fix`, `secret-scan` hook, atomic-commit `/ship` with semver awareness, multi-choice prompt pattern, PRD System Design + Threat Model sections.

## Prerequisites

- Claude Code installed and authenticated
- `gh` (GitHub CLI) installed and authenticated (`gh auth status` should report OK)
- Git

## Install

From inside Claude Code:

```
/plugin
```

Navigate to **Marketplace → Add marketplace** and paste this repo's clone URL. Then install `forge@mjolnir`.

Restart Claude Code after install so the statusline applies.

## Disabling the statusline

The plugin sets `statusLine.command` in its own `settings.json`. To override it with your own statusline (or restore the default), add your preferred command to your user `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /path/to/your/own/statusline.sh"
  }
}
```

User settings override plugin settings.

## Workflow

```
/forge:product-discovery  →  /forge:prd  →  /forge:prd-refine  →  /forge:build  →  /forge:ship
                                                                      ↓                 ↓
                                                            (verifier, e2e,       (security-review,
                                                             scope-review)         code-review,
                                                                                   learnings sync)

Bug found after ship?  →  /forge:fix   (reproduce → failing test → minimal patch → ship)
Worth remembering?     →  /forge:learn (capture; retro digests; prior-learning surfacing)
```

See `CHANGELOG.md` for the release history and `docs/superpowers/specs/` for design specs behind each milestone.

## Contributing

PRs welcome. See `docs/claude-plugin-conventions.md` and the design spec at `docs/superpowers/specs/2026-05-01-forge-plugin-design.md`.
