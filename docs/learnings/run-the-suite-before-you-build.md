# Run the whole suite before building on it

**Learned:** 2026-09-24 · **From:** auto-onboard build (fix in PR #30)

Before `/build` started on `auto-onboard`, the suite on `main` was 52 passed and
23 failed. Every failure was exit 127, meaning "command not found".
`test-block-attribution.sh:17` ran the hook through `timeout 5`. That comes from
GNU coreutils, which macOS does not ship. So the hook never ran, and each
assertion failed before it tested anything.

Nothing had caught it because nobody ran the suite on this machine after
`1a84cf9` added the `timeout` call. A build on top of that baseline could not
have told its own failures apart from the old ones.

## The rule

Run the full suite before the first line of a build, and treat a red baseline as
its own light-path fix, shipped first. Exit 127 in a test means a missing
command, not a failing assertion. Look at the harness before you look at the
code.

In test scripts, use only commands that macOS and Linux both ship. For a time
limit, use perl's `alarm` rather than `timeout`.
