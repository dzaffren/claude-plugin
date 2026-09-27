# A scratch copy is not a sandbox: point HOME inside it too

**Learned:** 2026-09-27 · **From:** /build pentest, seeded run 1

The pentester ran its proof inside `mktemp -d`, on a `git archive` copy, with a
harmless payload. The code under test still called `gpg`, and `gpg` created
`~/.gnupg` in the real home directory. The payload stayed in the scratch copy;
the tool the product called did not. A tool keeps its config and cache under
`HOME`, not under the working directory.

## The rule

When an agent runs code under test, it sets `HOME`, `XDG_CONFIG_HOME`,
`XDG_CACHE_HOME` and `TMPDIR` inside the scratch copy for every command, and
checks afterwards that nothing outside the copy changed. A stub on `PATH` for a
tool the proof does not need (run 2 stubbed `gpg`) is better still.

When you check that a folder did not change, list its contents, not `ls -la`
of the folder itself: the `..` line reflects the parent's changes and gives a
false alarm.
