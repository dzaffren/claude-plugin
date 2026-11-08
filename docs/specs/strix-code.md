# Strix code

**Version:** v1 · **Status:** Draft · **Type:** Feature · **Project type:** CLI/Library

**Shape doc:** docs/specs/pentest-depth/shape.md
**Depends on:** attack-classes, needs-validation

When Strix, an LLM key and Docker are present, `/release` also runs Strix on the scratch copy of the release. zuko's blind verifier checks each Strix finding, and the confirmed ones go into the same report and block the release by the same rule (D10).

## Problem

The release pentest has one attacker: the zuko pentester, which runs on Claude Code. A user with an LLM key cannot add a second attacker. Strix is an open-source pentest tool that runs its agents in Docker and calls an LLM with the user's own key. On this machine, `strix` 1.4.1 and Docker 29.9.2 are installed, and `~/.strix/cli-config.json` sets `STRIX_LLM` and `LLM_API_KEY`. No zuko stage runs Strix, so those credits find nothing.

## Slice test

| Check                         | Result                                                                                                                                  |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Cuts every layer it needs     | yes — `/release` step 2 checks for Strix and runs it, the verifier judges its findings, the report holds them, and `release.py cut` enforces them |
| One e2e test walks it         | yes — one e2e test cuts a release of a scratch repo with a stub `strix` that writes two findings, and checks the report and the block |
| Worth shipping alone          | yes — the next zuko release gets a second attacker that the user already pays for                                                       |
| Fits (≤5 scenarios, ≤2 areas) | yes — 5 scenarios, 2 areas: the `/release` skill, and `release.py`                                                                      |

**Path:** full — the slice adds an outside tool, a new input to the report, and a new reason for `cut` to refuse.

## User story

As the person who runs `/release` with an LLM key, I want Strix to attack the release next to the zuko pentester, so that a hole that one attacker misses can still block the release.

## Flow

```mermaid
flowchart LR
  R["/release step 2"] -- "strix on PATH? key? docker info?" --> C{Strix ready}
  C -- "no: one Strix skipped line" --> P["zuko:pentester"]
  C -- "yes: scratch copy" --> S["strix -n -t scratch"]
  S -- "vulnerabilities.json" --> V["finding-verifier, blind"]
  P -- "findings and leads" --> V
  V -- "confirmed" --> REP["report.md: Findings"]
  V -- "rejected Strix finding" --> NV["report.md: Needs validation"]
  REP -- "--pentest" --> CUT["release.py cut"]
  CUT -- "a critical or high: refuse" --> T["/release terminal"]
```

`/release` checks for Strix, its key and Docker. When all three are present, Strix attacks the scratch copy next to the zuko pentester. The blind verifier judges each finding from both, and `cut` blocks on a confirmed critical or high from either.

## States

```mermaid
stateDiagram-v2
  [*] --> Missing: no strix on PATH
  [*] --> NotReady: strix, but no key or no Docker
  [*] --> Ready: strix, key and Docker
  Missing --> Ready: user says yes to the install
  Missing --> Skipped: user says skip
  NotReady --> Skipped: one Strix skipped line
  Ready --> Finished: exit 0 or 2
  Ready --> Failed: exit 1, or no run.json
  Ready --> Stopped: budget reached, status stopped
  Finished --> [*]
  Stopped --> [*]
  Failed --> [*]
  Skipped --> [*]
```

A Strix run starts missing, not ready or ready. A ready run finishes, stops at its budget, or fails. Each end goes into the report.

## Acceptance criteria

```gherkin
Scenario: a confirmed Strix finding goes into the report
  Given zuko is tagged v2.6.0, and v2.6.0..HEAD has 4 commits
  And strix 1.7.0 is on PATH, ~/.strix/cli-config.json sets STRIX_LLM and LLM_API_KEY, and docker info answers
  When the user runs /release, says yes to 2.6.1 and picks code-level
  Then /release runs Strix on the scratch copy of v2.6.1 with --scan-mode standard and --max-budget 10
  And Strix reports 2 vulnerabilities, and the verifier confirms 1 medium in plugins/zuko/scripts/lib/release.py and rejects the other
  And the report lists the medium under Findings as S1, and the rejected one under Needs validation
  And the summary prints "Strix      standard · $3.80 of $10 · 2 found · 1 confirmed · 1 needs validation"

Scenario: a confirmed high from Strix blocks the release
  Given the verifier confirms a high from Strix in plugins/zuko/scripts/lib/git-command.py
  And the zuko pentester confirms nothing
  When /release runs release.py cut with that report
  Then cut prints "Pentest blocked v2.6.1: 1 high" and the S1 row
  And cut writes nothing

Scenario: no key or no Docker skips Strix with one line
  Given strix is on PATH, and neither the environment nor ~/.strix/cli-config.json sets LLM_API_KEY
  When the user runs /release and says yes to 2.6.1
  Then /release prints "Strix skipped: no LLM_API_KEY in the environment or ~/.strix/cli-config.json"
  And the zuko pentest runs as it does today
  And the report lists "STRIX — skipped: no LLM_API_KEY" under Not assessed

Scenario: zuko offers to install a missing Strix
  Given strix is not on PATH
  When the user runs /release and says yes to 2.6.1
  Then /release asks "Strix is not installed. Install strix-agent 1.7.0 with uv tool install? yes / skip"
  And on yes it installs strix-agent 1.7.0, prints the installed version, and goes on to the key and Docker checks
  And on skip it prints "Strix skipped: not installed" and the zuko pentest runs as it does today

Scenario: a Strix run that fails or stops early is said, not hidden
  Given Strix exits 1 with "Docker daemon not reachable" on its last line
  When /release reads the Strix run
  Then /release prints "Strix did not finish: exit 1 · Docker daemon not reachable"
  And the release goes on with the zuko pentest only, and the report lists "STRIX — did not finish: exit 1" under Not assessed
  And a run that stopped at its budget still sends each finding it wrote to the verifier, and the report says "stopped at the $10 budget"
```

