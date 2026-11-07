# An old Windows clone keeps its CRLF files

**Learned:** 2026-11-07 · **From:** /build guard-paths

The `.gitattributes` rule from `lf-checkout` changes only the files that git
writes again. In this repo's main checkout, 349 files stayed `w/crlf` after the
rule merged. A fresh worktree of the same commit had LF everywhere. So
`test-block-attribution.sh` failed 4 checks in the main checkout and 3 in the
agent's worktree, on the same code. The extra check joins `git-naming.md` with
`tr '\n' ' '`, and the `\r` that stays breaks its regex.

## The rule

On Windows, compare test counts in a fresh worktree, or check
`git ls-files --eol` for `w/crlf` first. A failure that only the main checkout
shows is the checkout, not the code.
