# An agent's Bash calls start fresh, and a prefix covers one command

**Learned:** 2026-09-27 · **From:** /review of the pentest build

Two ways the pentester's proof fence leaked, found by review:

- **Nothing carries between Bash calls.** `work=$(mktemp -d)` in one call is
  gone in the next, and the working directory is back in the repo. A step that
  used `$work` later ran with an empty variable, in the real repo.
- **`VAR=value cmd` covers only `cmd`.** In `HOME=/x a | b`, `b` runs with the
  real `HOME`. So does everything after `&&`.

## The rule

A multi-step procedure an agent runs goes in one Bash call. Print a path once,
then write it out literally: `cd /var/folders/.../tmp.X && export HOME=... &&
...`. Join the steps with `&&`, never `;` or `||`. A `cd` that fails must stop
the rest, or the rest runs where the `cd` started. `export` a fence; never
prefix it.

A hook that enforces this checks the joiner after the command that set the
mode, not before it. The first fence let `cd X; echo x > README.md` through
because it judged the `;` while it still thought it was in the repo.
