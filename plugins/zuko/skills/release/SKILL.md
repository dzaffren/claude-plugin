---
name: release
description: >
  Turns everything shipped since the last release into a version: proposes the
  number from the commits, pentests the release range, cuts the changelog,
  bumps the manifests, then commits, tags, pushes and creates the GitHub
  release. Use when the user says
  "release it", "cut a version", "tag a release", or runs /release.
disable-model-invocation: true
allowed-tools: Bash(git status *) Bash(git log *) Bash(git diff *) Bash(git show *) Bash(git ls-files *) Bash(git archive *) Bash(tar *) Bash(git rev-parse *) Bash(git add *) Bash(git commit *) Bash(git tag *) Bash(git push *) Bash(gh release *) Bash(python3 *) Bash(date *) Bash(mktemp *) Bash(curl *) Bash(kill *) Bash(bash *)
---

# Release

Turn the lines `/ship` left under `[Unreleased]` into a numbered, tagged
GitHub release. `release.py` makes every decision. This stage asks the user,
then does the outward steps through git and gh.

Read `${CLAUDE_PLUGIN_ROOT}/references/voice.md` and
`${CLAUDE_PLUGIN_ROOT}/references/git-naming.md`.

## Steps

### 1. Plan

From the repo root (`git rev-parse --show-toplevel`):

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" plan <repo-root> [--version X.Y.Z]
```

Pass `--version` when the user named one (`/release 3.0.0`). `plan` runs the
test suite, so give the Bash call `timeout: 600000`. Print its output as it
is. Its last line is `NEXT:`. Branch on that line and nothing else — `plan`
exits 1 on `NEXT: stop`, and that is its answer, not a crash:

| Line                          | Skill does                                                      | Then                      |
| ----------------------------- | --------------------------------------------------------------- | ------------------------- |
| `NEXT: stop`                  | a gate failed; report and end                                   | end, nothing written      |
| `NEXT: ask 2.2.0`             | ask "Release 2.2.0?"                                            | yes → step 2 with 2.2.0   |
| `NEXT: confirm 1.4.3`         | an override whose size is off; the advice is above it; ask once | yes → step 2 with 1.4.3   |
| `NEXT: ask-first`             | no tag, no manifest version; ask 0.1.0 or 1.0.0                 | the answer → `plan` again |
| `NEXT: ask-version`           | nothing calls for a release; ask for a version or stop          | the answer → `plan` again |
| `NEXT: resume v2.2.0 push`    | tag at HEAD, not on origin; push it, then create the release    | step 4's push, then 5     |
| `NEXT: resume v2.2.0 release` | tag at HEAD and on origin, no GitHub release; create it         | step 5                    |

The question is the one `plan` printed; ask it and wait. Propose nothing of
your own on `ask-first`. When the user gives a version instead of yes, run
`plan` again with `--version <it>` and branch on the new `NEXT:` line. No,
or stop → end; nothing is written.

One yes covers steps 2 to 7. Do not ask again. A resumed release skips step 2:
its report is already in the release commit.

### 2. Pentest

Attack the release range before anything is written. The pentester runs the
project's own code; a hook fences its Bash to read-only git and its scratch
copy (D14). The fence stops direct commands, not code: a tracked program the
pentester runs, or the project's code itself, can still reach the network or
write anywhere. Run `/release` inside Claude Code's sandbox for untrusted code.
The range is the last
tag, from `plan`'s `Last version` line, to `HEAD`: `v1.4.2..HEAD`. With no tag
yet, it is the whole tracked tree.

**Pick the target, with the version yes.** The project's `OVERVIEW.md` "Run it"
table names a server in its `run` row -> offer it. No run row -> there is
nothing to ask and the pentest is code-level.

```
Pentest target: localhost (starts "<the run command>"), a staging URL, or code-level?
```

- **code-level** (the default, and the only option with no run row): just the
  range checks below, nothing started. The report reads `**Mode:** code-level`.
- **localhost**: start the `run` row in the background and keep its output. Poll
  the port once a second for up to 60 s with `curl -sf http://127.0.0.1:5000/health`
  (or the app's root). If it does not answer in 60 s, stop with the last 20 lines
  of the app's output and this message, then go to the reason question below
  (nothing is written without a reason):

  ```
  Pentest cannot run: invoice-api did not answer on 127.0.0.1:5000 in 60 s
  ```

  When it answers, write the host and port to `.git/zuko-pentest-target`, e.g.
  `127.0.0.1:5000`.
- **a staging URL**: write that host to `.git/zuko-pentest-target`. Start nothing.

The `block-pentest-target.sh` guard reads that file and blocks every request to
any host but the one it names, so a live request can only reach the target.

**Run the live checks (localhost or staging).** The pentester is fenced and
never curls (D14, D27). It names the A01 and A07 requests to try; the release
step, not the pentester, sends each one with `curl` to the target host and hands
the response back for the pentester to judge. The pentester reads, and changes
only objects the run created (D29).

**Tear down on every path** -- passed, blocked, or the app never started: stop
the app with `kill` on its pid, and remove the target file
`.git/zuko-pentest-target`, before step 3.

In live mode the report reads `**Mode:** live · <target>`, and A01 and A07
move from `NOT ASSESSED:` to `ASSESSED:`.

**Check the attack-class pin.** Run
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-attack-pin.sh"`. When it prints a
line, print that line to the user. The check never stops the release (D93).

**Pick the old files.** Run
`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" pick <repo-root>`.
Print its lines to the user as they are. Each indented line names one old
file, then the mark that put it on the list. When `pick` exits 1, print its
refusal, such as `Coverage ledger unreadable: ...`. Then end before the
pentest: nothing is written.

**Start Strix.** Strix is a second attacker that runs with the user's own LLM
key (D112). The pentest target decides whether Strix also attacks the
running app:

- **a staging URL**: run this first, and branch on its one line:

  ```
  python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" strix-ready <repo-root>
  ```

  | Line                                 | Skill does                                                                                  |
  | ------------------------------------ | ------------------------------------------------------------------------------------------- |
  | `STRIX: ready · <version>`           | ask the confirmation below                                                                  |
  | `STRIX: missing · strix-agent 1.7.0` | ask the install question below; after `Strix 1.7.0 installed`, run `strix-ready` again      |
  | `STRIX: skipped · <why>`             | print `Strix skipped: <why>`, ask nothing, and start no Strix run                           |

  Ask the confirmation once, with the host of the URL and the output of
  `git rev-parse --short HEAD`:

  ```
  Strix will attack staging.invoice-api.example.net with real requests. zuko cannot hold it to this host or to reads only, and it may change or delete data there. Staging should run a1b2c3d, the release HEAD. Do you own this host and accept data loss on it? yes / code-level
  ```

  Only the reply `yes` sends Strix live: add `--live <the URL>` to the
  `strix` command below. Strix sends its requests from its Docker sandbox,
  and no zuko hook sees them, so D28 and D29 do not cover them (D120). On
  `code-level`, start Strix without `--live`. On any other reply, print
  `Strix live skipped: the reply was not yes; Strix attacks the code only`,
  and start Strix without `--live`.
- **localhost**: ask nothing. Print
  `Strix live skipped: the Strix sandbox cannot reach 127.0.0.1:5000; Strix attacks the code only`,
  with the target's host and port, and start Strix without `--live` (D121).
- **code-level**: start Strix without `--live`.

Make an empty folder with `mktemp -d`. Join the files that the
range changes (`git diff --name-only <last tag>..HEAD`, or every tracked file
with no tag) and the paths that `pick` printed, with `,`. Run this with
`run_in_background`, and go on to the dispatch at once:

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" strix <repo-root> --scratch <the folder> --files <the files>
```

For a live run, add `--live <the URL>` at the end. One run attacks the copy
and the URL, within the same $10 (D122). `release.py strix` exits 2 when it
refuses the URL: print its message, and start Strix again without `--live`.

Print `Strix running: standard · up to $10 · in the background, next to the pentester`,
or `Strix running: standard · live <host> · up to $10 · in the background, next to the pentester`
for a live run.
When it ends, branch on its last line, which starts `STRIX:`, and nothing else:

| Last line                    | Skill does                                                                                   |
| ---------------------------- | -------------------------------------------------------------------------------------------- |
| `STRIX: missing · strix-agent 1.7.0` | ask the install question below                                                        |
| `STRIX: skipped · <why>`     | print `Strix skipped: <why>`                                                                 |
| `STRIX: failed · <why>`      | print `Strix did not finish: <why>`; the `FINDING` blocks above it still go to verifiers     |
| `STRIX: done · …`            | the `FINDING` blocks go to verifiers                                                         |
| `STRIX: stopped · …`         | the `FINDING` blocks go to verifiers; the run stopped before it finished                      |

Ask the install question once, with the version from the `STRIX: missing` line:

```
Strix is not installed. Install strix-agent 1.7.0 with uv tool install? yes / skip
```

On yes, run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" strix-install <repo-root>`.
It prints `Strix 1.7.0 installed` -> start the `strix` command again, in a new
empty folder. It prints `Strix install failed: ...` -> print that line, and
Strix is skipped as not installed. On skip, print `Strix skipped: not installed`.

A skip or a failure never stops the release (D112): the pentest goes on
without Strix.

1. Dispatch the `zuko:pentester` agent with `RANGE`, `OLD FILES`, `VERSION`,
   the repo, and the target when the release runs live. `OLD FILES` is the
   paths that `pick` printed, joined with `, `, or `none` when it printed no
   path. It returns a scope block with a `FILES CHECKED:` line, findings, each
   with a `PROOF` it ran, and LEAD blocks, each with a `TRACE`, an `UNKNOWN`
   and a `CHECK`.
2. Send each finding to a `finding-verifier` agent, blind, exactly as
   `/review` does: the claim, `CATEGORY`, `SEVERITY`, `FILE`, `SYMBOL`,
   `SNIPPET` and `PROOF`, with `BASE: <the last tag>`, or
   `BASE: none (first release: every tracked line is in the range)`. For a
   finding or a lead in a file from `OLD FILES`, send
   `BASE: none (old file: every line of this file is in scope)`, because the
   range does not change that file. Never the scope block. A verifier that hits its turn limit is not confirmed, and is
   never resumed with added context. A confirmed finding keeps the lowest
   `SEVERITY` a verifier returned, never above the pentester's.

   Send each lead to its own verifier in the same way, with `KIND: lead` first
   and no `SEVERITY`: `KIND: lead`, the `LEAD` claim, `CATEGORY`, `FILE`,
   `SYMBOL`, `SNIPPET`, `TRACE`, `UNKNOWN` and the same `BASE`. Never send
   `CHECK`. A lead holds when its verifier returns `VERDICT: CONFIRMED`. Drop
   each other lead.

   Send the Strix claims when the Strix run and the pentester have both
   returned. Send each Strix `FINDING` block to its own verifier in the same
   way, blind (D113). The claim is the `TITLE`. `CATEGORY` is the OWASP 2025
   category from `owasp.md` that fits the `CWE` and the title, then the CWE in
   brackets: `A05:2025 Injection (CWE-78)`. `SEVERITY`, `FILE` and `SNIPPET`
   come from the block. `SYMBOL` is the function around `FILE`'s line, which
   you read in the repo. `PROOF` is the Proof of Concept section of the `POC`
   file. `BASE` is the same as for a pentester finding in that file. A Strix
   finding holds when its verifier returns `VERDICT: CONFIRMED`. A rejected
   one goes under Needs validation, and so does a block with `FILE: none`,
   which goes to no verifier. Print each `OUTSIDE:` line to the user as it is.
   It goes to no verifier and not into the report.
3. Write the report to a file in the session's scratchpad directory (`mktemp`
   when there is none), in this format, from the confirmed findings and the
   confirmed leads only:

   ```text
   # Pentest v1.5.0

   **Result:** pass
   **Mode:** code-level
   **Range:** v1.4.2..a1b2c3d (9 commits)
   **Date:** 2026-10-02

   ## Findings

   | ID | Severity | Category | Where | Description |
   | -- | -------- | -------- | ----- | ----------- |
   | P1 | medium | A05:2025 Injection | exporters/ledger.py:31 export_ledger | order reaches ORDER BY unchecked |
   | S1 | medium | A05:2025 Injection (CWE-78) | exporters/suppliers.py:29 export_suppliers | Supplier export passes the supplier name to a shell |

   ## Needs validation

   | ID | Category | Where | Description | Unknown |
   | -- | -------- | ----- | ----------- | ------- |
   | N1 | A05:2025 Injection | exporters/suppliers.py:29 export_suppliers | on Windows, a supplier name may reach a cmd.exe shell string unquoted | whether cmd.exe on Windows runs the text after & in a supplier name as its own command |
   | N2 | A09:2025 Security Logging and Alerting Failures (CWE-532) | importers/bank.py:58 import_rows | Strix: Bank import logs the full account number | whether Strix's proof reaches this line: zuko's verifier could not trace it in the code |

   ## Assessed

   - A05:2025 Injection — 4 subprocess calls, 2 SQL strings
   - ATTACK-CLASSES (Cloudflare c1c8a8c) — Injection, Obvious things: exporters/ledger.py
   - AI-AND-LLM (Cloudflare c1c8a8c) — tool-argument injection, indirect injection: exporters/assistant.py
   - STRIX 1.7.0 (standard, anthropic/claude-sonnet-5-5) — 3 found, 1 confirmed, 1 needs validation, 1 info dropped · $3.80 of $10

   ## Not assessed

   - A01:2025 Broken Access Control — needs a running server (slice 5b)
   - CLIENT-SIDE (Cloudflare c1c8a8c) — no browser code in the range
   - MEMORY-SAFETY-AND-BINARY (Cloudflare c1c8a8c) — no native code in the range

   ## Files checked

   - invoice_cli/cli.py
   - invoice_cli/exporters/assistant.py
   - invoice_cli/exporters/ledger.py
   ```

   Copy each `ASSESSED:` and `NOT ASSESSED:` line from the scope block into
   its list. Put the OWASP lines first, then the class-file lines (D94).

   Copy each file in the `FILES CHECKED:` line into `## Files checked`, one in
   each line. Write each path from the repo root, as the pentester gave it.
   `cut` marks these files in the coverage ledger, and refuses a report
   without the section.

   A `LEAK:` line from the pentester (its proof changed something outside the
   scratch copy) goes into the table as its own row, `| L1 | critical | leak |
<the path> | a pentest proof changed it outside the scratch copy |`, so
   `cut` refuses the release. A leak is never re-judged; it is observed.

   `**Result:**` is `blocked` when any row is critical or high, and `pass`
   otherwise. `Where` is `FILE` then `SYMBOL`, and `Description` is
   the claim. The report never carries a `PROOF`: it is committed and public.
   Print each confirmed finding's `PROOF` to the terminal after the table, for
   the user to act on.

   The `## Needs validation` section is always there. Its table lists the
   confirmed leads, numbered `N1`, `N2` and on. With no confirmed lead, the
   table has its header and no rows. `Where` is `FILE` then `SYMBOL`,
   `Description` is the `LEAD` sentence, and `Unknown` is the `UNKNOWN` line.
   Write each `|` in a `Description` or `Unknown` cell as `/`, because `cut`
   reads each `|` as a cell break and refuses the row.
   A lead has no severity and never changes `**Result:**`. The table never
   carries a `TRACE` or a `CHECK`.

   Each confirmed Strix finding is its own row in `## Findings`, numbered
   `S1`, `S2` and on, with the `SEVERITY` that the verifier returned, as for a
   pentester finding. `Where` is `FILE` then `SYMBOL`, and `Description` is the
   `TITLE`. Each other Strix block is a row in `## Needs validation`, with the
   next free `N` ID, because `cut` refuses any other ID there. Its
   `Description` is `Strix: ` then the `TITLE`. Its `Unknown` is `whether
   Strix's proof reaches this line: zuko's verifier could not trace it in the
   code`. A block with `FILE: none` has `—` as its `Where`. In a live run, a
   block with `FILE: none` and an `ENDPOINT` other than `none` has the
   `ENDPOINT` as its `Where`, such as `GET /admin/export`. Its `Unknown` is
   `whether Strix's request reaches code in this release: Strix gave no code
   location`. It goes to no verifier and never blocks (D123).

   One line in the report says what Strix did:

   - `done` -> under `## Assessed`: `- STRIX <version> (standard, <model>) — <found> found, <confirmed> confirmed, <n> needs validation · $<cost> of $10`,
     from the `STRIX:` line. Add `, <n> info dropped` and `, <n> outside` after
     the needs validation count when the `STRIX:` line has them. Add
     ` · incomplete` at the end when it ends with `incomplete`. In a live run,
     the brackets read `(standard, live · <the URL>, <model>)`.
   - `stopped` -> the same line, with `stopped before it finished · ` in front of the counts.
     Strix gives no reason: a budget stop and a provider rate limit look the
     same. So the line names no cause, and its cost shows how far the run got.
   - `failed` -> under `## Not assessed`: `- STRIX — did not finish: <why>`, such as `- STRIX — did not finish: exit 1`.
   - skipped or missing -> under `## Not assessed`: `- STRIX — skipped: <why>`, such as `- STRIX — skipped: no LLM_API_KEY` or `- STRIX — skipped: not installed`.

   A staging target with a ready Strix and no `yes` adds a line under
   `## Not assessed`: `- STRIX live — code-level chosen for <host>`. A
   localhost target adds `- STRIX live — skipped: localhost target`. A Strix
   that is skipped or missing adds no `STRIX live` line.

   The report never carries a Strix PoC. After the pentester's `PROOF`s,
   print the `POC` path of each confirmed Strix finding, as `S1  <the path>`.
   In a live run, also print the `POC` path of each Strix row under Needs
   validation, as `N2  <the path>`.

   After the `PROOF`s, print each confirmed lead to the terminal:

   ```
   N1  exporters/suppliers.py:29 export_suppliers
       trace    supplier "x&echo marker&" in invoices.csv → cli.py main → export_suppliers → subprocess.run("start " + target, shell=True)
       unknown  whether cmd.exe on Windows runs the text after & in a supplier name as its own command
       check    on Windows, run `python -m invoice_cli.cli export invoices.csv` with the supplier x&echo marker&, and expect marker in the output
   ```

