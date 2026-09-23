# A worktree agent starts from main, not from your branch

**Learned:** 2026-09-24 · **From:** auto-onboard build

Chunk B of `auto-onboard` depended on chunk A's `load-overview.sh`. A was
already merged into `feat/auto-onboard` before B was launched. B's worktree
still started at `3c25ae6`, the tip of `main`, so the script was missing. The
agent noticed, fast-forwarded to `feat/auto-onboard` itself, and carried on. If
it hadn't noticed, it would have built against the wrong base.

## The rule

The prompt for a dependent chunk must name the commit it needs and tell the
agent to check `git log` for it first. If the commit is missing, the agent
fast-forwards to the feature branch before writing any test. Independent chunks
don't have this problem, because `main` and the feature branch are the same
until the first merge.
