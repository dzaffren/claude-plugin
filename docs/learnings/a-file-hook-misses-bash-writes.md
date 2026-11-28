# A Write or Edit hook never sees a file that Claude writes with Bash

**Learned:** 2026-11-28 · **From:** /poc for /spec plain-words

In the first headless run of the O3 spike, Claude was asked to create
`notes.md`. It wrote the file with a Bash command, not the Write tool, so the
PostToolUse hook on `Write|Edit|MultiEdit` never fired. The run looked like a
"no" until the hook's own log showed that it had never started.

## The rule

A check that hangs on `Write|Edit` covers only the saves made through those
tools. When the check must not miss a file, back it up in the Stop hook on the
docs this work touched, as plain-words does (D178). In a spike, log each hook
start to a file, so "never ran" and "ran and said nothing" look different.
