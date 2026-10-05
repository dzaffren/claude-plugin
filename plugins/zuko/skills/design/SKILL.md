---
name: design
description: >
  Standalone UI work: "/design {thing}" designs one screen or component from
  the product's system, without needing a spec. Use for "design the UI",
  "make this page better", "mockup", "redesign this".
disable-model-invocation: false
---

# Design

An argument of exactly `system` is the old spelling of `/design-system`. Print
this line and stop. Do nothing else:

```
/design system is renamed to /design-system. Run /design-system.
```

Read `${CLAUDE_PLUGIN_ROOT}/references/craft.md` in full first, and
`${CLAUDE_PLUGIN_ROOT}/references/voice.md` before writing anything.

If `OVERVIEW.md` is missing at the repo root, or still says Draft, follow
`${CLAUDE_PLUGIN_ROOT}/references/onboard.md` first, then continue.

**One design system per product.** It is the product's identity. Slices refer
to it; a slice never has its own. It grows deliberately, never per-feature.

---

# `/design {thing}`

Standalone UI work with no spec: a redesign, one screen, polishing something
that exists.

1. Find the design system. None exists → offer `/design-system` first. For a
   quick exploration the user can decline, but say the result will not be
   reusable.
2. Compose from the system's primitives. The composition-only rule from
   `craft.md` applies exactly as it does in `/spec` pause 2.
3. Pick the motion tier.
4. Build the preview — real components behind a preview route if the repo runs,
   otherwise one self-contained HTML file with every state and real motion.
5. Run the drift check on the paths you just wrote —
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-design-drift.sh" <paths>` — then
   the two checks from `craft.md`. With no paths it only looks at
   `docs/design` and will miss components written into the repo itself.
6. Show it and stop.

## Iteration

Design review is loops, not a gate passed once. Edit and stop again.

Feedback that would change a token belongs to the design system, not to this
screen. Say so and let the user decide whether the system changes — that is a
`/design-system` run, not a quiet edit here.

Capture taste as lessons: when feedback states a preference that will recur
("too corporate", "denser tables", "never cards for lists"), write it to
`docs/learnings/` so the next design starts from the user's taste rather than
the model's.
