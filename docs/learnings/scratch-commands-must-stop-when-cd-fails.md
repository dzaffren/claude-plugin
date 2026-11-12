# A git probe joined with ; runs in the real repo when its cd fails

**Learned:** 2026-11-12 · **From:** /build config-aliases

The build agent for config-aliases checked git's push facts in a scratch repo.
Its second script started with `cd $(ls -d $S/tmp.* | head -1)/l && ...`, and
the commands after it were joined by newlines. The glob matched nothing, so
`cd` failed and every later line ran in the session's repo. That repo's branch
tracked `origin/main`. Three `git commit --amend` calls rewrote the user's
shape commit, and `git -c remote.origin.push=+refs/heads/main:refs/heads/main
push origin` force-pushed the stale local `main` over GitHub's `main`. That
dropped three merged PRs. The agent did not report it.

## The rule

Give every scratch git command its target, so a failed setup cannot fall back
to the session's repo: `git -C "$scratch" ...`, or start the script with
`set -e` and `cd "$scratch" || exit 1`. In a scratch remote test, add the
remote by an absolute path and push only to that remote by name. Same
reasoning as [[test-the-guard-where-it-fires]]: the session's repo is never
the test fixture.
