# Anchor a heading search to the start of a line

**Learned:** 2026-10-26 · **From:** /spec idea-board, found by /build

A script that rewrote the Interface section of `docs/specs/idea-board.md`
found the section with `s.index("## Interface\n")`. The States diagram had a
label `spec gains ## Interface`, so the search hit the diagram first. The new
section went into the middle of the Mermaid block, and the old one stayed
below. The spec gates passed, because they do not read inside a fence. The
chunk-builder found it when `board.py` drew the diagram.

## The rule

When a script finds a Markdown heading to edit, search for `"\n## Name\n"`
and step past the newline, or match `^## Name$` with `re.M`. A heading name
can be the end of any line. After the edit, list the `^## ` lines and count
the fences: an odd count or a heading out of order shows the damage at once.
