# Craft

The design standard. Loaded whenever a slice has an interface a human looks
at. Web UI uses all of it; other project types use the parts about clarity and
respect for the reader.

The goal is work that looks like someone with taste made deliberate choices —
not work that looks generated. Everything here serves that.

## Hard bans

Refuse to ship any of these. No exceptions, no "just for the draft".

**Emojis in a product interface.** Ever. Use a real icon set — Lucide,
Phosphor, Heroicons, or hand-drawn SVG. Emojis render differently on every
platform, carry tone you didn't choose, and read as unfinished.

**The generated-UI tells.** These are the shapes a generically-prompted model
produces. If the design has one, it fails:

- purple-to-blue (or teal-to-indigo) gradient hero
- glassmorphism / frosted blur on more than one surface
- the three-card feature grid with circular icon badges
- everything at one font size in the default UI font
- `rounded-2xl` plus a soft drop shadow on every surface
- everything centred, including body text
- floating blurred gradient blobs as background decoration
- an "Elevate your workflow" / "Supercharge your X" headline
- neon-on-near-black dark mode that no light mode justifies
- a pill-shaped badge above every heading
- section after section at identical vertical rhythm

**Fake content.** No lorem ipsum, no `[placeholder]`, no `Product Name Here`,
no invented logos of real companies. Use the concrete examples from the spec.
If you don't have real content, the spec is incomplete — go back and get it.

## What good looks like instead

- **A real type scale.** A defined set of sizes with intent behind the ratio,
  and a pairing chosen for this product. Not one size everywhere, not eleven.
- **Spacing you can name.** A consistent scale (4px or 8px base), applied so
  that related things are visibly related and unrelated things are visibly
  apart. Whitespace is structure, not padding.
- **A restrained palette.** Derived from this product's content and context.
  One accent that means something. Neutrals that carry the weight.
- **Content-driven layout.** The shape of the page comes from what's on it. A
  dense data table and a marketing page should not share a grid.
- **Motion with physics.** Things move the way objects move — accelerate,
  decelerate, have weight. Not linear fades on everything.
- **Deliberate density.** Match how the thing is actually used. All-day
  professional tools should be dense. Occasional consumer flows should breathe.
- **States designed, not defaulted.** Empty, loading, error, and success are
  screens someone designed, not afterthoughts.

## Motion tiers

Pick one per slice at pause 2, write it into the spec.

| Tier | What | Typical use |
|---|---|---|
| **0** | No motion beyond instant state change | High-frequency tools, accessibility-first contexts |
| **1** | Micro-interactions: hover, focus, press, enter/exit. 120–240ms, real easing | Most product UI. The default. |
| **2** | Choreography: scroll-linked reveals, shared-element transitions, staggered lists, page transitions | Marketing pages, onboarding, moments that should feel considered |
| **3** | A signature moment: one 3D / WebGL / canvas piece that carries the brand | Landing pages and launches, where the impression is the product |

**Tier 3 does not pass without a written budget** in the spec:

- bundle size ceiling (kB, gzipped, for the 3D payload alone)
- target frame rate and the device class it must hold on
- what mobile gets instead
- what `prefers-reduced-motion` gets instead
- how it lazy-loads, and what the page looks like before it arrives

No budget, no tier 3. This is the earn-it rule applied to pixels: a 400kB
hero has to justify itself the same way a new service does.

## Floors — never negotiable, any tier

- `prefers-reduced-motion: reduce` is honoured. Every animation has a
  no-motion path that still communicates the state change.
- Animate `transform` and `opacity` only. Anything animating `width`,
  `height`, `top`, or `left` gets rewritten.
- No layout shift caused by motion. Reserve the space.
- Focus is always visible, and the focus order follows the visual order.
- Text contrast meets WCAG AA (4.5:1 body, 3:1 large). Interactive elements
  meet 3:1 against their background.
- Every interactive path works from the keyboard alone.
- Touch targets at least 44×44 CSS pixels on touch devices.
- Works in light and dark, and the choice is deliberate in both.

`/review` checks these mechanically on UI slices. They are not prose.

## References

