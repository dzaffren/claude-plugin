---
name: status
description: >
  Shows where every piece of work sits in the shipwright pipeline and what
  the next command is. Use when the user asks "where are we", "what's next",
  "pipeline status", "which specs are in flight", or types /status. Also
  regenerates the specs index page.
---

# Status

One table: every spec, its version, its stage, the next command. No prose
essays.

## Steps

1. **Scan the docs.** Read the header line (Version, Status) of every
   `docs/specs/*.md` and `docs/specs/*/spec.md`. Note `docs/specs/archive/`
   separately. List `docs/discovery/*.md` briefs that have no matching spec.

2. **Map status → next step:**

   | Status    | Next                                             |
   | --------- | ------------------------------------------------ |
   | (brief only) | `/spec` — turn the discovery brief into a spec |
   | Draft     | your review, then `/refine`                      |
   | Refined   | your review, then `/build`                       |
   | Built     | `/quality`, then `/security`, then `/ship`       |
   | Shipped   | done — `/discover` or `/spec` starts the next iteration |

   Cross-check `Built` against reality: if the branch for it doesn't exist
   or tests were never run, say so instead of trusting the label.

3. **Refresh the index page:**

   ```bash
   python3 ${CLAUDE_PLUGIN_ROOT}/skills/spec-html/scripts/md2html.py --index docs/specs
   ```

4. **Report.** Print the table (spec · version · status · next), one line
   for anything stale or contradictory (e.g. two specs for the same feature
   outside archive/), and end with the `file://` link to
   `docs/specs/index.html` on its own line.
