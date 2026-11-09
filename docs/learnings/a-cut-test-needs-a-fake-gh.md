# A test that runs cut needs a fake gh on PATH

**Learned:** 2026-11-09 · **From:** /build strix-live

`release.py cut` runs the release gates first, and the CI gate asks `gh api`
for the check runs of HEAD. A new e2e test put stub `strix` and `docker` on
PATH and left `gh` out. Its `cut` called the real `gh`, which asked GitHub
about a made-up repo, got a 404, and failed the gate before the pentest check.

## The rule

A test that runs `cut` puts the fake `gh` of `test-e2e-strix-code.sh` on PATH
with the other stubs. When `cut` prints `Release gates FAILED` with a `gh:`
error, look for the missing stub before the code.
