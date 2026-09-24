# Integrate a chunk's branch by cherry-pick, not merge

**Learned:** 2026-09-24 · **From:** decision-log build

Chunk C of `decision-log` came back on its own worktree branch. Merging it
into `feat/decision-log` wrote a commit titled "Merge branch
'worktree-agent-…' into feat/decision-log". `verify-ship-gates.sh` checks the
subject of every commit ahead of the base, so that merge commit would have
failed the ship gate's naming check.

## The rule

Bring a chunk's commits onto the feature branch with `git cherry-pick <shas>`,
never `git merge`. If a merge has already happened, tag it, `git reset --keep`
to the commit before it, cherry-pick, then `git diff <tag> HEAD` to prove the
tree is unchanged.