4. Print the summary, then go to step 3 with `--pentest <report-file>`:

   ```
   Pentest    code-level · v1.4.2..a1b2c3d (9 commits) · 7 categories · 2 class files
              A05 Injection        1 medium
              needs validation: 1 lead (2 dropped by the verifier)
              old files: 10 picked, 9 checked
              strix: 1.7.0 standard · $3.80 of $10 · 3 found · 1 confirmed · 1 needs validation · 1 info dropped · 9 outside
              not assessed: A01, A07 — no running server (slice 5b)
              class files not read: 8 — no matching code in the range
   ```

   The class-file count is the number of class-file lines under `ASSESSED:`.
   The lead count is the number of rows under `## Needs validation`. The
   dropped count is the number of leads that the verifiers rejected. With no
   rejected lead, leave out the part in brackets. The picked count is the
   number of paths that `pick` printed. The checked count is the number of
   those paths in `FILES CHECKED:`. The `strix:` line takes its version, cost
   and counts from the `STRIX:` line, and the confirmed and needs validation
   counts from the Strix rows. On a skip or a failure it reads
   `strix: skipped · no LLM_API_KEY` or `strix: did not finish · exit 1`.
   In a live run, `live <host>` follows `standard`, as in
   `strix: 1.7.0 standard · live staging.invoice-api.example.net · $6.20 of $10 · 2 found · 1 confirmed · 1 needs validation`.

