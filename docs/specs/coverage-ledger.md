# Coverage ledger

**Version:** v1 · **Status:** Draft · **Type:** Feature · **Project type:** CLI/Library

**Shape doc:** docs/specs/pentest-depth/shape.md
**Depends on:** needs-validation

Each release pentest records the files it checked in a committed coverage ledger. The next release also checks some files that no run has checked yet, so code older than the last tag gets covered over a few releases.

## Problem

The release pentest reads only the commits since the last tag. A file that has not changed since zuko first got a pentest is never read again. zuko has 148 tracked files outside its tests and docs, and nothing records which of them any pentest has read. A release that shipped without a pentest, such as v2.4.2 (D59), left its whole range unchecked, and no later run goes back to it. The report says what this run looked at, but not what no run has ever looked at.

## Slice test

| Check                         | Result                                                                                                                       |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Cuts every layer it needs     | yes — `/release` step 2 picks the old files, the pentester checks them, the report says the coverage, and `release.py cut` writes the ledger |
| One e2e test walks it         | yes — one e2e test cuts two releases of a scratch repo in a row and checks the ledger after each                             |
| Worth shipping alone          | yes — the next zuko release checks some of its old files, and the ledger says how many no run has checked                    |
| Fits (≤5 scenarios, ≤2 areas) | yes — 5 scenarios, 2 areas: the release pentest prompts, and `release.py`                                                    |

**Path:** full — the slice adds a committed file that `release.py cut` writes and reads, and it changes the pentester's input.

## User story

As the person who runs `/release`, I want each pentest to also check a few files that no pentest has read yet, so that after a few releases every file has been checked at least once, and I can see how far that has got.

## Flow

```mermaid
flowchart LR
  L[("docs/security/coverage.md")] -- "files no run has checked" --> R["/release step 2"]
  G["git diff RANGE"] -- "files the range changed" --> R
  R -- "range files + up to 10 old files" --> P["zuko:pentester"]
  P -- "SCOPE: each file it checked" --> R
  R -- "report: Coverage line" --> REP["docs/security/vX.Y.Z/report.md"]
  REP -- "--pentest" --> C["release.py cut"]
  C -- "marks checked files with the version" --> L
```

`/release` reads the ledger and picks up to 10 files that no run has checked. The pentester checks those files and the files in the range. `cut` marks each checked file in the ledger with the version, and the report says how many files are still unchecked.

## States

```mermaid
stateDiagram-v2
  [*] --> Unchecked: file is tracked
  Unchecked --> Checked: a pentest reads it, no lead
  Unchecked --> Lead: a pentest reads it, a lead stays open
  Checked --> Unchecked: it changes in a release with no pentest
  Lead --> Checked: a later pentest reads it, no lead
  Checked --> [*]: file deleted
  Unchecked --> [*]: file deleted
  Lead --> [*]: file deleted
```

A file starts unchecked. A pentest that reads it marks it checked, or keeps it open when a lead stays on it. A change in a release that ships without a pentest puts it back to unchecked.

## Acceptance criteria

```gherkin
Scenario: the first release with a ledger checks 10 old files and seeds the ledger
  Given zuko is tagged v2.6.0, and docs/security has no coverage ledger
  And the range v2.6.0..HEAD changes 3 files under plugins/zuko
  When the user runs /release, says yes to 2.7.0 and picks code-level
  Then the pentester checks the 3 range files and 10 other files that no run has checked
  And cut prints the line "Coverage   13 of 148 files checked by a pentest · 135 never checked"
  And cut writes the ledger with those 13 files marked "v2.7.0", and the other 135 marked unchecked
  And the terminal says that this release started the ledger

Scenario: the next release goes on from where the last one stopped
  Given the ledger has 135 unchecked files after v2.7.0
  And the range v2.7.0..HEAD changes 2 files that v2.7.0 checked
  When the user releases v2.8.0
  Then the pentester checks the 2 range files and the next 10 unchecked files
  And the ledger marks those 12 files "v2.8.0", and 125 files stay unchecked

Scenario: a release without a pentest puts its changed files back to unchecked
  Given plugins/zuko/scripts/lib/fence.py is marked "v2.7.0" in the ledger
  And v2.8.0 ships with --no-pentest "classifier stopped the run", and its range changes fence.py
  When the user releases v2.9.0 with a pentest, and fence.py does not change in v2.8.0..HEAD
  Then fence.py is unchecked in the ledger after v2.8.0
  And the v2.9.0 pentest picks fence.py as an old file before files it checked before

Scenario: a file with an open lead stays on the list
  Given the v2.7.0 report has lead N1 on plugins/zuko/scripts/lib/git-command.py
  When the user releases v2.8.0, and git-command.py does not change
  Then the ledger marks git-command.py "lead in v2.7.0", not checked
  And the v2.8.0 pentest picks git-command.py as an old file

Scenario: a ledger that cut cannot read stops the release
  Given the coverage ledger has a row for a file with the mark "v2.7.0" twice
  When /release runs release.py cut
  Then cut prints "Coverage ledger unreadable: ..." with the line, and writes nothing
  And a missing ledger is not an error: cut starts a new one, and says so
```

