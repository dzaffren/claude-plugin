# The visual page

Every spec publishes one page. The Markdown is the source of truth; the page
is how the user looks at it.

## Why both

The terminal is where the work happens, and Mermaid renders there fine. But a
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

## Hub page

One page for the whole project; each slice's page links from it. Built by
`/ship` at close-out, and republished by `/release`, from `OVERVIEW.md` and
`docs/ARCHITECTURE.md`, plus `DECISIONS.md` and `CHANGELOG.md` when they
exist. The Markdown wins: the hub is regenerated from those files, never
edited beside them.

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
