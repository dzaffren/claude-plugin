# A skill's e2e that runs git directly never meets the hooks the skill will

**Learned:** 2026-10-06 · **From:** /debug release-commit-blocked

D1 decided that `/release` commits straight to `main`. `block-dangerous.sh`
has denied every commit on `main` since the zuko 2.0.0 rebuild. Both shipped,
and the suite stayed green: `test-e2e-release.sh:153` makes the release commit
with `git -C "$repo" commit --no-verify`, so no PreToolUse hook ever saw it.
The first real `/release` (v2.2.0) stopped at step 4, and the user had to run
the commit with `!`.

A hook fires on the Bash call Claude makes, not on git. An e2e that runs the
skill's commands itself proves the scripts, never the guards around them.

## The rule

When a skill step runs a command that a zuko hook matches (`git commit`,
`git push`, `git tag`, `gh release`, `curl`), its e2e also feeds that exact
command, as hook JSON, to every hook `hooks.json` binds to it, in a scratch
repo in the state the step runs in. It asserts exit 0. A decision that a stage
does something a guard forbids needs the guard changed in the same slice.
See [[test-the-guard-where-it-fires]].