## Scope

**In:**

- A committed coverage ledger at `docs/security/coverage.md`, with one row for each tracked file that counts as a unit (O1, O2).
- `/release` step 2 picks up to 10 unchecked files, and the pentester checks them with the range (O3). It picks files with an open lead first, then files a skipped release put back, then never-checked files in path order (O5).
- The report gets a Coverage line, and the terminal summary says the same.
- `cut` marks each file that the pentester checked, and puts a file from a skipped release back to unchecked.
- A file with an open lead stays on the list.
- `cut` refuses a ledger it cannot read, and starts a new one when there is none.

**Out:**

- Cloudflare's coverage units (surface, boundary, subsystem and attack class) and its validator — not doing. The unit is a file (O1).
- A second pass over a file that a run already checked and that has not changed — not doing. The range catches each change.
- A separate `/audit` command for the whole repo — not doing (shape O3).
- Strix runs adding to the ledger — slice 4 `strix-code`.
- Carrying a lead's text into the next report — not doing. The ledger keeps only the mark on the file.

## Interface

The slice adds one file, one `release.py` command and one report section, and it changes two terminal outputs.

```mermaid
flowchart LR
  K["release.py pick"] -- "1. up to 10 OLD FILES, in O5 order" --> S["/release step 2"]
  L[("2. docs/security/coverage.md")] -- "read" --> K
  S -- "OLD FILES list" --> P["zuko:pentester"]
  P -- "FILES CHECKED in SCOPE" --> S
  S -- "3. ## Files checked" --> R["report.md"]
  R -- "--pentest" --> C["release.py cut"]
  C -- "marks, then rewrites" --> L
  C -- "4. Coverage line" --> T["/release terminal"]
  C -- "5. refusal" --> T
```

`release.py pick` reads the ledger and prints the old files for this release. `/release` hands them to the pentester, and writes each file that it checked into the report. `cut` marks those files in the ledger and prints the Coverage line.

### 1. `release.py pick`

```text
python3 release.py pick <project-dir>
```

It reads `docs/security/coverage.md` and the tracked files, and leaves out each file that the range since the last tag changes, because the range checks those anyway. It prints up to 10 old files in O5 order, one in each line, with the mark that put it on the list. It writes nothing.

```text
Old files  10 of 135 not checked · docs/security/coverage.md
  plugins/zuko/scripts/lib/git-command.py     lead in v2.7.0
  plugins/zuko/scripts/lib/fence.py           reset in v2.8.0
  .agents/skills/design-taste-frontend/SKILL.md  unchecked
  ...
```

With no ledger, the first line reads `Old files  10 of 148 not checked · no ledger yet, cut starts one`. With nothing left to pick, it reads `Old files  0 · every unit is checked`. A ledger it cannot read gives the same refusal as `cut` (section 5) and exit 1.

### 2. The ledger file

`docs/security/coverage.md`, sorted by path, one row for each unit (O2):

```text
# Coverage

**Updated:** v2.7.0 · 2026-11-20
**Units:** 148 · **Checked:** 13 · **Lead:** 1 · **Not checked:** 134

| File | Mark |
| ---- | ---- |
| .agents/skills/design-taste-frontend/SKILL.md | unchecked |
| plugins/zuko/scripts/lib/fence.py | v2.7.0 |
| plugins/zuko/scripts/lib/git-command.py | lead in v2.7.0 |
| plugins/zuko/scripts/lib/release.py | reset in v2.8.0 |
```

| Mark | Means | Counts as |
| --- | --- | --- |
| `vX.Y.Z` | the pentest of that release checked it, with no lead | Checked |
| `lead in vX.Y.Z` | that pentest checked it, and a lead on it is still open | Lead |
| `reset in vX.Y.Z` | it changed in a release that shipped without a pentest | Not checked |
| `unchecked` | no pentest has checked it | Not checked |

