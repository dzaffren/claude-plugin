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

## D33 · 2026-10-07 · The release-commit check refuses braces and globs outside quotes

Why: `whole_call` counts shlex tokens as git's arguments, but bash expands an
unquoted `{a,b}`, `*`, `?` or `[` into several words after the check passes. The
v2.3.0 pentest found it (P1), and a probe on 2026-10-07 showed
`-m {body,--all}` reach git as `-m body --all` on main. As shlex punctuation,
those characters split out only when unquoted, and the existing check refuses them.
Rejected: allow-listing the raw command's characters (the release body names
`[2.3.0]` inside quotes, so real releases would block), a hand-written quote
scanner (more code for the answer shlex already gives).
Source: specs/release-commit-brace.md
Status: active

## D34 · 2026-10-07 · The force-push check reads git's spellings of force, not shell variables

Why: git 2.52.0 forced a bare remote with `-uf`, `--mi` and `origin +main`, and
the check read only `--force` and `-f`. bash builds any of those from a brace
or glob after the hook reads the text, so a push holding one blocks with its
own reason.
Rejected: blocking `$` and backticks in a push (it would stop
`git push -u origin "$(git branch --show-current)"`), reading git config for
`remote.*.mirror` or a `+` push refspec (config set outside the command is out of
a command hook's sight). Both stay known limits: a command hook stops mistakes,
not a push written to get past it.
Source: specs/force-push-expansion.md
Status: active

## D35 · 2026-10-09 · Stop hooks judge only the zuko docs this work changed

Why: in 18 logged sessions across 7 projects the hooks failed turns over docs
the task never touched, and an old Built spec in Raslaw failed every turn until
fixed. A doc changed on the branch since the merge-base, staged, unstaged or
new is still judged, so a spec committed earlier in the same turn is caught.
Rejected: every doc on every turn (today; pulls Claude off its task),
uncommitted changes only (a spec set to Refined and committed in the same turn
is never checked), a warning for untouched breaches (/status already shows
each spec's open rows).
Source: specs/stop-hook-scope.md
Status: active

## D36 · 2026-10-09 · A zuko spec is known by its Version and Status line, a shape by its file name

Why: 118 docs in 8 local repos sit under docs/specs without the template's
`**Version:** vN · **Status:**` line. They are runbooks and other tools'
specs, and each fails today's gate. Raslaw keeps 20 real zuko specs in idea
folders, so the path cannot tell the two kinds apart.
Rejected: top-level docs/specs/*.md only (misses Raslaw's 20 nested specs),
any file with a `**Status:**` line (the runbook has one).
Source: specs/stop-hook-scope.md
Status: active

## D37 · 2026-10-12 · zuko writes to the ASD-STE100 writing rules, and a project's own writing rules win

Why: the house rules in voice.md had no limits, so the user could not check a
draft against a standard. In the five newest zuko docs, 14 of 209 prose
sentences had more than 25 words. ASD-STE100 Issue 9 gives published limits:
20 words in an instruction and 25 in a description.
Rejected: the house rules alone (no limit that the user can look up), the STE
dictionary of about 900 approved words (the repo has no copy of the standard,
so no word can be checked against it), STE over the project's CLAUDE.md
inside zuko docs (the user's global CLAUDE.md already lets a project's file
override it).
Source: specs/ste-voice.md
Status: active

## D38 · 2026-10-12 · The STE rules are prompt text, and nothing measures sentence length

Why: a contract test proves that the rules are in voice.md. The next real
stage stop shows whether Claude follows them. A gate on sentence length would
stop Claude in the middle of a task, which D35 removed from the Stop hooks.
Rejected: a Stop-hook gate on new long sentences (pulls Claude off its task),
a ste-check.py script that the user runs (the user chose not to build it,
2026-10-12), a headless claude -p proof (a spike that the user did not take,
2026-10-12).
Source: specs/ste-voice.md
Status: active

## D39 · 2026-10-12 · At a /spec or /shape pause, every unknown is asked in the question prompt

Why: 27 ledger rows in 10 specs say "default chosen autonomously". Four rule
texts let Claude write an assumption instead of asking, and pauses 1 and 2
could pass with rows Open. The auto-mode text says that a skill's rule to ask
wins, so the rule can require it.
Rejected: ask or write an assumption (today; Claude picked 27 answers alone),
assume and continue when there is no question prompt (answers that Claude
picked alone reach the next pause), a gate for each pause (a spec has no
marker for its pause; the Shaped and Refined gates stay, D19), the
/design-system pauses as well (a third area, outside this slice).
Source: specs/pause-questions.md
Status: active

## D40 · 2026-10-12 · An unproven row offers /poc before the recommended answer

Why: shape O4 makes a spike a choice that the user makes each time. The user
chose /poc first, always, also when the evidence already settles the claim
(spec O5). The recommended answer comes second, marked "(Recommended)".
Rejected: the recommended answer first, with /poc after it (the user chose
against it, 2026-10-12), running /poc without asking (shape O4).
Source: specs/pause-questions.md
Status: active

## D41 · 2026-10-12 · The last question at a pause approves it, and /build stays user-only

Why: one key approves /spec pauses 1 and 2. For /shape, "Which slice do we
spec first?" approves the shape. /build has disable-model-invocation: true, as
/review, /ship and /release do, so Claude cannot start it, and pause 3 ends
when the user types /build.
Rejected: a typed "proceed" as today (O3), "Approve the shape?" before the
slice question (two questions where one does, O7), a "Run /build now?" answer
with /build open to model invocation (Claude could then start /build for any
request that sounds like "build it", O8).
Source: specs/pause-questions.md
Status: active

## D42 · 2026-10-12 · /build and /review decide alone and add a row; they never stop to ask

Why: a run left alone should finish. Since pause-questions the pauses ask
every unknown, so what is left comes up during the run. A `Decided alone` row
says Chose, Other and Undo, so each choice is seen and can be undone at the PR.
Rejected: stopping to ask as today (a run waits for the user in five places),
stopping only when a scenario is dropped (O2), a free sentence in the Answer
(decision-pr could not pick out each part, O6).
Source: specs/unattended-build.md
Status: active

## D43 · 2026-10-12 · /review fixes a Decisions finding by obeying the entry

Why: D7 fixes every confirmed finding. To supersede an entry changes
DECISIONS.md, which stays the user's call through /spec, at the PR.
Rejected: leaving the code as it is with a row (a confirmed finding left in,
which D7 rejected; shape O5, O1), offering two fixes and waiting (a stop).
Source: specs/unattended-build.md
Status: active

## D44 · 2026-10-12 · A blocker ends /build at the end of the run, with the spec at Draft

Why: the scenarios that do not need the secret, the account or the service
still get built and tested. The one Open row is answered with /spec continue.
Rejected: stopping at once (the rest waits for an answer it does not need,
O3).
Source: specs/unattended-build.md
Status: active

## D45 · 2026-10-12 · A chunk-builder makes a choice only when it changes its own files

Why: file ownership keeps parallel chunks apart. A choice in its own files
cannot break another chunk. A choice that needs another chunk's file is made
by /build when it integrates.
Rejected: stopping and reporting as today (/build then builds the rest of the
chunk itself, O7), a choice in any file (two chunks could write one file).
Source: specs/unattended-build.md
Status: active

## D46 · 2026-10-13 · /ship builds the PR body from the spec: Your call, then Review, then what ships

Why: PRs 80 to 86 put "Your call" first, written by hand from memory, and some of
its choices were in no spec row. A body built from the Decided alone rows and the
Review section is the same after a new session. From ## Review down it has 300
words or fewer; the last four had 356 to 550. A row added after the PR opens is
rendered again into the body.
Rejected: rewording each row for the reader as PRs 80 to 86 did (the PR can drift
from the spec, O7), /ship's own choices in the body only (the spec stops being the
one record, O4), the scenario list (about 60 words that the spec link covers, O10),
Your call under the template's best heading (it can end up last, O5), 200 words or
no number (O3), a PR comment for a late row (O12), Review cut to its counts line
(O13).
Source: specs/decision-pr.md
Status: active

## D47 · 2026-10-13 · /review writes its result into the spec, and the ship gate fails a spec without it

Why: /review printed its findings to the terminal only, so a /ship in a new session
had nothing to report. Each run adds a dated line and one line for each fix. No line
is removed, so a clean second run does not hide the first run's fixes.
Rejected: /ship building the result from git log (the raw count is lost, O2), the
session's memory only (O2), each run replacing the section (O8), a hand check in
/ship (prompt rules drift, O9).
Source: specs/decision-pr.md
Status: active

## D48 · 2026-10-13 · The ship gate fails a Decided alone row that lacks Chose, Other or Undo

Why: the Your call table copies the three parts. A row with no Undo shows the user a
choice with no way back. unattended-build O8 left this check to decision-pr.
Rejected: "not recorded" in the empty cell (the PR opens with a gap, O6), prompt text
only as D38 (nothing catches a missing part, O6).
Source: specs/decision-pr.md
Status: active

## D49 · 2026-10-13 · When /ship cannot open the PR, it prints the body to paste

Why: two of the user's work repos are on gitlab.com, where /ship opens nothing and
the body was lost. A four-backtick fence holds the body, so a code block in it does
not end the fence.
Rejected: the push link only, as before (O1), opening a GitLab merge request (GitLab
was dropped on 2026-09-25, v3-release-and-hosts O13).
Source: specs/decision-pr.md
Status: active

## D50 · 2026-10-13 · One pr_body.py reads the rows for the ship gate and for the PR body

Why: the gate and the Your call table need the same split of each row into Chose,
Other and Undo. With one parser, the table cannot show a row that the gate did not
check, and a test can compare the output word for word.
Rejected: an awk check in verify-ship-gates.sh while Claude copies the rows (no test
can prove the copy, O11).
Source: specs/decision-pr.md
Status: active

## D51 · 2026-10-13 · The shared command parser refuses a command over 64 KB

Why: shlex grows a word one character at a time, so a 1.1 MB command took the
verifier guard 19.6 s and block-dangerous 21 s. A timed-out hook lets the call
through. At 64 KB a parse takes 0.14 s, and each caller already handles a
command it cannot parse.
Rejected: a rewrite of shlex that is linear for any size (a new parser in
every guard, which must match shlex token for token), a longer alarm in the
test (the guard still takes 20 s, and a timed-out hook lets the call through),
128 KB or 16 KB as the limit (O2), "onFailure": "block" on the guard hooks
(no guard nears the timeout with the limit, and older versions' handling of
the field is not known, O3).
Source: specs/tokenise-linear.md
Status: active

## D52 · 2026-10-13 · block-dangerous blocks a command that the shared parser cannot read

Why: on exit 3, the raw-text patterns missed `git -C . push --force` and
`git -C . commit`. A comment with an apostrophe, or an unclosed heredoc, sent
a force push to that check, and bash ran it. bash runs the lines before an
unclosed quote, and an unclosed heredoc to the end of the text, so "bash
cannot run it either" was false. This corrects the Why of D51: not every
caller's cannot-parse path was safe.
Rejected: keeping the raw-text check (proven bypass), a raw pattern that
reads git's options (each spelling that git takes is a new miss), a block in
each guard (block-dangerous.sh runs on every Bash call, and its block covers
them).
Source: specs/fail-closed-parse.md
Status: active

## D53 · 2026-10-13 · The shared parser reads `#` comments as bash does

Why: shlex started a comment at any `#`, so `echo x#;` hid the command after
it. The heredoc pass read quotes and `<<` inside comments, so `# it's` made
the parser refuse the command, and `# <<EOF` hid the lines after it.
Rejected: refusing `#`, as the agent fences do (a main-thread command needs
comments), keeping shlex's comment rule (proven bypass).
Source: specs/fail-closed-parse.md
Status: active

## D54 · 2026-10-13 · The attribution hook reads gh pr edit and gh pr merge as it reads gh pr create

Why: /ship replaces the PR body with gh pr edit --body-file when a row lands
after the PR is open, and gh pr merge --subject and --body write the merge
commit on the base branch. The hook read only create, so both passed a signed
body (checked on v2.4.0).
Rejected: reading only create (proven gap), also reading gh pr comment and gh
pr review (git-naming.md does not ban attribution there, O1).
Source: specs/pr-edit-attribution.md
Status: active

## D55 · 2026-10-13 · The shared parser refuses a `<<` inside arithmetic or `${ }`

Why: bash reads `<<` as a shift inside `(( ))`, `$(( ))`, `$[ ]` and `${ }`,
so a line such as `(( 1 << X ))` made the parser drop the lines after it, and
a force push there passed block-dangerous.sh (v2.4.1 pentest). But bash reads
`((cat << X); (true))` as two subshells and a heredoc, so neither reading is
safe alone. A backslash-newline that splits one of these openers or a `<<` is
refused too, because the walk reads one line at a time.
Rejected: reading `<<` inside them as a shift (the `((` subshell form then
hides a heredoc body), joining continued lines before the walk (time grows
with the square of the joined lines, D51).
Source: specs/arith-heredoc.md
Status: active

## D56 · 2026-10-13 · The attribution hook gives each value option of gh pr create and gh release create its value

Why: a value option the create tables did not know left its value in the
walk, so -Bnext read as -t and --target -t took -n as the title. The signed
body or notes after it were never read (checked on v2.4.1, main 4ef85fe).
Rejected: listing only -B and --target, the two found cases (-Hfeat and
--label -t fail the same way), reading -T/--template as a body file (gh
2.101.0 refuses it with --body, and needs a prompt without one, O2).
Source: specs/gh-create-value-options.md
Status: active

## D57 · 2026-10-13 · Scripts with pipefail give grep -q its text with a here-string

Why: under pipefail, grep -q can exit at a match before printf writes its next
line. printf then dies of SIGPIPE, the pipeline returns 141, and the if reads
the match as a miss. With strace pausing printf, block-dangerous.sh passed a
force push, and secret-scan.sh passed a staged key. bash writes a here-string
in full before grep starts, so no writer can die. A static check in
test-secret-scan.sh holds every script with pipefail to this.
Rejected: process substitution (printf can still die, and pipefail does not
see it, O5), [[ =~ ]] (^ and $ match only at the ends of the whole text),
set +o pipefail around each check (more lines at each of 14 sites), a strace
test alone (it cannot run where strace is missing, such as macOS, O1).
Source: specs/pipefail-grep-race.md
Status: active

## D58 · 2026-10-13 · The shared parser refuses a heredoc body in `"$( )"` that changes its quotes

Why: inside a double-quoted `$( )` or backticks, bash skips the quotes in
a heredoc body, and the parser read them. One `"` in the body made the
lines after the heredoc text, and a force push there passed
block-dangerous.sh (main 4ef85fe, v2.4.1). Each body line must now leave
the parser's state as it found it. A `<<` on a body line counts
too, because bash may have ended that body early or never opened it (O6).
Rejected: a check only at the line that ends the body (bash ends it at
the next backtick inside backticks, and bash 5.1 also at a line `EOF)`),
dropping the body as other heredoc bodies are (block-attribution.sh reads
the commit body in the `-m` word), refusing each `<<` inside `"$( )"` (it
blocks the standard commit form), one rule for each way bash ends a body
early (each missed way is a bypass, O6).
Source: specs/quoted-subst-heredoc.md
Status: active

## D59 · 2026-10-13 · Release v2.4.2 ships without a pentest

Why: The pentester run was stopped by a safety classifier before it attacked the parser and hooks. Each of the four fixes in this range was reviewed with bypass inputs run against bash, and every review finding is fixed and tested.
Rejected: running the pentest before v2.4.2 (The pentester run was stopped by a safety classifier before it attacked the parser and hooks. Each of the four fixes in this range was reviewed with bypass inputs run against bash, and every review finding is fixed and tested.)
Source: docs/security/v2.4.2/report.md
Status: active

## D60 · 2026-10-13 · /ship marks a slice Shipped before the push, in the slice's own PR

Why: after the merge the branch is gone and block-dangerous.sh blocks a
commit on main, so 31 of 96 merged PRs here were status-only. On main,
Shipped now means merged with every gate green; the signal check still
runs, but does not gate the word.
Rejected: a close-out commit after the merge (main is closed to it), a
second status-only PR for each slice (31 of 96 PRs here), republishing the
hub page only at /release (the hub falls behind until a release), a
ship-gate check that fails a spec or row not at Shipped (the flip sits in
the refresh step that already sets the row each time, and seven fixtures
would change).
Source: specs/shipped-in-pr.md
Status: active

## D61 · 2026-10-13 · /ship gives the ship gate the spec path

Why: with the spec at Shipped before the gate, the gate's no-argument
search for a Built spec finds nothing; the path also stops the gate from
checking another slice that main still has at Built.
Rejected: a no-argument search that also finds Shipped specs (it reads
every spec in docs/specs, and 40 are Shipped, so it would gate the wrong
one).
Source: specs/shipped-in-pr.md
Status: active

## D62 · 2026-10-25 · A script renders the idea board; Claude only publishes it

Why: the board must look the same after every stage and every new session, and a
test must prove what it shows. `board.py` reads the files with the parsers the gates
already use (D50), so the board cannot show a row that the gates read in another
way.
Rejected: Claude writes the HTML at each stage (the page changes from run to run,
and no test can check it), Claude edits the last page (it drifts from the files).
Source: specs/idea-board.md
Status: active

## D63 · 2026-10-25 · The board is a claude.ai page; localhost serves it only when the publish fails

Why: a claude.ai page opens on a phone and needs no process (shape O3). When the
publish fails, `board.py serve` on 127.0.0.1:4751 still shows the board (O4). It
checks the Host header, so a hostile page cannot read it through DNS rebinding
(O10).
Rejected: a local live server as the main host, as in Backlot (laptop only, a new
process, shape "Not doing"), a local file with no server (the user chose a server,
O4), plain `python3 -m http.server` (no Host check, O10), stopping the stage until
the publish works (a network blip blocks work).
Source: specs/idea-board.md
Status: active

## D64 · 2026-10-26 · The board draws its diagrams with Mermaid 11.16.1, loaded by the page

Why: every spec already holds its diagrams in Mermaid (D23), and the board must show
them readably in a dark page. claude.ai's built-in Mermaid drew them, but the user
could not read them (O13). The page loads a pinned Mermaid from jsDelivr and draws on
paper colours that it sets itself, on claude.ai and on localhost alike. 11.16.1 is
the first version with no known advisory; 11.12.0 let a classDef put HTML outside its
diagram (GHSA-ghcm-xqfw-q4vr), and cdnjs does not serve 11.16.1.
Rejected: claude.ai's built-in Mermaid (colours not set by the page, O13), SVG made
at render time by mermaid-cli (Node and a headless Chrome on every machine), D2 or
Graphviz (each spec's diagrams written twice, against D23), a light panel behind the
built-in Mermaid (plain, and no diagrams on localhost), Mermaid 11.12.0 from cdnjs
(nine advisories, review O21).
Source: specs/idea-board.md
Status: active

## D65 · 2026-10-26 · The gate card compares the spec with a git-ignored copy from the last stop

Why: the spec is not committed between pauses, and the card must show what changed
since the user last looked (gate-card O1). After each publish at a stop, the stage
copies the file to `docs/specs/.pages/<name>-last.md`. A missing copy says so on the
card, and never guesses.
Rejected: a commit at each stop (a commit per stop, and a stop is not a logical
chunk), no Changed part (the pain the slice exists for).
Source: specs/gate-card.md
Status: active

## D66 · 2026-10-26 · The gate card's Changed part is a summary by section, scenario and row

Why: the user reads the card to decide whether to approve, and a line diff of a
3,000-word spec is the wall of text the board replaces (gate-card O2). The summary
names each changed `##` section, each scenario by name, and each new or answered row.
Rejected: a full line diff (long, and it hides the one change that matters).
Source: specs/gate-card.md
Status: active

## D67 · 2026-10-26 · With a board, a pause prints only the Board line, one ASCII picture and the questions

Why: the board carries the scenarios, the slice test and the rows, so printing them
again buries the questions (gate-card O4, shape O4). The question prompt still asks
every Open row, as D39 needs. A spec with no board prints as before.
Rejected: keep the scenario list in the terminal too (the same facts in two places).
Source: specs/gate-card.md
Status: active

## D68 · 2026-10-26 · The PR card reads the spec's Test plan and Changes tables, not the branch diff

Why: the card must still show what met each scenario after the merge, when the branch
is gone (pr-gate O1). The spec's Test plan names a test per scenario, and each Changes
row names its scenarios, so the spec alone ties each scenario to its tests and files.
Rejected: the spec checked against the branch diff (works only while the branch
exists), the diff alone (it cannot tell which scenario a file serves).
Source: specs/pr-gate.md
Status: active

## D69 · 2026-10-26 · The PR card shows on every render for a slice at Built or later

Why: a shipped slice keeps a record of what met each scenario, which is the shape's
"what a shipped slice changed" pain (pr-gate O2). The card reads only the spec, so any
stage can draw it.
Rejected: the card only on the render that /ship makes (the next stage's render would
drop the record).
Source: specs/pr-gate.md
Status: active

## D70 · 2026-10-26 · A script renders the hub's Ideas section; the rest of the hub stays hand-written

Why: the Ideas rows read every shape and every spec they name, about 31 files today. They must read them as the board does (D62), and a test must prove each row.
Rejected: Claude writes the rows at each stage (the same misreads that D62 stops, and no test), a script renders the whole hub (about twice the work, better as its own slice).
Source: specs/library.md
Status: active

## D71 · 2026-10-26 · Replay finds a squash commit's PR with gh api, and reads its commits from refs/pull/N/head

Why: in this repo, gate-card, pr-gate and library each reached main as one squash commit, and only their PRs hold the pause commits. The squash subjects carry no PR number, and gh api names the PR exactly (caf25a7 → 104 in 0.6 s).
Rejected: main only (each squash-merged slice is one step), a stop log in each spec (every spec gains a section), matching PR heads by file content through git ls-remote (a guess when two PRs hold the same file).
Source: specs/replay.md
Status: active

## D72 · 2026-10-26 · A replay step holds the stages and the changes, not the whole board

Why: the user steps through how the idea moved. The stages and the gate card's change tags show that in about 0.4 KB a step, 15 KB for living-board's 38 steps.
Rejected: the whole board at each commit, with diagrams and panels (about 40 KB a step, 1.5 MB for 38).
Source: specs/replay.md
Status: active

## D73 · 2026-10-26 · A replay step changes only the Replay strip

Why: the board above shows the idea as it is now. A step card with its own stage chips never mixes past and present on one page.
Rejected: restaging the filmstrip and the rail at each step (the reader cannot tell at a glance which parts show the past).
Source: specs/replay.md
Status: active

## D74 · 2026-10-26 · Replay keeps its PR lookups in a git-ignored file, not in git refs

Why: a cached run touches no network. A file in docs/specs/.pages/ adds nothing to the user's repo, and a head that git gc drops is fetched again.
Rejected: refs under refs/zuko/pr/ (they show in git log --all and stay until removed by hand), no cache (one gh call per squash commit at every render).
Source: specs/replay.md
Status: active

## D75 · 2026-10-26 · The fence check flags a fence that opens inside an open block, not only a block left open

Why: idea-board.md at a5cb93f lost its Acceptance criteria section to an unclosed fence, yet its fences paired up again later and the file ended with no block open. A fence with a language name, opened inside a block with the same or longer marker, catches it, and no doc in the repo trips it.
Rejected: flag only a block still open at the end of the file (passes the real broken spec), flag a "## " heading inside a block (flags 22 docs and skill files that show headings in examples).
Source: specs/unclosed-fence.md
Status: active

## D76 · 2026-10-26 · The fence check runs in the Stop hook on each changed doc at any Status, and not in the ship gate

Why: a broken fence hides sections from the board and the PR body at any Status, and D35 already keeps an untouched doc out of the check. Each turn that touched a spec passed the Stop hook, so the ship gate would only check it again.
Rejected: Draft and Refined only, as the glossary check (a Shipped spec edited by /ship could carry a broken fence), the ship gate too (a second place to keep the same rule).
Source: specs/unclosed-fence.md
Status: active

## D77 · 2026-10-27 · board.py refuses a shape whose slice name has a / or \, and does not skip the row

Why: a Slice cell with `../` made board.py read a .md file outside docs/specs into a published board (pentest P1, v2.5.0). A refusal names the slice, so the shape is fixed in one edit.
Rejected: skipping the row and rendering the rest (the slice would vanish from the board with no sign), resolving the path and checking it stays under docs/specs (no real slice name needs a /).
Source: specs/slice-name-path.md
Status: active

## D78 · 2026-11-01 · The vendored taste skill is pinned to a tag, and design stages announce newer releases

Why: an unpinned lock swapped v1 for v2 without a choice (#121). A tag pin stops that,
and a notice at the start of each design stage tells the user that a newer release
exists (spec O2, O5).
Rejected: follow upstream main (the silent swap comes back), check at every session
start (a network call when no design work happens), show it only in `/status` (the
user sees it only when they ask).
Source: specs/taste-skill-upgrade.md
Status: active

## D79 · 2026-11-01 · Only /design-system deals directions from the taste skill

Why: one design system is the product's identity (D22). v2 directions belong where the
look is chosen, at pause B. `/spec` pause 2 and `/design` use the v2 house rules and the
inspector only, so a slice cannot drift from the system (spec O1).
Rejected: all design stages deal directions (a slice drifts from the system), no stage
deals them (pause B keeps a weaker direction test).
Source: specs/taste-skill-upgrade.md
Status: active

## D80 · 2026-11-01 · A missing Node is installed on request, and a skip is always announced

Why: the v2 inspector needs Node 22 and Chrome, Edge or Chromium. The user picks
install or skip, and a skip prints its reason and still runs `check-design-drift.sh`,
so a skipped check never reads as a pass (spec O3, O7).
Rejected: stop the stage until Node exists (blocks design work for a check), skip in
silence (reads as a pass), print instructions only (the user asked for an install).
Source: specs/taste-skill-upgrade.md
Status: active

## D81 · 2026-11-01 · The rendered drift check judges colour, type and radius, in light and dark at 1440px

Why: a token defines these values one to one, so an off-token value is drift. A colour set
only under `prefers-color-scheme: dark` is a real drift that one light render misses
(spec O1, O2).
Rejected: spacing (flex and auto margins compute off-scale values that are not drift),
light only (misses a dark-only colour), a second render at 390px (doubles the renders for
a rare media-query drift; overflow at 390px belongs to `rendered-floors`).
Source: specs/rendered-drift-check.md
Status: active

## D82 · 2026-11-01 · A rendered drift FAIL stops the preview, and a render that cannot run never exits 0

Why: the user sees only previews that conform, as with `check-design-drift.sh`. A gate that
rendered nothing must never read as a pass (lesson gate-scanned-nothing-is-not-a-pass).
Rejected: warn and show the preview (the drift reaches the user), stop the pause when Node
or a browser is missing (blocks design work; D80 already asks install or skip).
Source: specs/rendered-drift-check.md
Status: active

## D83 · 2026-11-01 · The rendered drift check has no allow attribute; it skips only media contents

Why: craft.md says that a value the system lacks is a proposal to the system, not a one-off.
The contents of `img`, `svg`, `video`, `canvas` and `iframe` are not CSS-styled UI (spec O5).
Rejected: a `data-drift-allow` attribute with a reason (an escape hatch that a stage can use
in place of a proposal to the system).
Source: specs/rendered-drift-check.md
Status: active

## D84 · 2026-11-01 · The rendered drift check opens files and localhost URLs only

Why: the dev-server path needs a URL, and a gate must not send requests to a host that it
was pointed at by text in a spec (spec O6).
Rejected: files only (the dev-server path stays unchecked), any URL (the gate makes network
requests to any host).
Source: specs/rendered-drift-check.md
Status: active

## D85 · 2026-11-01 · Tokens only in tailwind.config make the rendered check skip, announced

Why: the browser resolves CSS variables only. A Tailwind v3 project has no CSS token, so
the check cannot judge it, and D82 would stop each preview of that project (spec O7).
Rejected: exit 1 and stop the preview (forces the project to move its tokens before any
preview passes), load `tailwind.config.js` with Node (the gate runs the project's own code
and its plugins).
Source: specs/rendered-drift-check.md
Status: active

## D86 · 2026-11-01 · The rendered drift check drives the browser from Node 22, with no package

Why: only a browser computes styles, and Node 22 has the WebSocket that the DevTools protocol
needs. A spike on this machine rendered light and dark in 1.9 s (spec O8). D80 already covers
a missing Node.
Rejected: Python with a hand-written WebSocket client (about 100 lines of framing to own and
test), Playwright (a package and a browser download of about 150 MB for each user), the v2
`cdp.mjs` in place (v2 is repo-local and does not ship with zuko).
Source: specs/rendered-drift-check.md
Status: active

## D87 · 2026-11-01 · The rendered drift check blocks each request to a host that is not local

Why: D84 keeps the page local, and a preview can still name a CDN for fonts or images. With
the block, the check sends no request off the machine, and its result does not depend on the
network (spec O9).
Rejected: let subresources through (the gate sends requests to each host that the preview
names).
Source: specs/rendered-drift-check.md
Status: active

## D88 · 2026-11-01 · The dark render sets the media query, a .dark class and data-theme="dark"

Why: design systems switch to dark in three common ways, and shadcn and Tailwind use a class.
With the media query only, a class-based system gets two light renders, and its dark drift is
missed (spec O10).
Rejected: the media query only (misses class-based dark mode).
Source: specs/rendered-drift-check.md
Status: active

## D89 · 2026-11-07 · zuko's repo checks out every text file with LF, on every OS

Why: Git for Windows sets core.autocrlf=true, and 366 of 414 tracked files reached
the Windows work tree as CRLF, the installed plugin included. One rule in
.gitattributes overrides it for every clone.
Rejected: asking each user to set core.autocrlf=false (a setting on each machine, and
it changes every other repo of theirs), making each script and test strip \r (dozens
of readers, and a new one forgets), `* text eol=lf` without auto (git would treat the
PNG files as text unless each one is listed).
Source: specs/lf-checkout.md
Status: active

## D90 · 2026-11-07 · The pentester reads a pinned copy of Cloudflare's attack-class files from the plugin

Why: the pentester runs in every project, so the files ship with zuko. A pin at `c1c8a8c` keeps the link to upstream fixes. `ATTACK-CLASSES.md` and 9 companions are copied with the MIT licence (spec O1, shape O4).
Rejected: each project installs the Cloudflare skill (zuko stages do not hand work to another plugin), rewrite the files in zuko's words (loses the link to upstream fixes), all 15 files (the four phase docs describe phases that zuko does not run), RESOURCE-EXHAUSTION-AND-AVAILABILITY.md (D5 excludes every DoS finding).
Source: specs/attack-classes.md
Status: active

## D91 · 2026-11-07 · The pentester picks companion files from the upstream index, against the release range

Why: the index gives each companion a target line, and the range is what the pentest hunts. A companion is read only when the range touches its kind of code, and each one gets an Assessed or Not assessed line (spec O2, O5).
Rejected: a fixed map by project type (a CLI with a Dockerfile misses CLOUD-AND-DEPLOYMENT), read every file on each release (uses turns on classes with no code to hunt), match against the whole repo (more Assessed lines for the same hunt).
Source: specs/attack-classes.md
Status: active

## D92 · 2026-11-07 · Where a class file and zuko's rules disagree, zuko's rules win

Why: the class files only add places to look. The Never-a-finding list (D5), the severity grid (D4), a proof that the pentester ran, and no network stay. A lead that Cloudflare calls needs_validation is dropped until slice needs-validation (spec O3).
Rejected: Cloudflare's rules win for its own classes (conflicts with D4, D5 and the proof rule, and each needs a superseding entry).
Source: specs/attack-classes.md
Status: superseded by D101

## D93 · 2026-11-07 · The attack-class pin check speaks only when upstream changed a copied file

Why: the check runs once for each release. A notice for a README-only commit is noise, and the user stops reading it. Like D78, it only tells and never copies (spec O4).
Rejected: a notice for any newer commit (README and phase-doc commits are noise), an automatic update of the copy (D78: a silent swap of prompt text).
Source: specs/attack-classes.md
Status: active

## D94 · 2026-11-07 · Class files report in the Assessed lists, and a class finding keeps an OWASP category

Why: one line for each class file, under the headings that exist, keeps `release.py cut` unchanged. `CATEGORY` reads `A0N:2025 name · class`, so the blind verifier still reads its OWASP section (spec O6, O7, O8).
Rejected: one line for each class (40 or more lines in a report), a new report section (cut must learn it), a class-only category (the verifier must learn to read class files).
Source: specs/attack-classes.md
Status: active

## D95 · 2026-11-07 · A message that the attribution guard cannot read is blocked, on every OS

Why: a message file that the guard could not open passed on every OS: a missing file, a
`$VAR` path, `-F -` from a heredoc, and on Windows every Git Bash path. Each one let a
Claude trailer through, which D31 forbids for a payload.
Rejected: blocking on Windows only (the `$VAR`, stdin and same-command cases stay open
on Linux and macOS), reading the heredoc body for `-F -` (a pipe into stdin still cannot
be read), keeping the pass (the guard stays fail-open).
Source: specs/guard-paths.md
Status: active

## D96 · 2026-11-07 · The hooks convert a Git Bash path with cygpath, and only on Windows

Why: Git Bash converts a path only when it passes it as an argument, and a hook gets the
command as text inside JSON. `cygpath -m` reads Git Bash's own mount table, so `/tmp`,
`/c/...` and `/usr` all convert as bash sees them.
Rejected: a hand-written map of `/c/` to `C:/` (misses `/tmp`, `/usr` and any custom
mount), setting MSYS2 environment variables (they change argument conversion, not text
inside the payload), converting on every OS (Linux and macOS have no cygpath and need no
change).
Source: specs/guard-paths.md
Status: active

## D97 · 2026-11-07 · The pentester fence compares its paths with POSIX rules on every OS

Why: the fence judges the text that Git Bash runs, such as `cd /tmp/tmp.Zr93Np`. Windows
`os.path.normpath` turned `/` into `\`, so no scratch path passed and every proof was
blocked (attack-classes O11).
Rejected: converting each path with cygpath before the compare (the fence then judges a
path that bash never sees, and `/tmp/..` folds differently), leaving it blocked (no
Windows pentest can prove a finding).
Source: specs/guard-paths.md
Status: active

## D98 · 2026-11-08 · Each zuko Python process sets its own stdio to UTF-8 with LF

Why: Windows Python starts with cp1252 stdio and writes CRLF. `board.py render` and `decisions.py active` crashed on `→`, and `pr_body.py render` wrote 13 CR bytes in 13 lines. `PYTHONUTF8=1` still wrote `a→\r\n` on this machine. A `reconfigure` loop as the first statement fixes the encoding and the line end, in the 11 `lib/*.py` scripts and the 14 inline snippets in the hooks.
Rejected: `PYTHONUTF8=1` in the hooks (`print()` still writes CRLF, the skill commands that Claude runs do not get it, and it leaks into the user's own child processes), a shared `lib/utf8.py` module (each inline snippet must put `lib/` on `sys.path`, and a guard that cannot import it cannot read its payload), a bash reader that strips each CR (a command can carry a real `\r`, which `release-commit.py` checks).
Source: specs/utf8-stdio.md
Status: active

## D99 · 2026-11-08 · A byte that is not UTF-8 passes through zuko's Python as it came

Why: a guard must read the whole command, and a gate must report on an old Latin-1 commit subject, not crash on it. `surrogateescape` keeps each such byte on input and writes the same byte on output, which is what Windows Python already did with cp1252.
Rejected: replacing the byte with U+FFFD (a guard then checks text that differs from the command, and a published page refuses U+FFFD), stopping with an error (a gate stops on one old commit subject, and a strict read on Linux crashed where Windows went on).
Source: specs/utf8-stdio.md
Status: active

## D100 · 2026-11-08 · A lead that the pentest cannot prove goes under Needs validation, with no severity, and never blocks

Why: the pentester dropped each unproved lead, so a hole in a Windows-only branch was never seen on a Linux release. Each lead names the one fact that decides it. `cut` refuses a report without the section, so an absent section never reads as no leads (spec O5, scenario 5).
Rejected: drop the lead, as D92 did until this slice (the user never hears of it), a severity for a lead (a guess about impact would block or pass a release with no proof), a cap at 10 leads (hides leads), an optional section (a pentester that ran out of turns leaves no section).
Source: specs/needs-validation.md
Status: active

## D101 · 2026-11-08 · Where a class file and zuko's rules disagree, zuko's rules win, for leads too

Why: the class files only add places to look. The Never-a-finding list (D5), the severity grid (D4), a proof that the pentester ran for each finding, and no network stay. A lead that Cloudflare calls `needs_validation` becomes a LEAD block. D5 stops a lead too, and an untrusted-text lead needs a trace to a tool call or a file write (D6) (spec O4).
Rejected: Cloudflare's rules win for its own classes (conflicts with D4, D5 and the proof rule), only D5 applies to leads (every skill that reads PR text gives a lead), neither applies (DoS leads in every report).
Supersedes: D92
Source: specs/needs-validation.md
Status: active

## D102 · 2026-11-08 · Release notes count the leads, and the report names each lead without its trace or check

Why: the notes and the committed report are public and permanent. One count line tells readers that leads exist. Each report row has the category, the place, the claim and the unknown fact. The trace and the check print in the terminal only, as D12 does for `PROOF` (spec O1, O2).
Rejected: one notes line for each lead (unproved guesses on each release page), no notes line (readers do not know that leads exist), the trace and the check in the report (a near-exploit one click from the repo page).
Source: specs/needs-validation.md
Status: active

## D103 · 2026-11-08 · A blind verifier checks each lead's trace, and a broken trace drops the lead

Why: the pentester's word alone fills the section with guesses. The verifier gets `KIND: lead` and confirms only when each step of the trace is real, nothing upstream stops it, and the repo does not answer the unknown. It never sees the check (spec O3).
Rejected: the pentester's leads go straight into the report (no second look, more noise), the verifier's finding rules for leads (rule 1 rejects every lead, because a lead has no observed outcome).
Source: specs/needs-validation.md
Status: active

## D104 · 2026-11-08 · A Windows workflow on branch pushes proves the suite while zuko is built on Linux

Why: this slice is built on Linux, and its done line is 0 failures on Windows. GitHub's `windows-latest` runner is the only Windows that a Linux session can reach. GitHub starts a `workflow_dispatch` workflow only from the default branch, but a `push` trigger runs from a file on a branch. Claude pushes only when the user says so, so the user starts each run.
Rejected: the user's Windows machine (the last two full runs there stopped on low memory, utf8-stdio O7), Linux plus the docs only (nothing then proves the Windows claim), a dispatch-only workflow merged to `main` first (one more PR and merge before the first proof).
Source: specs/portable-suite.md
Status: superseded by D126

## D105 · 2026-11-08 · A check whose setup Windows refuses prints SKIP with the reason, and never counts as a pass

Why: without Developer Mode, `ln -s` makes a copy, so a symlink check would pass or fail on a plain file. A SKIP line names the check and the reason, as the lesson "a gate that scanned nothing must never exit 0" asks. The Windows way runs first: `icacls` denies a read, and a real symlink is used when Windows allows it.
Rejected: fail the check (a green run then needs Developer Mode on every Windows machine), pass it quietly (a check that ran nothing would count as proof).
Source: specs/portable-suite.md
Status: active

## D106 · 2026-11-08 · run.sh gives each test file 600 s, and a file past it fails

Why: `e2e-board` hung on Windows until it was stopped by hand, and a hang blocks `/release` at its tests gate. On Windows, `release` ran past 300 s, so 600 s gives it twice that.
Rejected: 300 s (a slow Windows machine may fail `release`), no limit (a new hang still blocks the run).
Source: specs/portable-suite.md
Status: active

## D107 · 2026-11-08 · On Windows, zuko's Python finds gh and bash on PATH itself, and runs a script through bash

Why: CreateProcess looks in Python's own folder, the current folder and `System32` before PATH, and appends `.exe` only. So `release.py` misses a test's stub `gh`, and may start WSL's `bash.exe` from `System32`. Git Bash walks PATH in order and runs a `#!` script, and zuko now does the same.
Rejected: `shutil.which` (it searches the current folder first, and finds a name with no extension only from Python 3.12), a `ZUKO_GH` variable for tests (a setting that only tests read, and the real `gh.exe` still wins without it), `.cmd` stubs (`cmd.exe` splits the `&` in `status?per_page=100&page=1`).
Source: specs/portable-suite.md
Status: active

## D108 · 2026-11-08 · board.py turns the Git Bash rewrite of --by back into the typed text

Why: Git Bash rewrites `/spec x pause 1` to `C:/Program Files/Git/spec x pause 1`, and the board shows it. The live board said `C:/Program Files/Git/ship utf8-stdio` on 2026-11-08. One repair in `board.py` covers each stage's call.
Rejected: `MSYS_NO_PATHCONV=1` in six skill commands (one missed command shows the bug again), `--by` without its leading `/` (every caller and the board's text change).
Source: specs/portable-suite.md
Status: active

## D109 · 2026-11-09 · A coverage unit is a tracked file outside tests, docs and root Markdown

Why: `git ls-files` gives the list, a path stays the same across runs, and git says when it changed. zuko has 148 units. Prompt files under `plugins/` count, because agents obey them, and vendored `.agents/skills/` counts (spec O1, O2).
Rejected: a function (a parser for each language, and a rename loses the history), Cloudflare's surface, boundary, subsystem and class units (a recon map each run, and the shape left out Cloudflare's phases), every tracked file (tests and docs use turns on nothing to attack), leaving out vendored skills (zuko loads them, and nothing would read them).
Source: specs/coverage-ledger.md
Status: active

## D110 · 2026-11-09 · Each release pentest adds up to 10 old files, picked by release.py: leads, then resets, then path order

Why: 10 files take zuko's 148 units through in about 15 releases and leave turns for the range. A script gives the same pick each run, so a test can predict it (spec O3, O5).
Rejected: 5 files (about 30 releases), 20 files (a large range runs out of turns), the largest files first (vendored files crowd out small hooks), a random pick (no test can predict it), a pick in the prompt (prompt drift).
Source: specs/coverage-ledger.md
Status: active

## D111 · 2026-11-09 · The coverage ledger is committed at docs/security/coverage.md, and cut refuses one it cannot read

Why: the next release on any clone reads it, and the release commit carries it with the report. It names files, not holes. A ledger that cut cannot read stops the release, as a bad report does, so an empty ledger never reads as no coverage. `cut` prints the Coverage line, and the report stays as the skill wrote it (spec O4, O6).
Rejected: a git-ignored ledger (lost on a new clone), a new ledger in place of a bad one (all history lost without a word), the Coverage line written into the report by cut (cut copies the report as it is).
Source: specs/coverage-ledger.md
Status: active

## D112 · 2026-11-09 · Strix runs from release.py on its own copy, next to the pentester, and a skip or a failure never stops the release

Why: the pentester stays the floor for a user with no key (shape O5). `release.py` runs Strix, so a stub `strix` can test the readiness check, the run and the parser, and the skill branches on one `STRIX:` line. A skip or a failure prints why, and the report lists Strix under Not assessed (spec O5). Spike run 1 hung for 3 minutes and spent $0, so `release.py` stops a run after 30 minutes. The $10 budget stops the spend (spec O2, O11).
Rejected: a typed reason when Strix fails (Strix is optional, and the pentester still ran), the skill running `strix` in Bash (no test can walk it), the pentester's scratch copy (Strix mounts its target writable), no time limit (a hung run holds `/release`).
Source: specs/strix-code.md
Status: active

## D113 · 2026-11-09 · A Strix finding in the release's files goes to a blind verifier; a rejected one goes under Needs validation, and the others stay in the terminal

Why: Strix proves each finding in its own sandbox, so a rejection can mean only that the verifier could not trace it (spec O4). Its `BASE` is the pentester's: the last tag, or none for an old file (spec O8). In spike run 3, nearly all 12 findings were in older files, and they would come back in each report. So a finding outside the range and `OLD FILES` is printed and counted only (spec O13). An info finding is not a hole (spec O7). A Strix run marks no file checked, because Strix does not say which files it read (spec O6).
Rejected: dropping a rejected finding (loses a sandbox proof), `BASE: none` for each Strix finding (an old hole blocks an unrelated release), old-code findings under Needs validation (the same rows in each report), info as low, marking the range files checked (Strix may not open them).
Source: specs/strix-code.md
Status: active

## D114 · 2026-11-09 · zuko installs Strix only on request, with a pinned uv tool install, and refuses a strix older than 1.7.0

Why: `uv tool install strix-agent==1.7.0` pins the version and runs no remote script (spec O3). In spike run 1, Strix 1.4.1 erased the keys in `~/.strix/cli-config.json`: its `persist_current()` rewrites the file from the environment only. 1.7.0 keeps them (spec O12). A skip, or no `uv`, gives one Strix skipped line, as D80 does for Node.
Rejected: `curl -sSL https://strix.ai/install | bash` (an unpinned remote script), `pipx install` (no pipx on this machine), any `strix` on PATH (spec O10: 1.4.1 erases keys), the file's keys copied into the environment for 1.4.1 (zuko would work around a Strix bug).
Source: specs/strix-code.md
Status: active

## D115 · 2026-11-09 · Each Strix run is standard mode with a $10 budget

Why: spike run 3 took 10 minutes and $9.14, and the budget ended it. 10 runs use about $91 of the $100 a month (spec O2).
Rejected: quick with $5 (a shallower run), deep with $25 (4 runs a month).
Source: specs/strix-code.md
Status: active

## D116 · 2026-11-09 · zuko's Python writes `/` in each path that it prints, writes to a file, gives to git or compares as text

Why: on Windows, `os.path` builds `docs\adr\0001-use-make.md`, and 26 checks of the Windows suite failed on it. git always gives `/`, so `DECISIONS.md`, the gate messages, the board's Replay and the release marker disagreed with it. `.replace(os.sep, "/")` is the idiom of `stop_scope.py:78`, and on Linux and macOS it changes nothing.
Rejected: `posixpath` in place of `os.path` (on Windows it misreads `C:\` paths in `isabs` and `join`), replacing each `\` on every OS (a Linux file name can hold `\`), a shared helper (six one-line sites in four scripts).
Source: specs/windows-paths.md
Status: active

## D117 · 2026-11-09 · A Windows run whose only failure is the Chrome start check passes after one rerun

Why: `e2e-rendered-drift` "a 404 page prints E6 with its status" fails in some Windows runs with `CDP timeout: Page.navigate`. It failed in portable-suite runs 2 and 4 and passed in runs 1 and 3 (its O18). The cause is Chrome's start time on the runner, and its fix belongs to `windows-ci`.
Rejected: only a run with 0 failed counts (each run takes about 17 minutes, and this slice does not touch that check).
Source: specs/windows-paths.md
Status: superseded by D127

## D118 · 2026-11-09 · On Windows, program.argv() never hands CreateProcess a bare program name

Why: CreateProcess looks in the current folder before PATH, so a bare `git` runs the `git.exe` at the root of the project that a hook runs in. A program that is not on PATH now raises `FileNotFoundError`, as a missing program does on Linux.
Rejected: give the bare name back so the caller's error path runs (a planted `git.exe` still runs when PATH has no git), set `NoDefaultCurrentDirectoryInExePath` (it drops the current folder only; Python's own folder and System32 still come before PATH).
Source: specs/exe-lookup.md
Status: active

## D119 · 2026-11-09 · Each program that zuko's Python starts goes through program.argv()

Why: four `git()` helpers and the attribution guard's `cygpath` started a bare name, so each was open to a planted `.exe`. A check in `test-program.sh` fails a new `subprocess.run([` in `lib/` that skips `program.argv()`, on every OS.
Rejected: fix only the four `git` calls that the shape named (the `cygpath` call in `block-attribution.sh` has the same hole), `shutil.which` (on Windows it looks in the current folder first).
Source: specs/exe-lookup.md
Status: active

## D120 · 2026-11-09 · Strix attacks a staging URL only after a yes in each run, and no zuko guard holds its requests

Why: Strix sends its requests from its Docker sandbox, which no Claude Code hook sees, so D28 and D29 do not cover them (shape O6). The question names the host, the missing guard, the data loss and the HEAD that staging should run (spec O7, O9). Only an exact yes sends Strix live (spec O10).
Rejected: a hook or proxy that holds Strix to one host (its traffic leaves from the container, past every hook), one yes kept for later releases (a later release can name another host), typing the host again to confirm (slower for the same check).
Source: specs/strix-live.md
Status: active

## D121 · 2026-11-09 · Strix goes live only on a staging URL; a localhost target keeps it to the code

Why: Strix rewrites localhost to host.docker.internal, which on Linux reaches the Docker bridge and not an app bound to 127.0.0.1 (spec O2). release.py refuses a loopback --live value too.
Rejected: a reachability probe from a container, then a live run (more code and a Docker test for a target the shape did not ask for).
Source: specs/strix-live.md
Status: active

## D122 · 2026-11-09 · A live release has one Strix run on the copy and the URL, within D115's $10

Why: one run keeps 10 releases a month on $100 (spec O4).
Rejected: a code run and a live run at $10 each (about 5 releases a month), one run at $20 (supersedes D115 for each live release).
Source: specs/strix-live.md
Status: active

## D123 · 2026-11-09 · A live Strix finding with no code location goes under Needs validation, with its endpoint, and never blocks

Why: a finding with no code location reaches no verifier (D113), and a block with no verifier stops a release on a claim that zuko cannot check (spec O5).
Rejected: a critical or high live finding that blocks without a verifier (a false positive stops the release).
Source: specs/strix-live.md
Status: active

## D124 · 2026-11-09 · zuko gives Strix no test accounts

Why: Strix has the source in the copy and can find the seed accounts, or register through the app. No secret goes into the instruction file or to the STRIX_LLM provider (spec O6).
Rejected: a test login typed at each run (the login goes to the LLM provider).
Source: specs/strix-live.md
Status: active

## D125 · 2026-11-09 · Both suite jobs are required on main, and the repo admin bypasses them

Why: a test that passes on one OS only must block the merge, not only show red. `/release` pushes its commit straight to `main` (D1), with no PR, so the admin bypasses the rule.
Rejected: not required (a red job can still be merged by mistake), required with no bypass (it blocks the release push, and D1 would have to change).
Source: specs/windows-ci.md
Status: active

## D126 · 2026-11-09 · The suite workflow runs on each PR to main and by hand, not on a push to main

Why: the PR is the last stop before `main`. A run after a squash merge repeats the PR's tree, and a Windows run takes 13 to 18 minutes.
Rejected: a run on each push to `main` too (a second run of the same tree after each merge), the push trigger on one branch that D104 used (that branch is shipped, and a PR now proves each branch).
Supersedes: D104
Source: specs/windows-ci.md
Status: active

## D127 · 2026-11-09 · A Windows check that fails in some runs gets its cause fixed, and the required job never reruns it

Why: a required job that fails at random blocks each merge until a person reruns it. The Chrome 404 check timed out after 25 s in 2 of 4 portable-suite runs, and its cause is not known.
Rejected: a rerun of a failed file in CI (it also hides each new flaky test), a SKIP on Windows (Windows then never proves the 404 path), one rerun as D117 allows (each red run then needs a person).
Supersedes: D117
Source: specs/windows-ci.md
Status: active

## D128 · 2026-11-09 · A new push to a PR cancels its suite run in progress

Why: only the newest commit of a PR can merge, and a Windows run takes 13 to 18 minutes.
Rejected: letting each run finish (runs stack up on a busy PR, and only the last one counts).
Source: specs/windows-ci.md
Status: active

## D129 · 2026-11-09 · A PR does not have to hold the latest main before it merges

Why: with that rule, each merge sends every other open PR to an update and a new run of 13 to 18 minutes. A clash between two PRs still shows on the next PR run.
Rejected: requiring the latest `main` (one more update and full run after each merge).
Source: specs/windows-ci.md
Status: active

## D130 · 2026-11-09 · The required checks on main are a repository ruleset, not classic branch protection

Why: a ruleset names its bypass list, and its API reports `current_user_can_bypass`. That proves the admin bypass of D125 without a push to `main`.
Rejected: classic branch protection with "include administrators" off (the admin bypass is implicit, and nothing lists it).
Source: specs/windows-ci.md
Status: active