Taste anchors, not a required stack. Name which one you're aiming at and
**what specifically** you're taking from it, before you design. "Like Linear"
is not a direction. "Linear's information density and its restraint with
colour" is.

| Reference | Take from it |
|---|---|
| **21st.dev** | Component-level motion and interaction detail. What a single control can feel like. |
| **Linear** | Density, keyboard-first interaction, restraint with colour, speed as a design value |
| **Stripe** | Forms, error handling, documentation-grade clarity, progressive disclosure |
| **Vercel** | Restraint, typographic hierarchy, monochrome plus one accent |
| **Framer / Awwwards / Godly** | Site-level ambition, scroll choreography, what tier 2–3 can be |
| **three.js examples** | What is actually achievable in tier 3, and what it costs |

Reference the *reasoning*, never copy the surface. Two products that look
identical to Linear both look like nothing.

## Techniques

Use only what the repo's stack supports. Never introduce a library the
project doesn't already have without saying so and why.

| Need | Reach for |
|---|---|
| React micro-interactions and transitions | Motion (Framer Motion) |
| Scroll choreography, timelines | GSAP + ScrollTrigger |
| 3D / WebGL in React | React Three Fiber + drei |
| 3D, no framework | three.js directly |
| Smooth scroll | Lenis |
| Cross-page transitions | View Transitions API, with a fallback |
| Component library already present | shadcn/ui — follow the shadcn skill's conventions |

## taste-skill v2

`design-taste-frontend` v2 has a direction library, a house style and a
browser inspector. Each design stage uses one part of it (D79). In the
commands below, `<skill>` is the folder that holds the skill's `SKILL.md`.

| Stage | Uses |
| --- | --- |
| `/design-system` pause B | `draw.mjs` deals the candidate directions |
| `/spec` pause 2, `/design` | The house rules and `inspect.mjs` |

**At `/design-system` pause B:** Deal three candidates from the brief. Pick
the sector from the list that `draw.mjs` prints when `--sector` is missing:

```
node <skill>/scripts/draw.mjs --sector <sector> --brief "<one line>" --options 3
```

This prints three directions and writes no file. For each candidate that
the user wants built, deal it in full:

```
node <skill>/scripts/draw.mjs --sector <sector> --brief "<one line>" --direction <id> --out .taste-skill/pause-b/<id>
```

The `--out` folder is not optional. `inspect.mjs` reads
`.taste-skill/direction.json` on every later run and warns on any font that
the sheet did not deal. A sheet left there would argue with the design
system's tokens long after pause B.

**In `/spec` and `/design`:** Do not run `draw.mjs`. The design system
already chose the direction. When a v2 house rule and a design-system token
disagree, the token wins.

Run the inspector on the preview in the mode that fits the screen:

```
node <skill>/scripts/inspect.mjs <preview>
node <skill>/scripts/inspect.mjs <preview> --app
```

Use `--app` for a screen that people work in: a dashboard, a table, a form
or settings. Page mode asks for pictures, a focal headline and motion that
such a screen does not need.

**An inspector FAIL** stops the preview, as a drift-check failure does. Fix
it with the system's primitives and tokens, then run the inspector again.
When the fix needs a token or a component that the system does not have,
offer the two options from "Composition only". When a rule does not fit
this screen, pass `--allow <rule>`, and tell the user the rule and the
reason. Do not show a preview that has an open FAIL.

**Before any v2 script runs**, check that it can run (D80):

1. Run `node --version`. `draw.mjs` needs Node 18 or newer. `inspect.mjs`
   needs Node 22 or newer. On Windows, when `node` is not found, also try
   `"C:\Program Files\nodejs\node.exe" --version`. winget puts Node on the
   machine PATH, and a shell that was open before the install does not see
   it. When that path works, use it in place of `node` for the rest of the
   stage. Do not ask to install a Node that is already there.
2. For `inspect.mjs` only, look for Chrome, Edge or Chromium. The script
   finds them itself, and `CHROME_PATH` overrides the search.

At pause B, a skip means that the directions come from the brief, as when
v2 is not installed.

When a part is missing, ask the user in the question prompt. Do not skip
in silence:

- Question: "The v2 inspector needs Node. Node is not installed. Install it
  now?" When Node is too old, say "needs Node 22 or newer" and name the
  installed version.