## Scope

**In:**

- `/release` step 2 checks for `strix`, `STRIX_LLM` and `LLM_API_KEY` in the environment or in `~/.strix/cli-config.json`, and `docker info`.
- With all present, Strix runs on the scratch copy of the release, with a fixed scan mode and a budget cap.
- With no `strix`, zuko asks once for each release, and installs a pinned version on yes, as D80 does for Node.
- The blind verifier judges each Strix finding, as it does for the pentester's findings.
- Confirmed Strix findings go into the Findings table, and block the release by D10. Rejected ones go under Needs validation (O4). Info findings are dropped (O7).
- The report says whether Strix ran, was skipped, stopped at its budget, or did not finish, and the run's cost.

**Out:**

- Strix against a running app on a host the user names — slice 5 `strix-live`.
- Strix in place of the zuko pentester — not doing (shape, Not doing).
- Strix through a proxy to a Claude subscription — not doing (shape, Not doing).
- The managed `strix cloud` platform — not doing. It uploads the code to a third party, and the shape chose an API key only.
- Strix runs marking files in the coverage ledger — not doing (O6). Strix does not say which files it read.
- Strix in `/review` — not doing. The shape keeps extra attackers to the release (shape O7).

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | Strix lists Claude Opus 5.5 as "needs CVP access". Do Claude models work in Strix with an API key, without CVP, on Windows with Docker Desktop? This machine sets `STRIX_LLM` to `anthropic/claude-sonnet-5-5`. (from shape O8) | unproven | shape | poc | Accepted risk | Build now. The first real release with Strix proves it. If Claude fails in Strix, the run shows as "did not finish" (O5), and the zuko pentest still stands, 2026-11-09 |
| O2 | What does one code-level Strix run cost, and does one run for each release fit in $100 a month? The answer also sets the default `--scan-mode`. (from shape O9) | unproven | shape | poc | Resolved | `--scan-mode standard --max-budget 10`. At most 10 runs fit in $100 a month, and a run stops cleanly at the cap. Not measured: the first real run gives the cost, 2026-11-09 |
| O3 | How does zuko install Strix? Its main installer is `curl \| bash`, and it also ships as the `strix-agent` package. The lean is `uv tool install` or `pipx install` of `strix-agent` at a pinned version. (from shape O12) | question | shape | user | Resolved | `uv tool install strix-agent==1.7.0`, pinned. The D-entry is drafted at pause 3, 2026-11-09 |
| O4 | The verifier returns only CONFIRMED or REJECTED. Where does a Strix finding go that the verifier rejects? The needs-validation spec said this slice puts it under Needs validation. | question | spec p1 | user | Resolved | Under Needs validation, with no severity, and it never blocks. Strix ran a proof in its sandbox, so a rejection can mean only that the verifier could not trace it. The D-entry is drafted at pause 3, 2026-11-09 |
| O5 | When Strix fails or stops early, does the release go on with the zuko pentest only, or ask for a reason as it does when the pentester fails? | question | spec p1 | user | Resolved | The release goes on with the zuko pentest only. `/release` prints why Strix did not finish, and the report lists Strix under Not assessed. The D-entry is drafted at pause 3, 2026-11-09 |
| O6 | Does a Strix run mark files in the coverage ledger? Strix does not say which files it read. The coverage-ledger spec handed this question to this slice. | question | spec p1 | user | Resolved | No. Only the zuko pentester's `FILES CHECKED` line marks the ledger, 2026-11-09 |
| O7 | Strix grades findings critical, high, medium, low or info. zuko's grid (D4) has no info. What happens to an info finding? | question | spec p1 | user | Resolved | Dropped. An info finding goes to no verifier and not into the report. The summary counts it, 2026-11-09 |

_Never delete this section or its rows. See references/ledger.md._

## Glossary

- **Strix** — an open-source AI pentest tool (`usestrix/strix`). It runs its agents in Docker and calls an LLM with your own key.
- **Pentest** — a penetration test: an attack on your own code to find holes before someone else does.
- **Blind verifier** — an agent that judges one finding from the claim and the code only, without the reasoning of whoever found it.
- **Scratch copy** — the copy of the release that `git archive` puts in a temporary folder, where the pentester runs its proofs.
- **CVP** — Anthropic's Cyber Verification Program. Strix says that Claude Opus 5.5 needs this access for pentest work.
- **Scan mode** — Strix's `--scan-mode`: `quick` takes minutes, `standard` about 30 minutes, and `deep` hours.
- **uv** — a Python package manager. `uv tool install` puts a Python command on PATH in its own environment.
- **e2e** — end-to-end: one test that walks the whole slice as a user would.
