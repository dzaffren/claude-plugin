# Pick the path token by where the file lives, not by the file's existing style

**Learned:** 2026-06-04 · **From:** /build, forge thinking-skills-quality (ported 2026-09-11)

`${CLAUDE_SKILL_DIR}` resolves to one skill's own directory; `${CLAUDE_PLUGIN_ROOT}`
resolves to the plugin root. A shared reference at the plugin root cited with
`${CLAUDE_SKILL_DIR}` simply 404s. Both tokens legitimately appear in one
`SKILL.md`, so matching the surrounding style is not a safe rule — a builder did
exactly that and picked the wrong one.

Wrong: `${CLAUDE_SKILL_DIR}/references/craft.md`, when `craft.md` sits at
`plugins/zuko/references/`. Right: `${CLAUDE_PLUGIN_ROOT}/references/craft.md`,
and `${CLAUDE_SKILL_DIR}/references/<file>.md` only for a skill's own siblings.
