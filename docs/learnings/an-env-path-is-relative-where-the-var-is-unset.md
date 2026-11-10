# A path built from a variable is relative where the variable is unset

**Learned:** 2026-11-09 · **From:** chrome-lookup build

node-lookup's spec said Chrome always starts by an absolute path. It read
`findChrome()` on Windows only. On Linux and macOS, `LOCALAPPDATA` is not set,
so `join('', 'Google/Chrome/...')` is a relative path. The fall back
`C:\Program Files` is relative there too, because posix reads it as one
folder name. A planted file at that path ran in place of the real Chrome.

## The rule

Before a spec calls a built path absolute, build it with each variable unset,
on each OS the code runs on. Skip a candidate that is not absolute before it
reaches the disk. A path that looks absolute on one OS may be a plain name on
another.
