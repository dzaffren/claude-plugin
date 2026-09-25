# A fixture writes every project file before it renders the README

**Learned:** 2026-09-25 · **From:** changelog build

Chunk B of the `changelog` slice added a `CHANGELOG.md` to each gate fixture
after the fixture had already run `render-readme-block.sh --write`. Eight
tests went red. `readme_block.py:34` lists `CHANGELOG.md` in the block's Docs
section when the file exists, so creating the file afterwards left every
fixture's README block stale, and the gate's `--check` failed them.

The same holds for `DECISIONS.md`, `docs/ARCHITECTURE.md`, and any file the
block's Docs list names.

## The rule

In a fixture, create every project file first, then render the README block,
then commit. A new file the block links to goes above the render line, never
below it.
