# Changelog

All notable changes to this project are documented in this file. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.2.0] - 2026-10-05

### Added

- /ship writes plain-language lines to CHANGELOG.md for every feature or fix, and the ship gate refuses a feature or fix branch that adds none.
- Onboarding creates CHANGELOG.md with a heading for each past release tag, or adds an [Unreleased] section to a changelog you already have.
- Commit subjects can mark a breaking change with ! before the colon, as in feat(config)!: read settings from invoice.toml.
- /release turns what you have shipped into a numbered version: it works out the number from the commits, moves the changelog lines under it, bumps the manifest versions, and tags and publishes a GitHub release.
- /review checks security against the OWASP Top 10:2025. Each security finding names its category and severity, and the report says which categories it checked and why it skipped the rest.
- The review's blind checker reads the diff with git itself, and a hook holds it to read-only git commands.
- /release pentests the code shipped since the last release before it cuts the version. A proven critical or high blocks the release, medium and low findings go in the release notes by severity, category and file, and skipping the pentest needs a typed reason.
- A hook holds the pentester's shell to its scratch copy: it cannot push, tag, reach the network with a command, or write outside the copy. For untrusted code, run Claude Code's sandbox as well.
- /review reports what a branch introduces, not only the lines it touches: a deleted check or a changed call is a finding, and removing a guard that a security fix added raises its severity one tier.
- /review treats silent failures as A10 findings, such as a swallowed error, a default returned on error, or retries that give up quietly, and flags auth or validation changed without a test change.
- /release can pentest a running web app, not just the code: it starts the app (or takes a staging URL you name), checks for broken access control and broken authentication with real requests, and a guard blocks any request to a host you did not name.
- The review's blind checker drops a finding for a defence only when it cites the file and line it read, and a confirmed security finding names who can exploit it and what they gain.
- A shape cannot be marked Shaped, or a spec Refined, while its ledger still has an Open question. A shape can hand a question to a later slice instead, and that slice's /spec picks it up as open.
- A hook blocks gh pr create when the PR body or title carries Claude attribution, as it already did for commits, tags and releases.
- /design-system is its own command for building or extending the product's design system; /design now designs screens only, and /design system tells you the new name.
- Diagrams in zuko's terminal replies are drawn in ASCII so they read in the terminal; specs and pages keep Mermaid.
- /shape NOV-125 starts the shape from that Jira ticket when Jira is connected: it reads the summary and description and asks only what the ticket leaves open.
- New specs and shapes end with a Glossary, and a turn that leaves a Draft or Refined spec, or a shape, using a listed term such as semver or SSRF without a glossary entry fails with the doc and the term named.
- /design-system takes a Figma frame link when Figma is connected and builds the brief from that frame's variables and styles, each token traced to its Figma variable.

### Fixed

- The ship gate no longer mistakes a Mermaid decision node, such as a diamond labelled origin host, for an unfilled placeholder, so specs can write diagram labels without quoting them.
- zuko's test helpers no longer misread text longer than 64 KB, so a check on long output passes or fails for the right reason.
- /release on a GitLab repo now says plainly that it supports GitHub only, instead of promising GitLab releases in a later slice.
- A commit made in another worktree is now checked on that worktree's branch, so zuko no longer blocks it as a commit on main, and a commit from a worktree onto main is blocked.
- The secret scan now reads the staged changes of the repo a commit runs in, so a secret staged in another worktree is caught.

### Security

- Known medium issue: A06:2025 Insecure Design in plugins/zuko/scripts/scope-pentester-bash.sh; see docs/security/v2.2.0/report.md.
- Known low issue: A05:2025 Injection in plugins/zuko/scripts/check-design-drift.sh; see docs/security/v2.2.0/report.md.
- Known low issue: A10:2025 Mishandling of Exceptional Conditions in plugins/zuko/scripts/block-dangerous.sh; see docs/security/v2.2.0/report.md.
- Known low issue: A10:2025 Mishandling of Exceptional Conditions in plugins/zuko/scripts/secret-scan.sh; see docs/security/v2.2.0/report.md.

[unreleased]: https://github.com/dzaffren/claude-plugin/compare/v2.2.0...HEAD
[2.2.0]: https://github.com/dzaffren/claude-plugin/releases/tag/v2.2.0
