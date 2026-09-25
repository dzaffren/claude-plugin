# A guard reads every spelling the command's own parser accepts

**Learned:** 2026-09-25 · **From:** release review

The release review found three bypasses of the attribution hook, all one
class. The hook read `gh release create -F path` and `git tag --message`,
but the tools themselves also accept:

- `gh release new`, gh's built-in alias for `create`
- `-F=path`, where gh's flag parser drops the `=` (git keeps it)
- `--mess`, git's abbreviation of `--message`

## The rule

Before writing a guard over a CLI's options, check how that CLI parses them:
its aliases (`--help` lists them), whether it abbreviates long options, and
what it does with `=` after a short flag. git and gh differ on the last two,
so each needs its own answer. Test each spelling against the real tool first.
