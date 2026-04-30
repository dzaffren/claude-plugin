---
name: poc
description: >
  Generates a clickable HTML/CSS/JS proof-of-concept prototype to visualise a
  feature for stakeholders. Use whenever someone wants to show what a feature
  could look like — even without saying "prototype" or "POC". Trigger on
  phrases like "mock this up", "demo this idea", "visualise the feature",
  "let's see what this would look like", or any request to preview or
  demonstrate a feature idea. Works after /product-discovery or /prd. Outputs
  self-contained Tailwind-styled HTML to docs/poc/{name}/. When in doubt,
  trigger — a clickable prototype is almost always useful.
---

# POC Generator

Produce a clickable, self-contained HTML/CSS/JS prototype that visualises a
feature for stakeholder review. No build tools, no frameworks, no dependencies
beyond Tailwind CDN — just files a product owner can open in a browser and
share immediately.

**Feature name:** `$ARGUMENTS` — used to locate context and name the output
folder. If empty, see Step 1.

---

## Step 1: Establish What You're Working With

### If `$ARGUMENTS` is empty

List what's available so the PO can orient quickly:

- Any discovery briefs: `ls docs/discovery/` (if the directory exists)
- Any PRDs: `ls docs/specs/` (if the directory exists)

Then ask: "Which feature would you like a prototype for?" and wait for their
answer before proceeding.

### What to ask (only ask what's genuinely missing)

Once you have a feature name, check what the PO has already told you:

