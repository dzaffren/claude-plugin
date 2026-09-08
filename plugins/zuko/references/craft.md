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
  `/design system`, and every slice inherits it, or
- **rework the screen** with what exists.

Never invent silently. `check-design-drift.sh` enforces this on the code side;
this rule is why.
