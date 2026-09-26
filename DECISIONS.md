# Decisions

Append-only. A changed decision is a new entry that supersedes the old one; only an
old entry's Status line ever changes.

## D1 · 2026-09-25 · Release commits go straight to main

Why: one command runs start to finish; a PR would stop `/release` halfway, waiting
for a merge, with the version already chosen.
Rejected: release branch plus PR (pauses mid-release; only needed for a protected
main, which zuko's repos do not have today).
Source: specs/release.md
Status: active

## D2 · 2026-09-25 · zuko computes the release version itself

Why: the rule is four lines — breaking gives major (minor below 1.0.0), feat gives
minor, fix gives patch — and zuko already parses the commit types for the changelog
gate.
Rejected: git-cliff (a dependency for four lines), semantic-release (a Node
dependency that releases without a human yes), commitizen (a Python dependency whose
changelog lines are commit subjects, already rejected by the changelog slice).
Source: specs/release.md
Status: active

## D3 · 2026-09-25 · No feat, fix or breaking commit means no proposed release

Why: a version number promises a change; with none since the last release there is
nothing to promise. semantic-release and commitizen both default to no release here.
Rejected: proposing a patch anyway (a patch promises a fix nobody made).
Source: specs/release.md
Status: active

## D4 · 2026-09-25 · Security severity is a 3 × 3 exploitability × impact grid

Why: the verifier has to place a finding and may only move it down; three rows and
three columns can be judged from a diff, and "between two tiers pick the lower"
resolves every tie.
Rejected: CVSS (eight base metrics, most not judgeable from a diff), Anthropic's
one-line HIGH/MEDIUM/LOW guide (no rule for a finding between tiers), 1–10
confidence scores (the blind verifier already filters; out per the shape).
Source: specs/owasp-lens.md
Status: active

## D5 · 2026-09-25 · Review exclusions start from Anthropic's security-review, and OWASP wins where they clash

Why: Anthropic's 17 exclusions and 12 precedents remove known false-positive
classes; three of them would hide OWASP 2025 categories (A03, A09, A10), so those
are narrowed to the diff instead of kept.
Rejected: OWASP alone with no exclusions (every env var and escaped template gets
reported), Anthropic's list whole (drops lockfile changes and removed security
logging).
Source: specs/owasp-lens.md
Status: active

## D6 · 2026-09-25 · Untrusted text in a prompt is a finding only when it can steer a tool call or a file write

Why: zuko's skills read PR templates, web pages and review comments; text there
that makes a skill run a command the user did not ask for is a real attack, while
text that only colours the model's answer is not.
Rejected: Anthropic's exclusion 14 as written (would miss a skill obeying a PR
template), no exclusion (every LLM call reported).
Source: specs/owasp-lens.md
Status: active

## D7 · 2026-09-25 · Severity orders the review report; it does not change what gets fixed

Why: a confirmed finding has a traced failing path whatever its tier, and `/review`
already fixes every confirmed finding; severity's job is order here and the release
block in slice 5.
Rejected: leaving low findings unfixed in the report (a confirmed bug left in by
default).
Source: specs/owasp-lens.md
Status: active

## D8 · 2026-09-26 · The finding-verifier's Bash is scoped by a hook on agent_type

Why: without `git diff` the verifier burned its turns hunting base versions (17
turn-limit events in the second seeded run), and the resumes that rescued it leaked
the finder's context; a PreToolUse hook sees the caller's `agent_type` and can hold
the verifier to read-only `git diff` and `git show`.
Rejected: pasting diff hunks into the verifier prompt (the skill would slice a hunk
per finding; the verifier seeing the diff itself was preferred), a prompt-only rule
(nothing enforces it), scoped `tools:` patterns such as `Bash(git diff *)` (not
enforced: the docs give no such form and a headless probe ran `ls /` through one).
Source: specs/owasp-lens.md
Status: active
