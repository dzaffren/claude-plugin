# The visual page

Every spec publishes one page. The Markdown is the source of truth; the page
is how the user looks at it.

## Why both

The terminal is where the work happens, and it shows Mermaid as source. But a
spec is also something you read on a phone, hand to someone, or come back to
in three months. That wants a real page.

The page is **generated from the spec**, never maintained beside it. If they
disagree, the Markdown wins and the page gets republished.

## When to publish

- At the end of `/spec` pause 3, once the plan is approved.
- Again whenever the spec materially changes (a new version, a resolved
  ledger item that changed the plan, a scope change).
- Not on every small edit. A typo fix is not a republish.

Same file path each time, so it redeploys to the same URL. The user keeps one
link per slice forever.

## What goes on it

In this order:

1. **The slice, in one line.** What ships and who it helps.
2. **Status strip.** Version · status · open items count · branch.
3. **User flow diagram.** The picture from pause 1.
4. **Acceptance criteria.** The Given/When/Then scenarios, readable.
5. **Interface.** Screens or the endpoint/command surface. Link to the live
   preview if there is one.
6. **Architecture.** The components diagram.
7. **Runtime sequence.** How a request actually moves.
8. **Data.** ER diagram and the migration plan, when the schema changes.
9. **Non-functionals.** The five-line block: load, breaks first, security
   surface, proof it works, rollout.
10. **Open items.** The ledger, open rows highlighted.
11. **Risks.** Real ones with mitigations.

Skip any section the spec doesn't have. Never render an empty heading.

## How to build it

Load the `artifact-design` skill before writing the page, and
`artifact-diagramming` for the diagrams. Then:

- Write the HTML to `docs/specs/.pages/{slice}.html` in the target repo (the
  directory is gitignored — the Markdown is what gets committed).
- Publish with the Artifact tool, same file path each time.
- Title: the slice name. Short, specific, no explainer after a dash.
- Favicon on first publish only.

Diagrams render natively in artifacts through `<pre class="mermaid">` blocks —
do not load a diagram library.

## Link back to the hub

Once a hub page exists (its link is on the `## More` line of `OVERVIEW.md`),
every spec page opens with one line above the slice line:

`Part of invoice-cli — hub page: https://claude.ai/...`

If the shape doc of the spec has a `**Board:**` line, add this line above
the slice line:

`Part of {idea} — board: {url}`

## Idea board

Each idea with a shape has one board. The board is a page that shows the
slices of the idea, their stages, their links and their choices. The script
`board.py` makes it from the shape, the specs and `DECISIONS.md`. Do not load
`artifact-design` for the board. Do not edit the HTML.

These stages republish the board:

- `/shape`, at step 6.
- `/spec`, at each pause.
- `/build`, at its report.
- `/review`, after it writes the `## Review` section.
- `/ship`, after the hub page.

`/release` does not republish the board. A release does not change the stage
of a slice.

`/shape` knows its idea. Each other stage reads the `**Shape doc:**` line of
its spec. The idea is the folder of that shape:
`docs/specs/living-board/shape.md` → `living-board`. When the spec has no `**Shape doc:**` line, skip the board.
Say nothing about it.

1. Run the script. For `--by`, give the stage and the slice, for example
   `--by "/spec idea-board pause 1"`:

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/board.py" render docs/specs/{idea}/shape.md --by "{stage} {slice}"
   ```

2. Write the output to `docs/specs/.pages/{idea}-board.html`.
3. Publish that file with the Artifact tool. Use the same file path each
   time, so the URL stays the same. Give an icon on the first publish only.
4. After the first publish, add `**Board:** {url}` to `shape.md`, on its own
   line under the `**Project type:**` line. Do not change that line after.
5. Print one line in the terminal:

   ```
   Board: https://claude.ai/artifact/…
   ```

`render` exits 2 when it cannot read the shape, or when the shape has no
`## Slices` table. Print its message as one line. Then go on with the stage.

When the publish fails, the stage goes on. Serve the board on localhost:

1. Check that the server on port 4751 serves this board. The check passes
   only when the page it returns is the file you wrote:

   ```bash
   curl -sf http://127.0.0.1:4751/{idea}-board.html | cmp -s - docs/specs/.pages/{idea}-board.html
   ```

2. If the check fails, start the server in the background:

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/board.py" serve docs/specs/.pages
   ```

   Wait one second. Run the same check again.
3. When a check matches, print one line, with the error from the Artifact
   tool:

   ```
   Board not published: {error}. Local board: http://127.0.0.1:4751/{idea}-board.html
   ```

When the second check does not match, print this line instead, with the
absolute path of the file. Another program, or the server of another
project, holds port 4751, and `serve` exits 1:

```
Board not published: {error}. Port 4751 is in use, so open the file: {absolute path}
```

Leave the server running after the stage ends. A later failed publish uses
it again. The next stage tries the publish again.

## Hub page

One page for the whole project; each slice's page links from it. Built by
`/ship` before the push, in the slice's own PR, and republished by
`/release`, from `OVERVIEW.md` and `docs/ARCHITECTURE.md`, plus
`DECISIONS.md` and `CHANGELOG.md` when they exist. The Markdown wins: the
hub is regenerated from those files, never edited beside them.

In this order:

1. **Product line and status strip.** The overview's description · its
   Status · the latest release · the date it was last updated. The release
   comes from the overview's `**Release:**` field and reads
   `v2.2.0 · 2026-09-25`, the date from that version's `CHANGELOG.md`
   heading, linked to its GitHub release page. No `**Release:**` field →
   leave it out.
2. **Run commands.** The `## Run it` table.
3. **Architecture.** The context and components diagrams.
4. **Slices.** The slices table, each row linking to that slice's spec page.
5. **Links.** README and `docs/ARCHITECTURE.md`.

Write it to `docs/specs/.pages/_hub.html` — next to the spec pages, so the one
ignore rule covers both; the underscore keeps it from colliding with a slice
name. Publish with the Artifact tool from that same path every time, so the
link never changes. Title: the project name.

On the hub's first publish, republish each existing spec page so it gains the
back-link line.

## Style

The page carries the same voice rules as everything else. It is a working
document, not a pitch deck. No hero section, no marketing gradient, no
celebration of the plan. Dense, scannable, honest about what's unresolved.

Open ledger items are the most important thing on the page after the flow
diagram. Make them impossible to miss.
