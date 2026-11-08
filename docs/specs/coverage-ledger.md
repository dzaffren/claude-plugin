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
  And the report's Coverage line reads "13 of 148 files checked by a pentest; 135 never checked"
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
