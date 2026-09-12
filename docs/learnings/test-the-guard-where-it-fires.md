# A branch-conditional guard proves nothing when tested from a branch

**Learned:** 2026-09-12 · **From:** /build hook-command-match

`block-dangerous.sh` only denies a commit when `HEAD` is `main` or `master`.
The build for that guard runs on `feat/...`, so the first run of the four
acceptance scenarios came back with every commit row green — including the
rows that were supposed to be red. The guard was not passing; it was never
reaching the branch check.

The same trap catches any guard whose verdict depends on ambient state: the
current branch, the staged diff, an env var, the working directory.

## The rule

Give the test its own state instead of borrowing the session's. A throwaway
repo costs two lines:

```bash
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
git -C "$scratch" init -q -b main
export CLAUDE_PROJECT_DIR="$scratch"
```

Then print the state the assertions depend on — `harness branch: main` — so a
green run cannot be mistaken for a run that skipped the check. Same reasoning
as [[gate-scanned-nothing-is-not-a-pass]]: a pass has to say what it inspected.
