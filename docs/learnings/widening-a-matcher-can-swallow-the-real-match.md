# Widening what starts a match can swallow the real match after it

**Learned:** 2026-11-11 · **From:** /review git-spellings

`git-command.py` started a git call only at a bare `git` word. git-spellings
widened that to any word whose last path part is `git`, to catch
`/usr/bin/git`. The wider test then fired on `A=/x/git` and `env -C /srv/git`,
which come before the real `git`. The real `git` became the first argument
of the false call, the guards saw the subcommand `git`, and
`A=/x/git git push --force origin main` passed. origin/main had blocked it.

The build's replay compared verdicts over 28009 real commands and found
nothing, because no real command had that shape.

## The rule

A change that must only add blocks has to keep every output of the old code.
Check it as a set: run old and new on the same corpus and prove the old lines
are a subset of the new ones. Then try adversarial inputs where the new
trigger appears just before the old one. When a wider trigger fires, keep the
old start too. Overlapping matches are safe. A match that replaces the old
one is not.