The pentester returns nothing, stops early, or fails → the pentest did not
finish. Say so, and ask:

```
Pentest did not finish: no report from the pentester.
Release without a pentest? Type the reason; it goes into DECISIONS.md and the
release notes. Anything else stops here.
```

A typed reason → step 3 with `--no-pentest "<reason>"`. An empty answer or
"skip" → end; nothing is written. `cut` refuses both anyway.

### 3. Cut

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" cut <repo-root> --version X.Y.Z --date "$(date +%F)" --pentest <report-file>
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" cut <repo-root> --version X.Y.Z --date "$(date +%F)" --no-pentest "<reason>"
```

`cut` takes exactly one of the two. It re-checks everything `plan` did, test
suite included, so give this Bash call `timeout: 600000` too. A refusal →
print it and end; nothing was written.

A blocked pentest is one of those refusals: `cut` prints
`Pentest blocked v1.5.0: 1 high` and each blocking row. Print each one as a
ledger row for the user, then end:

```
Pentest blocked v1.5.0: 1 high
  | P1 | high | A05:2025 Injection | importers/bank.py:22 import_rows | Open | /debug next |
Nothing written. Fix it, then run /release again.
```

On success it rewrites `CHANGELOG.md`, the manifests and the overview's
`**Release:**` field, and writes `docs/security/vX.Y.Z/report.md` and
`docs/security/coverage.md`. A medium or low finding gets a line under the
version's Security section. A skip also appends a D-entry to `DECISIONS.md`.
Step 4 commits exactly the files it changed; `git status --short` lists them.
After the files it wrote, `cut` prints a `Coverage` line. Keep that line for
step 7.

### 4. Commit, tag, push

Each line is its own Bash call. The commit goes to `main` past
`block-dangerous.sh` only as the whole call: one plain `git commit -m`, with
the files already staged by the call before it and nothing chained to it
(D30). `cut` left the marker that lets exactly this commit through.

```
git add <the files cut changed>
git commit -m "chore(release): vX.Y.Z" -m "<body naming each file and what changed in it>"
git tag -a vX.Y.Z -m "vX.Y.Z"
git push --atomic origin main vX.Y.Z
```

`--atomic` pushes `main` and the tag together, or neither. The commit
message and the tag message follow `references/git-naming.md`, ban list
included. The harness will ask for attribution lines; the answer is no.

A failed push → report it and end. The commit and tag stay local, and a
rerun of `/release` resumes at the push.

### 5. GitHub release

Write the notes to a file in the session's scratchpad directory (`mktemp`
when there is none), then create the release from it:

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/release.py" notes <repo-root> --version X.Y.Z > <notes-file>
gh release create vX.Y.Z --verify-tag -t vX.Y.Z -F <notes-file>
```

