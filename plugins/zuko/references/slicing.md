# Slicing

One spec is one vertical slice. This file defines what that means, how to
split when it doesn't fit, and how the rules bend by project type.

## What a vertical slice is

A thin cut through every layer the change touches, complete enough to work on
its own.

```
        ┌──────────────────────────────────┐
layers  │ interface │ logic │ data │ deploy │
        └──────────────────────────────────┘
             ▲
horizontal:  build all of one layer first     ← wrong
vertical:    ▓ one thin column, top to bottom ← this
```

Horizontal work ("the API this sprint, the UI next") can't be tested end to
end and can't ship. Vertical work can.

## The slice test

A spec passes only if all four are true. Check them out loud at pause 1 and
write the result into the spec.

1. **Cuts every layer it needs.** No "backend now, UI later". If the slice
   has a user, the user can reach it.
2. **One e2e test can walk it.** One test, following the acceptance criteria
   start to finish, proves the whole slice. If you'd need three unrelated
   tests, it's three slices.
3. **Worth shipping alone.** If it went to production tomorrow with nothing
   else, someone is better off. "Groundwork for later" is not value.
4. **Fits.** More than ~5 acceptance scenarios, or touching more than two
   areas of the system, means it's too big.

Fails any of them → split. Never widen the spec to make it pass.

## How to split

Split along **what the user can do**, never along **what the system has**.

| Wrong split | Right split |
|---|---|
| database layer / API layer / UI layer | share a link · expire a link · protect a link |
| "the models" / "the endpoints" | create a draft · publish a draft · archive one |
| backend team work / frontend team work | one working path, then the next path |

Techniques when a slice is too big:

- **Drop a variation.** One payment method now, the rest later.
- **Drop an interface.** Works in the app now, API for it later.
- **Drop the automation.** Manual trigger now, scheduled later.
- **Drop the scale.** 100 rows now, pagination later.
- **Drop the polish.** Plain error message now, guided recovery later.
- **Happy path only.** Ship it, then a slice for the error cases — but only
  when the error case is rare and not dangerous.

Each dropped thing becomes its own later slice, listed in order.

## Slice 0 — the walking skeleton

On an empty repo, the first slice is a walking skeleton: the thinnest
possible path through every layer, deployed.

```
one screen → one endpoint → one row in one table → back to the screen
     +  one e2e test that walks it
     +  CI running that test on push
     +  deployed to the real target
```

It does almost nothing on purpose. Its job is to prove the rails exist. Every
later slice is then cheap, because nothing structural is unknown.

Slice 0 needs decisions the code can't answer — language, framework, database,
host, CI. Ask them at pause 1, one at a time, and write the answers into the
spec as the record. Never pick a stack silently.

## Project types

Detect from the repo; ask only if genuinely ambiguous. What changes:

| | Web app with UI | API / service | CLI / library | Data / LLM app |
|---|---|---|---|---|
| **Slice is** | screen → endpoint → data | endpoint → data | one command or one public function | one transformation or one prompt path |
| **Interface (pause 2)** | screens, states, motion | endpoint shape, payloads, status codes, error bodies | command surface, flags, output format, help text, error messages | input/output contract, prompt shape, failure modes |
| **Design system** | required | skipped | skipped | skipped |
| **Proven by** | browser e2e | API-level e2e against a real server | invoking the built binary or importing the built package | fixture run end to end, plus evals where output is generated |
| **"Ships alone" means** | a user can do the thing | a caller can call it | a user can run it | a record can flow through it |

Pause 2 always happens. It is the interface stage, not the pixels stage. Only
for web UI does it involve a design system.

## The light path

Small changes skip ceremony. Trigger it automatically when all of these hold:

- the change is a bug fix, a rename, a dependency bump, or a copy change
- it touches ≤3 files
- it adds no new interface, no new data, no new dependency

Then: one pause instead of three, no design system check, one reviewer instead
of a panel, no feature flag required. The e2e requirement still holds if the
repo has an e2e suite — a bug fix without a regression test is how the bug
comes back.

Say out loud which path you took and why, in one line.

## Earn it

The rule against over-engineering. No new layer, service, abstraction,
interface, config option, cache, queue, or dependency unless a named
acceptance criterion or a written risk demands it.

Every added piece names its trigger in the spec:

> Added a `ShareTokenRepository` — scenario 3 needs token lookup by value and
> by report, and the existing `ReportRepository` has no access to the tokens
> table.

Can't name the trigger → cut it. When in doubt, write the dumb version. The
second time it hurts, that's evidence, and evidence justifies the abstraction.

Things that are never justified by "we might need it": a plugin system, a
config file for one value, an interface with one implementation, a generic
handler for one case, a queue for work that finishes in 50ms.
