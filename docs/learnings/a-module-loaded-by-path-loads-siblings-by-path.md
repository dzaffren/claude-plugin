# A module that release.py loads by path must load its siblings by path

**Learned:** 2026-11-09 · **From:** /build strix-code

`release.py` loads each sibling with `load()`, by its file path, so it works
"whatever sys.path holds". `strix.py` did `import program`. That worked when
`release.py` ran as a script, because Python puts `lib/` first on
`sys.path`. It failed in `test-e2e-pentest-live.sh`, which loads `release.py`
by its path from another folder: three checks failed with an empty result.
The new tests passed, because they all ran `release.py` as a script.

## The rule

In a lib module that `release.py` loads, load each sibling by its path, as
`release-commit.py` does for `git-command.py`. Run the whole suite, not only
the new test files: the break shows only where another test loads the module
in another way.
