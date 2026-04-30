# Changelog

All notable changes to the forge plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [0.1.0-alpha] - 2026-05-01

### Added

- Initial forge plugin under the mjolnir marketplace
- Ported skills, agents, hooks, scripts, and verifier from did-workflow under the forge brand
- GitHub-native command set (`gh` replaces `glab` in ship, build, learning-capturer, and related skills)
- Two-line statusline (`scripts/statusline.sh`) auto-applied via plugin `settings.json`

### Notes

- v0.1-alpha is a foundation release. Functional upgrades (atomic-commit `/ship`, `/fix`, `/security-review`, multi-choice prompts, broader stack coverage) land in subsequent milestones per `docs/superpowers/specs/2026-05-01-forge-plugin-design.md`.
