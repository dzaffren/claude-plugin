# Changelog

Every shipped slice adds plain-language lines to one `CHANGELOG.md` at the repo
root. One copy of the rules — `/ship` writes the lines from this file, and the
ship gate checks they are there.

## The file

```markdown
# Changelog

All notable changes to this project are documented in this file. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Export the ledger as one CSV file.

### Changed

- BREAKING: Settings move from settings.ini to invoice.toml; rename the file.

### Fixed

- Invoice numbers keep their leading zeros.

## [0.2.0] - 2025-05-19

Released before this changelog was kept.
```

Keep a Changelog 1.1.0: newest first, `## [Unreleased]` on top. Sections go in
this order, each only when it has a line: Added, Changed, Deprecated, Removed,
Fixed, Security. A new line goes below the last line of its section. A section
that is not there yet is added in its place in that order.

`[Unreleased]` becomes a version later, through `/release` (not yet built).
Never cut a version, add a date, or write a compare link here.

## Commit type to section

| Commit                                                     | Section  | Line                                                          |
| ---------------------------------------------------------- | -------- | ------------------------------------------------------------- |
| `feat`                                                     | Added    | what the user can now do, one sentence, ends with a full stop |
| `fix`                                                      | Fixed    | what now works that did not, in the user's words              |
| `fix` for a security finding from `/review` or the pentest | Security | what was exposed and that it no longer is — no exploit detail |
| any `!` or `BREAKING CHANGE:` footer                       | Changed  | starts `BREAKING:` and says what the user must do             |
| `feat` that removes something                              | Removed  | what is gone and what to use instead                          |
| `chore` `docs` `test` `refactor`                           | —        | no line                                                       |

## How many lines

One line per change a user would notice, usually 1 to 3 per slice. Never one
per commit: three commits that build one export are one line. A branch with
only `chore`, `docs`, `test` or `refactor` commits adds none.

## Writing a line

Write for someone who uses the product, not for someone reading the diff. Say
what they can now do, or what now works.

| Commit                                                | Line                                                                            |
| ----------------------------------------------------- | ------------------------------------------------------------------------------- |
| `feat(exporters): write ledger csv`                   | `- Export the ledger as one CSV file.`                                          |
| `fix(parsers): keep leading zeros in invoice numbers` | `- Invoice numbers keep their leading zeros.`                                   |
| `feat(config)!: read settings from invoice.toml`      | `- BREAKING: Settings move from settings.ini to invoice.toml; rename the file.` |

- A line never repeats a commit subject word for word.
- A `BREAKING:` line says what the user must do, not only what changed.
- A security line names what was exposed and that it no longer is. Never the
  exploit: no payload, no steps to reproduce it.
- No PR or issue links. The PR number does not exist until after the gate.
- The ban list in `git-naming.md` applies to lines too: no Claude attribution,
  no session links, no emojis.

## Creating the file

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/changelog.py" init <repo-root>
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/changelog.py" add-unreleased <repo-root>
```

`init` writes the header, an empty `[Unreleased]`, and one heading per semver
tag reading "Released before this changelog was kept." Nothing is invented for
past versions. `add-unreleased` prints the one-line change that adds
`[Unreleased]` to a changelog in another shape; `--write` applies it after the
user approves. Old entries are never reformatted. Onboarding runs these, and
`/ship` does for a repo onboarded before the file existed.

## Enforced

`scripts/verify-ship-gates.sh` runs `scripts/lib/changelog.py check` against
the branch's merge-base. A new line is a bullet under `[Unreleased]` at HEAD
whose text was not a bullet under `[Unreleased]` at the merge-base — moving a
line does not count. The gate fails a branch with `feat`, `fix` or `!` commits,
or a `BREAKING CHANGE:` footer, that adds no new line. It also fails on a
missing file, a missing `## [Unreleased]` heading, or attribution text in an
added line. The prose above writes the lines; the gate does not trust it.
