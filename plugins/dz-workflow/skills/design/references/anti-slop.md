# Anti-slop rules (fallback when frontend-design isn't installed)

Distilled from Anthropic's frontend-design skill. The full skill is better —
install it: `/plugin install frontend-design@claude-plugins-official`.

## The three default looks — never ship them

AI-generated design collapses into three clusters. If the output matches
one, it's slop regardless of polish:

1. **Cream + serif + terracotta** — warm off-white background, serif
   display type, terracotta/rust accent. The "tasteful AI startup" look.
2. **Near-black + acid green** — dark UI with a single neon accent,
   usually green. The "AI dev tool" look.
3. **Broadsheet** — white, hairline rules, all-caps micro-labels,
   newspaper pretensions.

## Derive, don't default

- Tokens come from the product: who uses it, where, for what. A field
  logistics tool and a kids' reading app must not share a palette.
- Pick one thing the design commits to (density, warmth, speed,
  authority) and let every token decision serve it.
- Real content only. Design around the spec's concrete examples — long
  names, empty states, worst-case numbers. Lorem ipsum hides layout bugs.

## The two-pass check

After the first pass, ask: "given a similar prompt for a different product,
would I have produced roughly this?" If yes, the design came from the
model's priors, not from this product — revise until the answer is no.

## Mechanical floor

- One token set across all components; no per-component drift.
- Every state the acceptance criteria mention: empty, error, loading.
- Light and dark. Keyboard focus visible. Contrast ≥ 4.5:1 for text.
- No decoration that carries no information.
