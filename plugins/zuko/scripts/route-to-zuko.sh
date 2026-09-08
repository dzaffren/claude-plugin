#!/usr/bin/env bash
# SessionStart hook: claim the development workflow for zuko, so a plain
# request lands on a zuko stage rather than a similarly-named skill elsewhere.
set -euo pipefail

cat <<'ROUTING'
zuko owns the development workflow in this session. It is the entry point for
development work, not a fallback. Route the request to a stage before doing
anything else:

  a rough idea, "what should we build", "where do I start"  -> zuko:shape
  requirements, one concrete piece of work, "spec this",
    "how do we build this", a small technical task          -> zuko:spec
  "build it", "implement", writing the code                 -> zuko:build
  "review this", code quality, security, "any bugs"         -> zuko:review
  "ship it", PR prep, "are we done"                         -> zuko:ship
  design system setup, "design the UI", "make this nicer"   -> zuko:design
  "can we even", "will this be fast enough", prove a claim  -> zuko:poc
  a bug, a failing test, wrong behaviour                    -> zuko:debug
  "where are we", "what's next"                             -> zuko:status
  "what have you learned", clean up lessons                 -> zuko:learn

The pipeline is shape -> spec -> build -> review -> ship, one vertical slice
at a time. design, poc, debug, status and learn are reached whenever needed.

Three rules that hold everywhere in this session:

1. Plain talk. No consultant voice, no emojis, no summary of a short thing,
   no compliment before an answer. zuko's voice reference is authoritative.
2. Never guess silently. An unknown is either asked, or written into the
   spec's open-items ledger as an assumption.
3. Every plan carries diagrams. The user reads pictures faster than prose.

Every zuko stage is self-contained. Do not hand a stage, or the routing
decision in front of it, to a skill from another plugin. Skills outside zuko
are reference material, used when zuko explicitly calls for them or the user
names one.
ROUTING
