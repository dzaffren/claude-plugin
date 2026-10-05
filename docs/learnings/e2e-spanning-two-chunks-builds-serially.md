# An e2e that spans two code chunks cannot be built in parallel

**Learned:** 2026-10-05 · **From:** pentest-live build

The `pentest-live` plan cut three chunks: A (the test harness), then B (the
target guard) and C (the skill, agent and release.py) "in parallel". But the
one e2e test in chunk A exercises the guard from B and the skill snippet plus
release.py from C in the same file. A single test file passes or fails as a
unit, so neither B nor C could turn it green alone — each parallel worktree
agent would have seen it red and had no way to finish.

## The rule

When the e2e, or any one test, needs code from more than one chunk, those
chunks are not parallel. Build the harness first and red, then the code chunks
serially in one checkout, and let the shared test go green at the end.

Parallel worktrees only pay off when each chunk owns a test it can green by
itself. A test that straddles two chunks turns the parallel plan into two
agents stuck at red and an integration step that still has to do the real work.

## Where to catch it

At `/spec`, in the Chunks table: trace each test in the harness chunk to the
chunks it needs. A test that needs two or more collapses their parallelism.
Say so in the plan, or re-cut the e2e so each chunk has a test it owns.

Related: the harness is still the first chunk
([detail](harness-before-the-chunks-it-proves.md)), and chunks are cut by file
([detail](chunk-by-file-not-by-story.md)).
