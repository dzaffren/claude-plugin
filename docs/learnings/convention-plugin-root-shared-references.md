---
name: plugin-root-shared-references
description: cite plugin-level shared refs from SKILL.md with ${CLAUDE_PLUGIN_ROOT}, skill-local refs with ${CLAUDE_SKILL_DIR}
type: convention
scope: project-specific
captured: 2026-06-04
source: /build session (thinking-skills-quality) — feature-builder picked the wrong token; caught in review
---

Shared references that live at the plugin root (`plugins/forge/references/`,
e.g. `multi-choice.md`, `pushback-frameworks.md`, `artifact-digest.md`) MUST be
cited from SKILL.md content as `${CLAUDE_PLUGIN_ROOT}/references/<file>.md`. Use
`${CLAUDE_SKILL_DIR}/references/<file>.md` ONLY for a skill's own sibling files
(e.g. `prd/references/bdd-format.md`). A single SKILL.md legitimately mixes both
tokens.

**Why:** `${CLAUDE_SKILL_DIR}` resolves to the skill's own directory, so
`${CLAUDE_SKILL_DIR}/references/pushback-frameworks.md` 404s when the file
actually lives at the plugin root. `${CLAUDE_PLUGIN_ROOT}` IS officially
supported inside skill content — verified against the official Claude Code
plugins-reference (code.claude.com/docs/en/plugins-reference): "Claude Code
provides three variables for referencing paths [CLAUDE_PLUGIN_ROOT,
CLAUDE_PLUGIN_DATA, CLAUDE_PROJECT_DIR]. All are substituted inline anywhere
they appear in skill content, agent content, hook commands, monitor commands,
and MCP or LSP server configs." The repo's `docs/claude-plugin-conventions.md`
Variables Reference previously listed `${CLAUDE_PLUGIN_ROOT}` as
hooks/`.mcp`-only; that error was corrected in the same PR that captured this
learning.

**How to apply:** When adding a reference to a SKILL.md, decide by WHERE the
file lives — plugin root → `${CLAUDE_PLUGIN_ROOT}`; the skill's own dir →
`${CLAUDE_SKILL_DIR}`. Do NOT blindly "match the file's existing token style":
a SKILL.md already citing `bdd-format.md` via `${CLAUDE_SKILL_DIR}` does not
mean a new plugin-level shared ref should use the same token. Matching style
blindly is exactly what caused a feature-builder to pick the wrong token this
session.
