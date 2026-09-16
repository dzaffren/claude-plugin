# A check that could not run is not a miss

`expect_match` ran `printf ... | grep -qE` and treated every non-zero exit as
"the text is not there". `grep` exits 1 when it ran and found nothing, but 2 or
worse when it never started — and under memory pressure it does not start.
Three live sessions at once leave about 3 GB free on this machine, which is
enough to hit it.

The result was a suite that failed roughly one run in fourteen, always on text
that was plainly present, and never in the same place twice. It survived twenty
clean re-runs, so it read as unreproducible noise.

`grep_text` in `scripts/tests/run.sh` now retries when the exit code is neither
0 nor 1, and records "the check never happened" if it still cannot run.

This is [[gate-scanned-nothing-is-not-a-pass]] one level down. That lesson is
about a run that scanned no files reporting success; this is about a single
assertion that never executed reporting a verdict on content. Both come from a
tool's "I did nothing" being spelled the same way as its "I found nothing".

When a check is flaky and the text is obviously there, suspect the checker
before the content.
