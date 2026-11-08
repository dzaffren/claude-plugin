# Set MSYS=noglob when native Windows code starts a Git Bash program

**Learned:** 2026-11-09 · **From:** portable-suite build

`release.py` and `board.py` run a test's stub `gh` through Git Bash's
`bash.exe`. A Git Bash program that a native program starts gets a Windows
command line, and it expands `{a}`, `*` and `[..]` in it, so
`repos/{owner}/{repo}` arrived as `repos/owner/repo`. `program.argv()` now adds
`noglob` to `MSYS`.

## The rule

When native Windows code starts a Git Bash program with arguments that hold
`{`, `*`, `?` or `[`, put `noglob` in `MSYS` first. A test of such code on
Linux cannot show the bug; only a Windows run can.
