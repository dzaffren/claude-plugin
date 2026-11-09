# An os.sep fix cannot fail on Linux

**Learned:** 2026-11-09 · **From:** /build windows-paths

On Linux and macOS `os.sep` is `/`, so `.replace(os.sep, "/")` changes
nothing there. A test of the fix passes before and after it, and the
test-first step cannot watch it fail. The red proof is a Windows run from
before the fix.

To check that a new test can see the bug at all, make the fixed line write
`\` on purpose, run the test on Linux, then put the line back. Do not keep
that change.

Also compare a Windows failure with the same check in a run from before the
fix. When it fails the same way, the fix did not cause it, and it may not be
a path problem at all.
