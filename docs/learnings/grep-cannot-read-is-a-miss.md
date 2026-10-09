# A gate that greps a file it cannot read sees no match

**Learned:** 2026-10-09 · **From:** stop-hook-scope build

`check-open-items.sh` found Open rows with `grep ... 2>/dev/null || true`. On
a doc it could not read (`chmod 000`), grep printed nothing to stdout, the
error went to /dev/null, and the gate read "no Open rows" and exited 0. The
spec it exists to guard passed unjudged. `verify-gates.sh` only failed the
same doc by luck: its Status grep also came back empty, so it reported
"Status 'missing'".

## The rule

A gate decides from a file only after it has read that file. Read it once,
in one place that fails on an error (here `lib/stop_scope.py` opens every doc
it lists and exits 1 when it cannot), and let the grep-based checks run only
on files that passed that read. Never pair `2>/dev/null` with `|| true` on
the line that decides the verdict.

A Stop hook that lists nothing is different: since D35 an empty list means
the turn changed no zuko doc, and exit 0 is the right answer. The empty-scope
rule in [the gate lesson](gate-scanned-nothing-is-not-a-pass.md) is about a
target that should exist, not about a turn with nothing to judge.
