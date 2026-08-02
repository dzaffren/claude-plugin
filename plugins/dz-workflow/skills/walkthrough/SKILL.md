---
name: walkthrough
description: >
  Explains existing code as a document: one real path traced with file:line
  references, a Mermaid diagram, saved as Markdown plus the HTML view. Use
  when the user says "walk me through", "how does X work", "explain this
  code/feature/flow", "document how this works". Independent of the
  workflow pipeline.
---

# Walkthrough

Explain how a piece of the codebase actually works by tracing one real path
through it — real function names, real files, real line numbers. Not an
abstract description of the design.

## Steps

1. **Read the code first.** If `graphify-out/graph.json` exists in the repo,
   query it for the structure before grepping, then open the real files to
   confirm — the graph points, the file proves. Follow the actual call path
   for the topic in `$ARGUMENTS`, noting `path/file.py:42` at each hop.

2. **Write the doc** to `docs/walkthroughs/{name}.md`:
   - Two or three plain sentences up top: what this thing does and where it
     starts.
   - A Mermaid diagram of the flow — under ~10 boxes, arrows labeled with
     what moves (`sends token`, `writes row`). Two zoom levels if it's big.
   - The trace: step by step through one real scenario with concrete values,
     each step anchored to `file:line`. Quote the load-bearing lines, not
     whole functions.
   - Gotchas: only the things the code can't say for itself (implicit
     ordering, surprising defaults, that one flag everything depends on).
   - Shortest complete version. No taxonomy sections.

3. **Render.** Generate the HTML view (spec-html skill) and end with the
   `file://` link on its own line.

If the walkthrough reveals the doc would go stale fast (code under heavy
change), say so in one line rather than silently documenting a moving target.
