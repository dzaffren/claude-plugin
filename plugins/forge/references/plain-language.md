# Plain Language & Trust Standard

Forge's house standard for **everything the user reads** — questions, answers,
recommendations, and summaries — at every stage from discovery through ship.
The goal: a non-technical user can understand and *judge* what forge says,
instead of accepting it on faith or getting something over-built.

Plain by default. The reasoning is always shown. Technical depth is available
the moment the user asks for it.

This pairs with `${CLAUDE_PLUGIN_ROOT}/references/multi-choice.md`: multi-choice
governs the *shape* of an enumerable question (numbered options + a recommended
pick); this standard governs the *voice*, the *reason*, and *depth-on-demand*
for all user-facing output, enumerable or free-form.

## The five rules

1. **Plain language by default.** Every question, answer, recommendation, and
   summary is written in plain language with no unexplained jargon. The plain
   text is what the user reads to make a decision.

2. **A reason behind every recommendation.** Every recommendation carries a
   short, plain-language reason — the basis for *this* pick, and *why this one
   over the alternative* when there is one. A recommendation shown without a
   reason is a defect, not a style choice — the user has no way to judge it.

3. **Show technical detail on demand (default off).** Wherever forge makes a
   recommendation, the user can ask to see the technical detail — but it is
   never shown unless they ask. When they do ask, reveal the deeper explanation
   **and keep the plain version and its reason visible**; detail adds to the
   plain answer, it never replaces it.

4. **Explain unavoidable jargon in plain words.** If a technical term genuinely
   cannot be avoided, explain it in plain words with a concrete description the
   user can follow without already knowing the term.

5. **Show your right-sizing.** When forge keeps something deliberately simple or
   recommends the smaller of two options, it says it did *not* go bigger, and
   why — "a bike when a bike was asked for, not a rocket." This lets the user
   see forge is not over-building.

## How it pairs with multi-choice.md

A multi-choice prompt's `Recommended: <#>` line must also carry a plain "why
this one" reason (rule 2). When an option has technical depth, mention that the
user can ask to see it (rule 3) — but keep the plain options as what they read
to choose.

## When this applies

Everywhere the user reads forge output: discovery questions, `prd` /
`prd-refine` recommendations, the build loop's pre-save summary, `ship`'s
commit-plan and PR summary, and `fix`'s root-cause hypotheses. No stage is
exempt.

## When NOT to belabor it

- Don't bolt a "show technical detail" offer onto a trivial confirmation that
  has no technical depth to show.
- Plain is not verbose. One clear sentence beats a padded paragraph — don't
  over-explain in the name of being plain.

## Examples

**Recommendation with a reason (good):**

> **Recommended: email magic-links for sign-in.** Why: your users sign in
> rarely and from lots of devices, so magic-links skip the password-reset
> dance (your #1 support ticket) and there's no password to leak. _Want the
> technical detail behind this? Just ask._

**Same recommendation, no reason (fails the standard):**

> Recommended: email magic-links for sign-in.
> ← the user can't tell *why*, so they can only take it on faith.

**Jargon explained in plain words:**

> This needs **rate limiting** — in plain terms, we cap how many sign-up
> attempts one person can make in a short window, so nobody can hammer the form
> thousands of times and slow it down for real customers.

**Right-sizing made visible:**

> I'd keep this to a single shared notes page, not a full document system.
> Why: three teammates sharing weekly notes don't need permissions, version
> history, or search yet — a bigger setup is work and complexity you don't need
> today. A bike, since you asked for a bike, not a rocket. _(Ask if you want to
> see what the bigger option would involve.)_
