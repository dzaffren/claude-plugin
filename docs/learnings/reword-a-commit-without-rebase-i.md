# Rewording a commit when `rebase -i` is not available

**Learned:** 2026-09-12 · **From:** ship-naming ship

The ship gate rejected the branch over one commit's subject and trailers. The
obvious fix is `git rebase -i main` and change `pick` to `reword` — and
interactive git flags do not work in this environment.

What does work is replaying the branch by hand onto its base:

```bash
git branch backup/{slice}                       # the escape hatch, first
git checkout --detach main
git cherry-pick {bad}                           # the one to fix
git commit --amend -m "{new subject}" -m "{new body}"
git cherry-pick {bad}..backup/{slice}           # everything after it, in order
git branch -f {slice} HEAD
git checkout {slice}
```

The range `{bad}..backup/{slice}` excludes `{bad}` itself and replays the rest
in order, so a linear branch comes back identical apart from the one message.

## Prove it before you trust it

The whole point is that nothing but the message changed, so check exactly that:

```bash
git diff --quiet backup/{slice}..HEAD && echo "identical"
```

If that prints nothing, a cherry-pick resolved differently than you think and
the replay is not clean. Do not carry on.

## When to reach for it

Only on a branch that is not pushed — check with
`git ls-remote --exit-code --heads origin {slice}`. Every commit gets a new
SHA, so on a pushed branch this becomes a force-push, which is a different
conversation and needs asking first.

Keep `backup/{slice}` until the PR is merged, then delete it.
