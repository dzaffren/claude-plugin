# Changelog

All notable changes to this project are documented in this file. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- The review's blind checker drops a finding for a defence only when it cites the file and line it read, and a confirmed security finding names who can exploit it and what they gain.
- A shape cannot be marked Shaped, or a spec Refined, while its ledger still has an Open question. A shape can hand a question to a later slice instead, and that slice's /spec picks it up as open.
- A hook blocks gh pr create when the PR body or title carries Claude attribution, as it already did for commits, tags and releases.

### Fixed

- The ship gate no longer mistakes a Mermaid decision node, such as a diamond labelled origin host, for an unfilled placeholder, so specs can write diagram labels without quoting them.
- zuko's test helpers no longer misread text longer than 64 KB, so a check on long output passes or fails for the right reason.
- /release on a GitLab repo now says plainly that it supports GitHub only, instead of promising GitLab releases in a later slice.
