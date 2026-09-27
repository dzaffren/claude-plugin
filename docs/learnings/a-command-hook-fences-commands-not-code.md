# A command-text hook fences commands, not code

**Learned:** 2026-09-27 · **From:** two review rounds on the pentester fence

`scope-pentester-bash.sh` reads the text of each Bash call and allows only
read-only git, `mktemp -d`, and commands inside a scratch copy. Review 1 made
it look like a sandbox. Review 2 walked straight through it from inside the
copy: `echo 'git push' | sh`, `python3 -c "..."`, `node -e`, `sh x.sh`,
`tar -xPf`. Each is one shell command the hook allowed, and each then runs code
the hook never sees.

## The rule

A PreToolUse hook that inspects command text can stop obvious escapes — a
nested shell, an interpreter's inline-code flag, an untracked script, tar
reaching outside a dir — and those are worth blocking. It cannot confine what a
program it allows then does: a tracked program that opens a socket or writes
through `$HOME` or `/tmp` is invisible to it. Say that limit in the decision
and the docs, and point untrusted code at a real OS sandbox. Do not let the
hook's wording claim confinement it does not deliver.

To tell "the pentester's own script" from "the project's code", check the path
against the real repo with `git ls-files --error-unmatch`: a `git archive`
scratch copy mirrors the repo, so a file it tracks is the project's, and one it
does not is something the pentester wrote.
