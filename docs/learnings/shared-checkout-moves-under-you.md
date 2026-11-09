# Build in your own worktree when another session shares the checkout

**Learned:** 2026-11-09 · **From:** portable-suite build

A second Claude session ran `/spec needs-validation` in the same checkout. It
switched the checkout to `feat/needs-validation` and committed there. The
`git switch -c feat/portable-suite` that `/build` ran then branched from those
commits, not from `main`, and the next `DECISIONS.md` append landed after that
session's D100 to D103. Later the other session put the checkout on `main`,
and the main-branch guard blocked each commit whose directory it could not
read from the command.

## The rule

Before `/build` branches, check `git branch --show-current` and branch from
`main` by name: `git switch -c {type}/{slice} main`. When another session may
use the checkout, build in a worktree of your own, and commit with
`git -C <literal path>`, because the guard does not expand a variable.
