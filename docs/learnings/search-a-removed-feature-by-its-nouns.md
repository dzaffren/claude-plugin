# Search a removed feature by its nouns, not its step phrases

**Learned:** 2026-11-27 · **From:** /build drop-board

`test-drop-board.sh` searched the skills and references for the phrases the
publish steps used: `board.py`, `visual-page`, "idea board", "hub page",
`Board:`. Every check passed, yet `references/voice.md` still said Mermaid is
the source "in specs, shapes and published pages". A wider grep for the
nouns, "published page", "the board", `claude.ai`, found it, plus stale board
text in `docs/ARCHITECTURE.md` and three OVERVIEW rows that the README copies.

## The rule

When a slice removes a feature, grep for every noun the feature is known by,
in prompts and in the docs that describe the system, not only for the step
phrases. Put each noun that finds a hit into the contract test.
