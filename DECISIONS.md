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

## D19 · 2026-09-25 · Shaped and Refined need zero Open rows; a shape hands a later slice's question forward instead

Why: the approval at the end of /shape and /spec is the user's review gate, and an
Open row there is a guess the user is approving without seeing; /build already
refuses them, but only after the approval.
Rejected: allowing Refined with Open assumption rows (the question surfaces only
at /build), resolving a later slice's question in the shape (a false answer written
down as true).
Source: specs/ledger-handoff.md
Status: active

## D20 · 2026-09-25 · The attribution hook reads gh pr create bodies and titles from the command line only

Why: /ship opens PRs with gh, and every body it writes arrives as -b, -F or a file
the command names; --fill reuses commit text the commit hook already checked.
Rejected: a PostToolUse check of the opened PR through gh pr view (the PR is public
by then), guarding the GitHub MCP tool in the same slice (not connected here, and
its payload shape is unverified — O2).
Source: specs/pr-attribution.md
Status: active

## D21 · 2026-09-25 · Inside a Mermaid fence, only decision-node braces are exempt from the placeholder check

Why: a decision node (an id, then its label in braces) is Mermaid syntax, not a
blank; any other brace in the fence, such as a blank in a box label, is still one
someone forgot.
Rejected: skipping every line inside a Mermaid fence (turns false blocks into false
allows for blanks in node labels), keeping the quote-the-label workaround (every
spec author has to know an undocumented rule).
Source: specs/mermaid-placeholder.md
Status: active

## D22 · 2026-09-25 · /design-system is its own skill; /design system prints the new name

Why: one skill with two modes chosen by the word "system" cannot design a screen
called system, and figma-brief extends only the design-system half.
Rejected: keeping both modes in one skill (the ambiguity stays), dropping the old
spelling silently (old specs and habits hit an unknown-mode error), a permanent
alias that runs the system mode (two names for one thing).
Source: specs/design-system.md
Status: active

## D23 · 2026-09-25 · Terminal replies draw diagrams in ASCII; Mermaid stays the source in files and pages

Why: Claude Code's terminal prints Mermaid as source, and the user already asked
for ASCII there; files and pages render Mermaid and diff cleanly in git.
Rejected: Mermaid everywhere (unreadable in the terminal), ASCII in the files too
(pages lose rendered diagrams, and ASCII diffs badly), a Mermaid-to-ASCII converter
(a dependency for what the model can draw directly).
Source: specs/ascii-terminal.md
Status: active

## D24 · 2026-09-25 · /shape reads a Jira ticket when the whole argument is a key and Jira is connected, and never writes to Jira

Why: a ticket already holds the problem statement; reading it saves the retyping,
and zuko uses an integration only when it is already there (shape O7).
Rejected: commenting or transitioning the ticket from /shape (a write the user did
not ask for, and a setup flow the shape ruled out), asking the user to paste the
ticket (the MCP is already connected), matching a key anywhere in the argument (an
idea that mentions a ticket is still an idea).
Source: specs/jira-shape.md
Status: active

## D25 · 2026-09-25 · The glossary gate checks a closed term list, in live docs only

Why: a named list of 17 terms can be read and argued with; live docs (Draft and
Refined specs, and shapes) are the ones still being read to make decisions.
Rejected: detecting jargon by heuristic (false positives with no way to argue), a
separate config file for the list (one list, one reader), checking Built and Shipped
specs (they are records, and every old spec would fail).
Source: specs/glossary-gate.md
Status: active

## D26 · 2026-09-25 · /design-system reads a Figma file only when Figma is already connected, and only reads

Why: a team's Figma variables are the brief's answers already; connecting Figma is
the user's own setup, and zuko's rule is to use an integration only when it is there.
Rejected: asking for an exported tokens JSON (a manual step the MCP removes), prompting
the user to connect Figma when no link was given (mentions a tool they may not use),
writing tokens back to Figma (a setup flow, out per the shape).
Source: specs/figma-brief.md
Status: active

## D27 · 2026-10-05 · The release step sends the live requests; the pentester's fence stays untouched

Why: the pentester's Bash is fenced by scope-pentester-bash.sh (D14), which blocks
curl. Rather than carve a hole in a boundary reviewed twice, the fenced pentester
reads the code and names the A01/A07 requests, and the release step sends them with
curl from its own main-thread context and feeds the responses back to judge. D14 is
left exactly as it shipped.
Rejected: loosening the fence to let the pentester curl the target host while the
target file exists (reopens the fence, and one mistake there is an attack on a third
party); a second fenced sub-agent allowed to curl (two boundaries to keep in step).
Source: specs/pentest-live.md
Status: active

## D28 · 2026-10-05 · A hook, not the prompt, holds the live pentest to its one target

Why: a request to a host the user did not name attacks a third party; the guard
reads one file the skill writes, the way block-dangerous.sh guards destructive
commands. It guards the release step's main-thread curls (D27).
Rejected: a prompt rule alone (drifts, and one miss is an attack on someone else), a
network sandbox (sandbox-exec is deprecated on macOS; Docker is a dependency most
projects lack).
Source: specs/pentest-live.md
Status: active

## D29 · 2026-10-05 · Live proofs read, and change only data the run created

Why: staging often holds shared or real data; a proof that deletes another user's
invoice is damage, not evidence, and reading it proves the same hole.
Rejected: any request that proves the hole (destroys staging data), no write
requests at all (cannot test create or delete routes).
Source: specs/pentest-live.md
Status: active

## D30 · 2026-10-06 · The main-branch guard lets through only the release commit cut prepared

Why: D1 sends the release commit straight to main, and block-dangerous.sh blocked
every commit on main, so v2.2.0 stopped at step 4 and needed the user's `!`. cut
writes .git/zuko-release with the version, HEAD and the files it wrote; the guard
allows a commit on main only when all three match a plain `git commit -m`. Binding
HEAD retires the marker once the commit lands, with no cleanup step.
Rejected: any `chore(release):` subject (any commit can claim it), keeping the block
and handing the commit to the user (stops /release halfway, against D1), deleting
the marker after the commit (a step every exit path must reach), comparing file
content (the user chose to allow edits to the same files).
Source: specs/release-commit-guard.md
Status: active

## D31 · 2026-10-06 · The guards on git commit fail closed on a payload they cannot read

Why: the v2.2.0 pentest proved P3 and P4: a lone surrogate made the payload parse
raise, the exit 0 after it passed the command, and a force push and a staged secret
went through. block-dangerous.sh, secret-scan.sh and block-attribution.sh now block
with a reason instead.
Rejected: failing open (proven bypass), failing open with a warning (the command
still runs unchecked).
Source: specs/release-commit-guard.md
Status: active

## D32 · 2026-10-06 · The pentester fence drops tools whose arguments are code or an output file

Why: awk's program and sed's script run commands and write files the fence
never sees, the same hole as `python3 -c`; `sort -o`, `uniq`'s second argument
and `file -C` overwrite files in the real repo. The v2.2.0 pentest proved awk
(P1), and a probe on 2026-10-06 proved the other four through the live hook.
Rejected: parsing awk and sed programs for `system`, pipes, redirects, `w` and
`e` (a parser that infers misses spellings), blocking only sort's `-o`,
`--output` and `--compress-program` (every bundled and abbreviated spelling to
guard), keeping sort and its siblings for a later slice (one of them writes the
real repo today).
Source: specs/pentester-fence-awk.md
Status: active
