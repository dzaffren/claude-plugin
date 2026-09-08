---
name: status
description: >
  Shows where every slice sits — version, status, open items, branch, and the
  next command. Use when the user asks "where are we", "what's next", "what's
  in flight", "status".
disable-model-invocation: false
---

# Status

Where everything is, in one screen. Read the files; report what is actually
there, never what should be there.

```!
git status --short --branch
git branch --list
```

## Gather

- `docs/specs/*/shape.md` — the ideas and their slice lists.
- `docs/specs/*.md` — the live specs. Skip `archive/`.
- Each spec's `**Status:**`, `**Version:**`, `**Depends on:**`, and its
  ledger.
- Branches matching `feat/*` and `spike/*`.
- `docs/learnings/INDEX.md` — the lesson count.

## Print

```
IDEA: share reports publicly              docs/specs/share-reports/shape.md

  #  slice                    ver  status    open  next
  1  public-report-link       v1   Shipped     0   —
  2  share-link-expiry        v1   Refined     2   /build (blocked: 2 open)
  3  share-link-password      —    —           —   /spec
  4  share-view-analytics     —    —           —   /spec

  branches:  feat/share-link-expiry (4 commits, 2 ahead)
  stale:     spike/webhook-idempotency — spike branches should be deleted
```

Then, only when true:

- **Blocked** — specs with open ledger rows, listing them. This is the first
  thing to say.
- **Drift** — a `Shipped` spec whose files were later modified by another
  slice. Name both.
- **Stale** — a spec `Refined` for a long time with no branch, or a spike
  branch still alive.
- **No design system** — the project is web UI and none exists.

End with one line: the single next thing worth doing, and the command for it.
Recommend, do not list options.

Nothing exists yet → say so and suggest `/shape`.
