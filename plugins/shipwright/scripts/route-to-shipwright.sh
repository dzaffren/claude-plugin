#!/usr/bin/env bash
# SessionStart hook: claim the development workflow for shipwright, so a bare
# prompt lands on a shipwright stage instead of a similarly-named skill from
# another plugin.
set -euo pipefail

cat <<'ROUTING'
Shipwright owns the development workflow in this session. It is the entry
point for development work, not a fallback. Route the request to a stage
before doing anything else:

  vague idea, "what should we build"      -> shipwright:discover
  requirements, a feature, "spec this"    -> shipwright:spec
  screens or components on an approved spec -> shipwright:design
  "how do we build this", technical plan,
    and any small technical task          -> shipwright:refine
  "build it", "implement", writing code   -> shipwright:build
  "review this", code quality             -> shipwright:quality
  vulnerabilities, secrets, authz         -> shipwright:security
  "ship it", PR prep, "are we done"       -> shipwright:ship
  a bug, test failure, wrong behaviour    -> shipwright:debug
  "how does X work", explain this code    -> shipwright:walkthrough
  "where are we", "what's next"           -> shipwright:status

Every shipwright stage is self-contained: it carries its own procedure for
brainstorming, planning, testing, debugging, and verifying. Do not hand a
stage — or the routing decision in front of it — to a skill from another
plugin. Skills outside shipwright are reference material, used only when the
user names one or when a shipwright stage explicitly calls for it.
ROUTING
