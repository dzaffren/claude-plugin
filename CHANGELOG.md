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
