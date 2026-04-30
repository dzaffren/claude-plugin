# Forge — a Claude Code workflow plugin

Installed from the **mjolnir** marketplace. Forge delivers a spec-driven, test-disciplined coding workflow with system-design consciousness and security awareness baked in.

## What's in v0.1-alpha

Milestone 1 ships a working port of the did-workflow pipeline under the forge brand, on GitHub (via `gh`), with a built-in statusline. Functional upgrades (`/fix`, `/security-review`, atomic-commit `/ship`, multi-choice prompts, new stacks) land in later milestones.

- Skills: `/forge:discover`, `/forge:poc`, `/forge:prd`, `/forge:prd-refine`, `/forge:grill-me`, `/forge:build`, `/forge:tdd`, `/forge:e2e-create`, `/forge:e2e`, `/forge:verifier`, `/forge:ship`, `/forge:doc-architect`, `/forge:learn`
- Agents: `feature-builder`, `reviewer`, `prd-story-writer`, `learning-capturer`
- Hooks: `block-dangerous`, `changelog-guard`, `auto-format`, `stop-verify`
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

## Workflow (M1 scope)

Follows the same pipeline as did-workflow; the in-flight upgrades to `/ship`, `/fix`, `/security-review`, and interactive skills arrive in M2 and M3 (see `docs/superpowers/specs/2026-05-01-forge-plugin-design.md`).

## Contributing

PRs welcome. See `docs/claude-plugin-conventions.md` and the design spec at `docs/superpowers/specs/2026-05-01-forge-plugin-design.md`.
