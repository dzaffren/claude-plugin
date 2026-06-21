# Forge — a Claude Code workflow plugin

Installed from the **mjolnir** marketplace. Forge delivers a spec-driven, test-disciplined coding workflow with system-design consciousness and security awareness baked in.

**Current version:** 0.7.0

See [CHANGELOG.md](CHANGELOG.md) for release history.

## Skills

- `/forge:product-discovery`, `/forge:poc`, `/forge:prd`, `/forge:prd-refine`, `/forge:grill-me`, `/forge:build`, `/forge:tdd`, `/forge:e2e-create`, `/forge:e2e`, `/forge:verifier`, `/forge:ship`, `/forge:fix`, `/forge:security-review`, `/forge:doc-architect`, `/forge:learn`

## Agents, hooks, statusline

- Agents: `feature-builder`, `reviewer` (scope-only, used by `/build`), `code-reviewer` (quality review, used by `/ship`), `prd-story-writer`, `learning-capturer`
- Hooks: `block-dangerous`, `changelog-guard`, `auto-format`, `stop-verify`, `secret-scan`
- Statusline: model · tokens · cost · context bar · cwd + git branch

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

## Contributing

PRs welcome. See `docs/claude-plugin-conventions.md` and the design spec at `docs/superpowers/specs/2026-05-01-forge-plugin-design.md`.
