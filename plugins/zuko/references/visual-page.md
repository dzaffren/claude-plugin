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

## Style

The page carries the same voice rules as everything else. It is a working
document, not a pitch deck. No hero section, no marketing gradient, no
celebration of the plan. Dense, scannable, honest about what's unresolved.

Open ledger items are the most important thing on the page after the flow
diagram. Make them impossible to miss.
