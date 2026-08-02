---
name: spec-html
description: >
  Renders a Markdown spec, discovery brief, design doc, or walkthrough into a
  self-contained HTML visualization (sidebar TOC, scroll-spy, rendered Mermaid
  diagrams, light/dark). Use whenever any such .md document is created or
  edited, or when the user says "regenerate the HTML", "show me the spec",
  "visualize the plan", or "HTML view". The other dz-workflow skills call
  this after writing their documents.
---

# Spec HTML View

Markdown is the source of truth. Every spec, discovery brief, design doc, or
walkthrough `.md` gets a sibling `.html` with the same basename in the same
directory. Never hand-edit the `.html`. Whenever the `.md` changes, regenerate.

## Generate

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/spec-html/scripts/md2html.py <path/to/doc.md> [more.md ...]
```

The script wraps the raw markdown in `assets/template.html` and writes the
sibling `.html`, printing a `file://` URL per file. The template guarantees:
one self-contained file (CDN only, opens from `file://`), sticky sidebar TOC
built from h2/h3 with scroll-spy, Mermaid blocks rendered as real diagrams,
~70ch measure, light and dark via `prefers-color-scheme`.

If `python3` is unavailable, read `assets/template.html`, substitute
`{{TITLE}}` (first `#` heading) and `{{MARKDOWN}}` (the raw markdown, with any
literal `</script` escaped as `<\/script`), and write the sibling file by hand.

## Content rules for the .md

- Any design, flow, or architecture section gets a Mermaid diagram: under ~10
  boxes, arrows labeled with what actually moves (`sends token`, `writes row`).
  If it needs more boxes, draw two diagrams at different zoom levels.
- Shortest complete version. No sections added for symmetry.

## Always end with the link

The final line(s) of the reply must be the clickable `file://` link(s) to every
generated `.html`, full absolute path, each on its own line, nothing after them.
