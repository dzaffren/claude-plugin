# A CI runner has no git identity

**Learned:** 2026-11-09 · **From:** zuko /build windows-ci (PR #136)

On a developer machine, git guesses a committer from the login name and the
host, so a test that commits or merges without `-c user.name` still passes.
A GitHub runner has no git user and an empty login name, so the same command
fails with `Committer identity unknown`. In `test-replay.sh` a squash merge
of a diverged branch failed that way, the next commit had nothing to commit,
and three checks failed on both runners while the suite passed locally.

## The rule

Every git command in a test that writes a commit or a merge passes the test
identity, `-c user.name=Test -c user.email=test@example.com`. To check a test
file the way a runner sees it, run it with git forbidden to guess:

```bash
HOME=$(mktemp -d) GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_COUNT=1 \
  GIT_CONFIG_KEY_0=user.useConfigOnly GIT_CONFIG_VALUE_0=true \
  bash plugins/zuko/scripts/tests/run.sh
```
