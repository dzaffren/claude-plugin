# A new gate check breaks every fixture that does not satisfy it

**Learned:** 2026-09-24 · **From:** readme-block build

Adding the README check to `verify-ship-gates.sh` made every existing test
repo that expected a passing gate fail — `test-e2e-naming.sh` and
`test-e2e-onboard.sh` had no README block. The failure was unrelated to what
those tests prove.

Wrong: commit the gate change first, then fix the fixtures.
Right: commit the fixture update first (give each repo what the new check
needs, rendered by the real script), then the gate and its own tests, so
every commit's suite stays green and old tests still fail only for their own
reason.