- Answers: "Install Node (Recommended)" and "Skip the inspector".

zuko installs no browser. When Node is ready but no browser is found, do
not ask. Print `install Chrome, Edge or Chromium, or set CHROME_PATH`, then
skip.

On "Install", use the installer for the system:

| System | Installer |
| --- | --- |
| Windows | `winget install --id OpenJS.NodeJS.LTS -e` |
| macOS | `brew install node` |
| Other, or no `winget` or `brew` | None. Print `install Node 22 or newer with your package manager`, then skip. |

After a winget install, run Node by its full path,
`"C:\Program Files\nodejs\node.exe"`, as step 1 says. Then run the
inspector on the preview. On every skip, print this line with
the real reason:

```
v2 inspector skipped: <reason>. check-design-drift.sh ran on <paths>.
```

| The missing part | `<reason>` |
| --- | --- |
| No Node | `Node not found` |
| Node too old | `Node v20.11.0 is older than 22`, with the installed version |
| No browser | `no browser found` |

When the installer fails, print this line, then skip:

```
Node install failed: <last line of the installer output>. v2 inspector skipped.
```

`check-design-drift.sh` runs on the preview in every case. A skipped
inspector is never a pass.

## Rendered drift check

`check-design-drift.sh` reads the source text. `check-rendered-drift.sh`
opens the preview in headless Chrome, Edge or Chromium, once in light and
once in dark. It fails any computed colour, font size, font family or
corner radius that is not a token value (D81). Run it after the static
check, on the preview:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-rendered-drift.sh" <preview>
```

`<preview>` is `docs/design/{slice}/preview.html`. On the dev-server path,
it is the preview route URL on `localhost` or `127.0.0.1`. The check opens
no other host, and it blocks each request that the page makes to another
host (D84, D87).

The tokens are the CSS custom properties in the token files. A length
token whose name holds `radius` or `rounded` is a radius token. Every
other length token is a size token. The contents of `img`, `svg`, `video`,
`canvas` and `iframe` are not judged (D83).

| Exit | Means | Do |
| --- | --- | --- |
| 0 | Every value is a token. The line names how many elements it judged. | Go on. |
| 1 | Drift, or the page loads none of the tokens. | Fix with the system's tokens and re-render, as for a static FAIL. Do not show the preview. |
| 1 | `no design system token file found` | Do not loop: there are no tokens to fix with. Skip, and say that `/design-system` makes the tokens. |
| 2 | Node, a browser or the page is not there. | See below. |

On exit 2, read the message:

- **Node not found, or Node older than 22.** Ask to install or skip, with
  the prompt and the installers of "taste-skill v2" above. Say "the
  rendered drift check" in place of "the v2 inspector".
- **No browser, or a wrong `CHROME_PATH`.** Do not ask. Print
  `install Chrome, Edge or Chromium, or set CHROME_PATH`, then skip.
- **The tokens live in `tailwind.config.js`.** Do not ask. Skip (D85).
- **Refused, rendered NOTHING, or could not load.** Fix the call, or
  start the dev server. Then run the check again.

On every skip, print this line with the real reason:

```
Rendered drift check skipped: <reason>. check-design-drift.sh ran on <paths>.
```

For the E7 skip, the line is:

```
Rendered drift check skipped: no design system token file. check-design-drift.sh ran on <paths>.
```

A skipped rendered check is never a pass (D82).

## The two checks, before anything reaches the user

Run both. Failing either means revise, not ship.

1. **Would a generically-prompted model have produced this?** If a one-line
   prompt would land in the same place, the design isn't derived from this
   product. Go back to the tokens and the layout.
2. **Does it hold up next to the reference you named?** Open the reference.
   Compare honestly. If it doesn't, say what's missing and fix that.

## Composition only

When a design system exists, screens are assembled from it. No new component,
no new token, no one-off value.

Needs something the system doesn't have → stop and ask:

- **add it to the system** — a deliberate decision, goes through
  `/design-system`, and every slice inherits it, or
- **rework the screen** with what exists.

Never invent silently. `check-design-drift.sh` enforces this on the code side;
this rule is why.