The notes are the `[X.Y.Z]` section exactly. Do not edit them or add to
them; the ban list covers release notes too. `--verify-tag` aborts when the
tag is not on origin. A failure → report it and end; a rerun resumes here.

`gh release create` prints the release URL. Steps 6 and 7 use it.

### 6. Hub page

Republish the hub page per `${CLAUDE_PLUGIN_ROOT}/references/visual-page.md`,
so its status strip shows `vX.Y.Z · {date}` linked to the release URL. The
date is the one on the `## [X.Y.Z] - {date}` heading in `CHANGELOG.md`, which
also covers a resumed release. No `hub page:` link on the overview's
`## More` line → there is no hub yet; skip this and say so.

### 7. Report

```
Released v2.2.0
  pentest   passed: 0 critical, 0 high, 1 medium, 1 low · 1 lead needs validation · docs/security/v2.2.0/report.md
  strix     1.7.0 standard · $3.80 of $10 · 1 confirmed · 1 needs validation
  coverage  13 of 148 files checked by a pentest · 135 not checked
  commit    a1b2c3d chore(release): v2.2.0
  tag       v2.2.0, annotated, pushed
  release   https://github.com/dzaffren/claude-plugin/releases/tag/v2.2.0
  overview  Release: v2.2.0 · hub page republished
```

The lead count reads `1 lead needs validation` or `3 leads need validation`.
With no lead, leave that part out.

The `strix` line has the same counts as the `strix:` line of step 2, and
names the host after `standard` in a live run. On a skip
or a failure it reads `strix     skipped · <why>` or `strix     did not finish · <why>`.

The `coverage` line is the text after `Coverage` in the line that `cut`
printed, as it is. It includes `· ledger started` for the release that
starts the ledger.

## Tags are permanent

Never delete, move or force-push a tag, and never `git push --force`. A tag
in the wrong place is a `NEXT: stop` from `plan`; the user sorts it out by
hand.
