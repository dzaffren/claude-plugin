# Replacing a broad matcher with a precise one turns false blocks into false allows

**Learned:** 2026-09-12 · **From:** /review hook-command-match

`block-dangerous.sh` matched `git commit` anywhere in the command text. That
over-blocked prose, so the fix parsed the command and matched only a git
invocation at a command position. Three real destructive commands then walked
straight through, all of which the old grep had caught:

- `sudo git commit`, `GIT_AUTHOR_NAME=x git commit`, `eval git push --force`,
  and `for f in a; do git commit; done` — any word before `git` meant it was
  no longer "at a command position"
- `git add .` + a blank line + `git commit` — `shlex` returns `\n\n` as one
  token, and the separator test compared tokens against a fixed set
- `git push --force-with-lease=main` — the regex anchored on whitespace after
  the flag, and `=` is not whitespace

## The rule

A precise matcher only removes matches. Before shipping one, take the inputs
the broad matcher caught and prove the precise one still catches them —
diff the two implementations on the same input set rather than testing the
new one alone:

```bash
probe() {           # exit 0 from new + exit 2 from old = a new hole
  new=$(printf '%s' "$1" | bash new.sh >/dev/null 2>&1; echo $?)
  old=$(printf '%s' "$1" | bash <(git show main:path/to/old.sh) >/dev/null 2>&1; echo $?)
}
```

And pick the narrowest test that fixes the actual bug. Here the bug was prose
being read as a command, and quoting already collapses prose into one token —
so "is this a bare `git` token" was enough. "Is this at a command position"
modelled far more of the shell than the fix needed, and every part of that
model that was wrong became a hole. Same reasoning as
[[test-the-guard-where-it-fires]]: state what the guard actually depends on.
