# The test harness cannot be the last chunk

**Learned:** 2026-09-12 · **From:** ship-naming build

The `ship-naming` plan cut four chunks: A, B and C in parallel, then D — the
test runner and every fixture — serial afterwards, "because it tests what B
and C build".

That ordering makes test-first impossible. Chunks B and C each had to write
a guard script with no way to run a single assertion against it, then hand it
to a later chunk to be covered retroactively. A test written after the code
it covers has already lost the thing that makes it worth writing: it never
failed for the right reason, so nothing proves it is testing anything.

## The rule

When a slice builds its own test harness, the harness is the first chunk, not
the last. Everything that depends on it comes after, and each dependent chunk
writes its own fixtures as it goes.

The dependency to order by is "can this chunk run a test", not "does this
chunk's subject matter come first".

## What it looked like in practice

```
planned:   A ─┐
           B ─┼─► D (harness + all fixtures)
           C ─┘

built:     harness ─► test 2 ─► code 2 ─► test 4,5 ─► code 4,5 ─► A ─► e2e
```

Serial, and no slower — the parallel chunks were six small files, and this
repo already knows that worktree agents often fail to commit
([detail](worktree-agents-cannot-commit.md)).

## Where to catch it

At `/spec`, when writing the Chunks table: if a chunk's files include the
runner, the assertion helpers, or the first fixtures, it is chunk one. If it
is anywhere else in the table, the plan is asking for code before tests.