`cut` writes the whole file each release. A new tracked file comes in as `unchecked`, and a deleted file goes out.

### 3. The report section and the pentester's input

`/release` gives the pentester an `OLD FILES:` list after `RANGE`. The pentester checks each old file as it checks a range file, with the same categories and class files. Its SCOPE block gets one more line, with every file that it read and hunted, from the range and from the list:

```text
FILES CHECKED: plugins/zuko/agents/pentester.md, plugins/zuko/scripts/lib/fence.py, plugins/zuko/scripts/lib/git-command.py
```

`/release` writes them into the report as a new section after `## Not assessed`, one file in each line:

```text
## Files checked

- plugins/zuko/agents/pentester.md
- plugins/zuko/scripts/lib/fence.py
- plugins/zuko/scripts/lib/git-command.py
```

An old file that the pentester did not reach is not in the list, so it stays on the list for the next release.

### 4. The terminal

The step 2 summary gets one line after `needs validation:`:

```text
           old files: 10 picked, 9 checked
```

`cut` prints the Coverage line after the files it wrote, and the step 7 report repeats it:

```text
Coverage   13 of 148 files checked by a pentest · 135 never checked
Coverage   13 of 148 files checked by a pentest · 135 never checked · ledger started
```

The second form is for the release that creates the ledger.

### 5. The refusals

`cut` and `pick` refuse and write nothing:

```text
Coverage ledger unreadable: line 14: plugins/zuko/scripts/lib/fence.py is listed twice
Coverage ledger unreadable: line 9: the mark "v2.7" is not vX.Y.Z, lead in vX.Y.Z, reset in vX.Y.Z or unchecked
Coverage ledger unreadable: no File and Mark table
Pentest report unreadable: Files checked names plugins/zuko/agents/nobody.md, which is not a unit
```

A report without `## Files checked` is refused as `Pentest report unreadable: no Files checked list`. A skipped pentest (`--no-pentest`) has no report to read: `cut` marks each unit that the range changed as `reset in vX.Y.Z`, and leaves the rest as they are.

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | What is one unit in the coverage ledger: a file, a function, or Cloudflare's own recon units? (from shape O15) | question | shape | user | Resolved | A tracked file. `git ls-files` gives the list, a path is stable, and git says when it changed. The D-entry is drafted at pause 3, 2026-11-09 |
| O2 | Which tracked files count as units? zuko has 462 tracked files: 76 in the plugin outside tests, 196 under scripts with the tests, and 64 in the vendored `.agents/skills/`. | question | spec p1 | user | Resolved | Every tracked file except test folders and fixtures (`/tests/`), `docs/`, and `*.md` at the repo root. Prompt files under `plugins/` count, and vendored `.agents/skills/` counts. zuko has 148 units. The D-entry is drafted at pause 3, 2026-11-09 |
| O3 | How many unchecked files does one release add to its pentest? | question | spec p1 | user | Resolved | 10 files each release, so zuko's 148 units take about 15 releases. The D-entry is drafted at pause 3, 2026-11-09 |
| O4 | The ledger is committed, so it is public. It names each file that no pentest has checked yet. Where does it live? | question | spec p1 | user | Resolved | `docs/security/coverage.md`, committed in the release commit. It names files, not holes. The D-entry is drafted at pause 3, 2026-11-09 |
| O5 | In what order does a release pick the unchecked files? | question | spec p1 | user | Resolved | Files with an open lead first, then files that a skipped release put back to unchecked, then never-checked files in path order. The D-entry is drafted at pause 3, 2026-11-09 |
| O6 | What does cut do with a ledger it cannot read? | question | spec p1 | user | Resolved | Refuse and write nothing, as cut does on a bad report. A missing ledger is not an error: cut starts a new one and says so. The D-entry is drafted at pause 3, 2026-11-09 |

_Never delete this section or its rows. See references/ledger.md._

## Glossary

- **Pentest** — a penetration test: an attack on your own code to find holes before someone else does.
- **Coverage ledger** — a record of each unit of code and whether a run has checked it.
- **Unit** — one piece of code that the ledger tracks, such as one file.
- **Range** — the commits since the last release tag, such as `v2.6.0..HEAD`.
- **Lead** — a possible hole that the pentester traced in the code but could not prove with a run.
- **e2e** — end-to-end: one test that walks the whole slice as a user would.