- **Screens / flow** — which screens or states to cover? (e.g. "onboarding:
  landing → sign-up → confirmation"). Ask only if not already described.
- **Interactivity level** — pick one:
  - **Clickthrough** — screens linked by navigation only, no state changes
  - **Interactive** — forms, toggles, modals, and UI state (mock data, no real
    API calls)
  - **Full walkthrough** — realistic end-to-end flow where user actions update
    the UI (e.g. submitting a form adds a row, approving a request changes a
    status badge)
    Ask only if not already clear from context.
- **Anything to emphasise?** — specific user roles, edge cases, or error states
  stakeholders need to see. Skip if not relevant.

If the user gave a clear description covering screens and interactivity, skip
straight to Step 2 without asking.

---

## Step 2: Load Context

Load whichever sources exist. If neither exists, work from the user's
description alone.

### Discovery brief

Look for `docs/discovery/{name}/brief.md`. If found with `status: complete`,
extract:

- Desired outcome
- Selected opportunity
- Solution candidates chosen for this feature

### PRD

Look for specs in `docs/specs/` matching the feature name — try
`docs/specs/{name}/spec.md` and `docs/specs/*{name}*/spec.md`. For an epic,
read the overview `spec.md` and treat all stories as one cohesive prototype.

From the PRD extract:

- User stories ("As a [user], I want to...")
- Acceptance criteria (happy paths, key error states)
- Scope (in/out)
- Success metrics (highlight these in the prototype)

**Priority**: PRD drives screen content and flows; discovery brief provides
strategic framing (outcome, opportunity) to inform what matters most.

---

## Step 3: Plan the Screens

Based on context and the PO's answers, map out the prototype:

- Each screen: its purpose and what user action leads to it
- Shared UI elements across screens (nav bar, header, sidebar)
- Which screens show error or empty states
- Navigation map: which button/link on each screen leads where

For **full walkthrough** level, also plan:

- What mock data changes after each action (row added, status updated, count
  incremented)
- What the before and after states look like

**When to confirm with the PO before proceeding:** only pause here for 4+
screens or full walkthrough prototypes. For simpler cases, proceed directly to
Step 4. When you do pause, keep it brief — a short bullet list is enough — then
ask "Does this look right?" and revise if needed.

---

## Step 4: Generate the Prototype

Write files to `docs/poc/{name}/`. Create the directory if it doesn't exist.

### File structure

| File                 | Purpose                                  |
| -------------------- | ---------------------------------------- |
| `index.html`         | Entry point — first screen the user sees |
| `{screen-name}.html` | One file per additional screen           |

Keep everything inline in each HTML file (no separate CSS or JS files) so each
file works when opened directly in a browser without a local server.

### Every HTML file must

- Include Tailwind via CDN in `<head>`:
  `<script src="https://cdn.tailwindcss.com"></script>`
  (Note: requires internet — without it the page renders unstyled. Mention
  this when handing off so stakeholders aren't surprised offline.)
- Be fully self-contained — no external assets that require a server
- Use relative links for navigation between screens (`href="screen-name.html"`)
- Show the feature/product name in the page `<title>` and visible header
- Include back/breadcrumb navigation where appropriate

### Styling

Use Tailwind utility classes throughout. Pick one primary accent colour and use
it consistently across all screens (e.g. `indigo`, `blue`, or `emerald`). Use
responsive breakpoints (`sm:`, `md:`) so the prototype is usable when
stakeholders open it on a phone or tablet.

**Important — Tailwind CDN class names must be complete strings.** The CDN uses
JIT compilation and cannot detect classes built by string interpolation. Write
`bg-indigo-600` directly, never `bg-${color}-600`. This applies to every
dynamic class — always use the full literal class name.

Common patterns:

- Page wrapper: `max-w-screen-lg mx-auto px-4 py-8`
- Card: `bg-white rounded-xl shadow-sm border border-gray-100 p-6`
- Primary button: `bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg font-medium`
- Muted text: `text-gray-500 text-sm`

**Icons and images:** Use inline SVGs for icons — copy simple paths directly
into the HTML. For quick decorative icons, emoji work well and require no
dependencies. Avoid `<img>` tags pointing to external URLs that might be
unavailable.

**Semantic HTML:** Use `<nav>`, `<main>`, `<button>`, and `<a>` instead of
generic `<div onclick>` handlers — it costs nothing and means the prototype
works with keyboard navigation and screen readers out of the box.

### Mock data

Use realistic, specific values throughout — no "Lorem ipsum", no "User 1 /
User 2", no `$0.00`. Invent a believable fictional product name if the real one
isn't known (e.g. "Meridian Analytics", "Vaulto", "Luma Health"). Include at
least 3–5 rows in any table or list. Add status badges, avatar initials, and
timestamps to make screens feel alive.

For **interactive** and **full walkthrough** prototypes, define mock data as a
JS `const` array at the top of the `<script>` block, separate from UI logic:

```js
const mockData = [
  {
    id: 1,
    name: "Priya Sharma",
    status: "pending",
    amount: 4200,
    date: "2026-03-18",
  },
  {
    id: 2,
    name: "Marco Bellini",
    status: "approved",
    amount: 8750,
    date: "2026-03-17",
  },
];
```

### Interactivity

**Clickthrough:** anchor tags only. No JS needed.

**Interactive:** vanilla JS event listeners.

- Modal: toggle `hidden` class on open/close
- Form validation: check fields on submit, show inline error messages
- Tabs: show/hide panels by ID
- Dropdowns: toggle on click, close on outside click

**Full walkthrough:** drive state through a JS array. On user action, mutate
the array and re-render the affected DOM region. Use `innerHTML` for simplicity:

```js
let items = [...mockData];
function render() {
  container.innerHTML = items.map(renderRow).join("");
}
form.addEventListener("submit", (e) => {
  e.preventDefault();
  items.unshift({ id: Date.now(), ...readFormValues() });
  render();
  modal.classList.add("hidden");
});
```

---

## Step 5: Validate

Trace through every user journey step by step — don't just skim. For each
screen, verify:

- [ ] Navigation links to the next screen resolve correctly (no broken hrefs)
- [ ] Every screen from the plan was generated
- [ ] No placeholder text (`TODO`, `Lorem ipsum`, `[Insert X]`, `User 1`)
- [ ] Tailwind CDN `<script>` tag present in every HTML file
- [ ] No dynamically constructed class names (all Tailwind classes are complete
      literal strings)
- [ ] Mock data is consistent across screens — the same name/value appears in
      both the list view and the detail view
- [ ] Every button and interactive element triggers a visible response
- [ ] Each file opens correctly when accessed directly (no server required)
- [ ] Consistent accent colour and spacing across all screens

---

## Step 6: Handoff

Tell the user:

1. Output path: `docs/poc/{name}/`
2. Which file to open first: `index.html`
3. One-line description of each screen
4. Recommended next step based on timing:
   - **After `/product-discovery`**: "Review with stakeholders to validate the
     solution direction, then run `/prd {name}` to write requirements."
   - **After `/prd`**: "Share alongside the PRD for sign-off, then run
     `/prd-refine {name}` to add technical detail."
