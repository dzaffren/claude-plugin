# A flow cannot start a user-only skill

**Learned:** 2026-10-12 · **From:** /spec pause-questions, pause 3

Pause 2 of pause-questions approved a last question, "Run /build now?", whose
answer would start `/build`. Pause 3 found `disable-model-invocation: true` in
`build/SKILL.md`. `/review`, `/ship` and `/release` have it too. Claude cannot
start any of them, so the approved answer could never work.

## The rule

Before a design lets Claude start a skill, read that skill's frontmatter. When
`disable-model-invocation` is `true`, only the user can start it. Do this check
at pause 2, where the interface is approved, not at pause 3.
