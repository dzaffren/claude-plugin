# dzafran-claude-plugins

**Status:** Active · **Release:** v2.4.3 · **Updated:** 2026-10-27 by /ship unclosed-fence

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
| ledger-handoff     | Shipped | A shape cannot be Shaped, or a spec Refined, with an Open ledger row; a shape hands a later slice's question forward | https://claude.ai/artifact/QzLUTiLTrGLMbzcLefV8P8 |
| pr-attribution | Shipped | The attribution hook blocks a gh pr create whose body or title signs Claude's name | https://claude.ai/artifact/5e7QMLTaHEKMdAijQ1W6JC |
| mermaid-placeholder | Shipped | The ship gate reads a Mermaid decision node as diagram syntax, not an unfilled placeholder | https://claude.ai/artifact/AnCszTToZDaHLDVcsyevpu |
| guard-worktree-dir | Shipped | A commit is judged on the branch and staged diff of the directory it runs in, so worktree commits pass the guards and secrets staged there are scanned | — |
| design-system | Shipped | /design-system builds the product's design system as its own command; /design is for screens and points its old system form at the new name | https://claude.ai/artifact/M3tjreL4wLrQ1qxyWzEPCA |
| ascii-terminal | Shipped | Diagrams in terminal replies are drawn in ASCII; Mermaid stays the source in specs and pages | https://claude.ai/artifact/TNetgs99avn7udEDAXJxhA |
| jira-shape | Shipped | /shape KEY starts the shape from that Jira ticket when Jira is connected, and never writes to Jira | https://claude.ai/artifact/RvxWtxemNhGHe3catVwNKC |
| glossary-gate | Shipped | Spec and shape templates end with a Glossary, and the spec gate fails a live doc that uses a listed jargon term without defining it | https://claude.ai/artifact/LN5TASnzHBzZak1Ge8CvwK |
| figma-brief | Shipped | /design-system takes a Figma frame link when Figma is connected and builds the brief from that frame's variables and styles | https://claude.ai/artifact/J8iPo9thpwVB4Xyzng2JX9 |
| pentest-live | Shipped | /release also attacks a running web app with real requests, checking broken access control and authentication; a guard holds every request to the one host you named | https://claude.ai/artifact/9ncMJwsS8wJtRzdfWxrv4j |
| release-commit-guard | Shipped | /release makes its own commit on main again: the guard lets through exactly the commit cut prepared, and the commit guards block a hook payload they cannot read | https://claude.ai/artifact/R9mozzVbH3JQ65xTvLJU3w |
| design-drift-filename | Shipped | The design drift gate runs under macOS's default bash, and a scanned file's name can no longer make it write a file | — |
| pentester-fence-awk | Shipped | The pentester fence no longer allows awk, sed, sort, uniq or file, which ran a shell or wrote files the fence never saw | — |
| release-commit-brace | Shipped | The release commit's exception on main refuses an unquoted brace or glob, which bash expanded into extra files in the commit | — |
| force-push-expansion | Shipped | The force-push guard blocks every spelling git forces with: a + refspec, a bundled -f, --mirror, and a brace or glob the shell expands | — |
| stop-hook-scope | Shipped | The Stop hooks judge only the zuko docs this work changed, so runbooks, other tools' specs and old breaches no longer fail a turn | — |
| ste-voice | Shipped | zuko writes to the ASD-STE100 writing rules, a published standard you can check it against, and every skill and agent reads them | — |
| pause-questions | Shipped | At each pause, /spec and /shape ask every open question and assumption in the question prompt, recommended answer first; a pause is approved only with no Open row | — |
| unattended-build | Shipped | /build and /review run to the end without asking; each choice they make alone is a Decided alone row in the spec, which does not block | — |
| decision-pr | Shipped | /ship opens the PR with each choice made without you, then the review result, then what ships; the ship gate fails a choice with no undo, or a spec with no review | — |
| tokenise-linear | Shipped | The guards' shared command parser refuses a command over 64 KB, and block-dangerous blocks it, so no guard takes 20 s and no long command times a guard out | — |
| fail-closed-parse | Shipped | The guards' parser reads # comments as bash does, and block-dangerous blocks a command the parser cannot read, so a comment or a broken line no longer hides a force push or a commit on main | — |
| pr-edit-attribution | Shipped | The attribution hook reads gh pr edit and gh pr merge as it reads gh pr create, so a replaced PR body or a merge commit message cannot sign Claude's name | — |
| arith-heredoc | Shipped | The guards' parser refuses a `<<` inside `(( ))`, `$(( ))`, `$[ ]` or `${ }`, where bash reads a shift, so it no longer hides the lines after it | — |
| gh-create-value-options | Shipped | The attribution hook gives each value option of gh pr create and gh release create its value, so a value option before the body or the notes no longer hides a signed text | — |
| pipefail-grep-race | Shipped | The hook and gate scripts give grep -q its text with a here-string, not a pipe, so a slow printf can no longer turn a match into a miss and let a force push, a commit on main or a staged secret pass | — |
| quoted-subst-heredoc | Shipped | The guards' parser refuses a heredoc inside a double-quoted $( ) or backticks when a line of its body changes the parser's quotes, so it no longer hides the lines after it | — |
| shipped-in-pr | Shipped | /ship marks a slice Shipped in the slice's own PR, with the README and the lessons, so no slice needs a second, status-only PR after the merge | — |
| idea-board | Shipped | Each idea gets one claude.ai board with its slices in order, each slice's stage, diagrams and decisions; every stage republishes it | — |
| gate-card | Shipped | At each /spec pause and the end of /shape, the board shows what waits for you, what is settled and what changed since the last stop; the terminal prints only the board link, one picture and the questions | — |
| pr-gate | Shipped | The board shows each built slice's scenarios next to the tests and files its spec names, with the choices made without you; the PR body links the board | — |
| library | Shipped | The hub page lists every idea with its board link, how many of its slices shipped and a mark per slice; /shape now publishes the hub too | — |
| replay | Shipped | The board steps through each commit that changed an idea's shape or specs, with the commits of squash-merged PRs read from GitHub, and shows what moved and what changed at each step | — |
| unclosed-fence | Shipped | The spec gate fails a zuko doc in which a code block swallows the text after it, so a broken spec can no longer reach a commit and mislead the board, the gate card and the PR body | — |

## More

README.md · docs/ARCHITECTURE.md · DECISIONS.md · CHANGELOG.md · hub page: https://claude.ai/artifact/YcLoFAaz4iRM6LArt5uPQT
