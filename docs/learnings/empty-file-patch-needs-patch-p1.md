# Apply a patch with an empty-file entry with `patch -p1` on Windows

**Learned:** 2026-11-07 · **From:** attack-classes build · **Rewritten:** 2026-11-08 by /review attack-classes

Seed 1's `range.patch` adds an empty file. On Git for Windows 2.46.1,
`git apply` refuses that entry, so the seeded run cannot start.

## The rule

On Windows, apply a seed patch that has an empty-file entry with `patch -p1`.
Use `git apply` on the other seeds.

This lesson was "a seeded pentester run proves nothing on Windows". The cause
was `is_scratch` in `scope-pentester-bash.sh`, which compared paths with
Windows `os.path.normpath`. D97 changed the fence to POSIX rules on every OS,
so that rule no longer holds.
