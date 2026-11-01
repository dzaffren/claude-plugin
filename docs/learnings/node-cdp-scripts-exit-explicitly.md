# A Node script that drives a browser must call process.exit

**Learned:** 2026-11-01 · **From:** /spec pause 3 spike, rendered-drift-check

A spike with v2's `cdp.mjs` finished its work in 1.9 s, but the process took
11 to 26 s to end. After `Browser.close`, open CDP timers and socket handlers
kept the event loop alive. Nothing was wrong in the output, so only a timed
run showed it.

## The rule

End a browser-driving script with `process.exit(code)`, after stdout and
stderr have flushed (exit in the write callback, so a piped report is not
cut). Give its e2e a wall-clock limit, so a hang fails a test and does not
just slow every pause.
