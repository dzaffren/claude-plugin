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

Position counts too. `pr-attribution` (2026-09-28) read every spelling of
`-b` and `-F`, then missed `gh pr -R o/r create`: the command group's own
flag (`gh pr --help`, `-R/--repo`) sits before the subcommand. Read the
group's `--help`, not only the subcommand's.

A value can spell an option too. The force-push check (2026-10-07) read
`--force` and `-f`, and git 2.52.0 also forced with `-uf` (a bundled short
flag), `--mi` (a prefix of `--mirror`, which forces every ref), and
`origin +main` (a refspec whose leading `+` forces that one ref). List the
spellings from `git push -h` and the refspec docs, then prove each against a
scratch bare remote.
