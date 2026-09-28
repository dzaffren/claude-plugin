# dzafran-claude-plugins

**Status:** Active · **Updated:** 2026-09-28 by /ship ledger-handoff

A personal Claude Code plugin marketplace with one plugin, zuko: a delivery workflow
that takes a rough idea to a shipped vertical slice. Used by its author across personal
projects.

## Run it

| Task    | Command                                                                                             |
| ------- | --------------------------------------------------------------------------------------------------- |
| install | `/plugin marketplace add dzaffren/claude-plugin` then `/plugin install zuko@dzafran-claude-plugins` |
| run     | `/shape` in a Claude Code session                                                                   |
| test    | `bash plugins/zuko/scripts/tests/run.sh`                                                            |
| lint    | not set up yet                                                                                      |

## Where things are

- `.claude-plugin/` — the marketplace manifest
- `plugins/zuko/skills/` — one folder per stage: shape, spec, build, review, ship, release, and the helpers
- `plugins/zuko/agents/` — subagents the stages dispatch (chunk-builder, reviewer, finding-verifier)
- `plugins/zuko/references/` — rules every stage reads (voice, slicing, ledger, onboarding)
- `plugins/zuko/scripts/` — hook and gate scripts; `tests/` holds their bash test harness
- `plugins/zuko/hooks/hooks.json` — wires the scripts to Claude Code hook events
- `docs/specs/` — shape docs and one spec per slice
- `docs/learnings/` — lessons replayed at every session start

## Slices

| Slice              | Status  | What it does                                                               | Page                                              |
| ------------------ | ------- | -------------------------------------------------------------------------- | ------------------------------------------------- |
| hook-command-match | Shipped | Guards match the git command that actually runs, not text inside arguments | —                                                 |
| ship-naming        | Shipped | One naming format for branches, commits and PRs, and no Claude attribution | —                                                 |
| auto-onboard       | Shipped | Writes and loads a living project overview; /ship keeps it current         | https://claude.ai/artifact/6jGkvydEiefbEkuRQiiULA |
| readme-block       | Shipped | A README block rendered from the overview and checked at ship time         | https://claude.ai/artifact/UjgNXmdzaq2Uaq1VkAMmmg |
| decision-log       | Shipped | An append-only DECISIONS.md, loaded every session and enforced by /review  | https://claude.ai/artifact/9hPyHKvyYczFPhbdBpJciM |
| adr-seeding        | Shipped | Seeds DECISIONS.md from a repo's existing ADRs                             | https://claude.ai/artifact/Xh4g34k8RftqLVG11HfZX6 |
| changelog          | Shipped | /ship writes plain-language CHANGELOG.md lines, enforced by the ship gate  | https://claude.ai/artifact/MhNNgxXonCgnAvfYyHQBdt |
| release            | Shipped | /release cuts a version from the commits: changelog, tag, GitHub release | https://claude.ai/artifact/GWzbvfunoJvLFAsWrBkimp |
| owasp-lens         | Shipped | /review judges security against OWASP Top 10:2025, with a category and severity on every finding | https://claude.ai/artifact/WGiEEvRnTmpzLGLUxtBTh2 |
| run-helpers-long-text | Shipped | Test checks on text over 64 KB pass or fail for the right reason | — |
| pentest            | Shipped | /release pentests the code since the last release; a proven critical or high blocks it | https://claude.ai/artifact/8ed6sqgcVTL6GzYmT3xkAS |
| regression-review  | Shipped | /review judges what a diff introduced: a deleted guard or changed caller is a finding, silent failures are A10, untested auth is coverage | https://claude.ai/artifact/2TQDxfubLjL9nQftBH3uDQ |
| release-host-message | Shipped | /release on a GitLab origin says it supports GitHub only, instead of promising a GitLab slice that was dropped | https://claude.ai/artifact/MvZ3Vm4192KiSyEyU5o4Hh |
| ledger-handoff     | Built   | A shape cannot be Shaped, or a spec Refined, with an Open ledger row; a shape hands a later slice's question forward | https://claude.ai/artifact/QzLUTiLTrGLMbzcLefV8P8 |

## More

README.md · docs/ARCHITECTURE.md · DECISIONS.md · CHANGELOG.md · hub page: https://claude.ai/artifact/YcLoFAaz4iRM6LArt5uPQT
