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
Status: superseded by D9

## D9 · 2026-09-26 · The finding-verifier's Bash is scoped by a hook on agent_type to read-only git diff, show, log and ls-files

Why: the verifier needs the diff, the base version of a line, history and the file
list; a PreToolUse hook sees the caller's `agent_type` and holds it to those four
read-only commands, refusing options that run a program or write a file. The
seventh seeded run lost turns to 45 blocked `git log` and `git ls-files` calls.
Rejected: `git diff` and `git show` only (D8; verifiers ran out of turns on the
blocked history and file-list calls), raising `maxTurns` above 30 (the turn budget
swung from 0 to 18 across runs of one fixture), pasting diff hunks into the
verifier prompt (the skill would slice a hunk per finding), a prompt-only rule
(nothing enforces it), scoped `tools:` patterns such as `Bash(git diff *)` (not
enforced: a headless probe ran `ls /` through one).
Supersedes: D8
Source: specs/owasp-lens.md
Status: active

## D10 · 2026-09-27 · release.py cut enforces the pentest verdict

Why: a release blocked on a proven critical or high has to stay blocked when a
prompt drifts; cut already refuses and writes nothing on a failed gate, so the
verdict joins that path.
Rejected: a skill-only rule (prompt drift, and the ledger's grep-over-prose rule),
a separate release.py pentest command (a step the skill could skip; cut cannot be
skipped).
Source: specs/pentest.md
Status: active

## D11 · 2026-09-27 · The first pentest is code-level for every project; live attacks follow in pentest-live

Why: zuko itself and most of its projects have no server; a code-level pass with
run proofs covers every release now, and live mode needs a target guard of its own.
Rejected: live mode first (needs a running-server fixture and a guard, and protects
no CLI project), both modes in one slice (about nine scenarios, over the size rule).
Source: specs/pentest.md
Status: active

## D12 · 2026-09-27 · Release notes and the committed report name unfixed medium and low findings without the proving input

Why: users should know a known issue ships; the notes and the committed report are
public and permanent on a public repo, so each finding gets severity, category,
file and a description, and the proving input prints in the terminal only.
Rejected: leaving them out of the notes (the shape's Security section rule), the
full proof in the notes (a working exploit in every release page), the proof in
the committed report (the same exploit, one click from the repo page).
Source: specs/pentest.md
Status: active

## D13 · 2026-09-27 · The pentester's Bash is fenced by a hook on agent_type

Why: the pentester runs the project's own code with Bash, so its commands cannot
be listed in allowed-tools; /review proved that prompt rules alone let it run
git push, git tag and curl. A PreToolUse hook sees the caller's agent_type and
holds zuko:pentester to read-only git, mktemp -d, and commands inside its own
scratch copy.
Rejected: prompt-only rules (the review proved push, tag and curl allowed),
requiring the OS sandbox (a user setting the plugin cannot turn on), deferring to
pentest-live (its target hook never runs in code-level mode).
Source: specs/pentest.md
Status: superseded by D14

## D14 · 2026-09-27 · The pentester fence stops commands, not code

Why: review 2 showed the hook fences the pentester's direct commands, but code
it or the project runs escapes — a pipe into a shell, an interpreter's inline-code
flag, an untracked script, tar reaching outside. The hook is tightened to block
those cheap holes (shells, inline flags, untracked modules and scripts, tar -P),
but a tracked program that opens a socket or writes outside the copy still can.
The fence is a guard against the pentester being steered into an obvious escape,
not a sandbox; untrusted code needs Claude Code's sandbox.
Rejected: claiming the hook confines the pentester (D13's wording; false once
code runs), a full syscall sandbox in the hook (a user setting the plugin cannot
turn on), dropping the hook (the cheap holes are worth closing).
Supersedes: D13
Source: specs/pentest.md
Status: active

## D15 · 2026-09-25 · A review finding is anything the diff introduced, deleted lines and changed callers included

Why: the regressions that do the most damage are removed checks, and a deleted line
leaves no touched line to report on; the old rule threw all of them away.
Rejected: touched lines only (misses every deleted guard), the whole file or repo
(reports pre-existing issues the branch did not cause).
Source: specs/regression-review.md
Status: active

## D16 · 2026-09-25 · Removing a guard that a fix or security commit added raises its severity one tier

Why: that line was put there to close a known hole, so deleting it reopens one; the
reviewer applies the raise from history, so the verifier's lower-never-raise rule
still holds.
Rejected: no history lookup (loses the strongest signal a deletion has), letting the
verifier raise (contradicts the lower-never-raise rule).
Source: specs/regression-review.md
Status: active

## D17 · 2026-09-25 · The reviewer pastes command output as EVIDENCE; the verifier checks it with its read-only git

Why: the verifier judged git and library behaviour from memory and got it wrong twice
(docs/learnings/verifiers-cannot-run-code.md); pasted output is data it can read
without spending turns, and D9's read-only git lets it re-run the command when it
doubts the output.
Rejected: dropping EVIDENCE so the verifier runs the history itself (costs turns on
every history finding; run 7 of owasp-lens lost turns to history calls), leaving it
to recall (proven wrong twice).
Source: specs/regression-review.md
Status: active

## D18 · 2026-09-25 · Coverage findings are two concrete cases, not a coverage number

Why: a changed auth or validation path with no changed test, and a new reachable
function with no calling test, each name a test to write; a percentage names none.
Rejected: a coverage tool and threshold (a per-stack dependency), every new function
(private helpers tested through their caller would all be reported).
Source: specs/regression-review.md
Status: active

## D20 · 2026-09-25 · The attribution hook reads gh pr create bodies and titles from the command line only

Why: /ship opens PRs with gh, and every body it writes arrives as -b, -F or a file
the command names; --fill reuses commit text the commit hook already checked.
Rejected: a PostToolUse check of the opened PR through gh pr view (the PR is public
by then), guarding the GitHub MCP tool in the same slice (not connected here, and
its payload shape is unverified — O2).
Source: specs/pr-attribution.md
Status: active
