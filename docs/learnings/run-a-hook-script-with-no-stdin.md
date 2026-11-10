# Run a hook script by hand with `</dev/null`

**Learned:** 2026-11-10 · **From:** /spec fence-backslash

`verify-gates.sh` is a Stop hook, so its first line is `input=$(cat)`: it reads
the hook payload from stdin. Run by hand from the Bash tool, stdin was a socket
that never closed. The gate sat in `cat` for a night, and the `git commit`
chained after it never ran until the gate was killed.

## The rule

Any zuko script that a hook also calls reads stdin first. Run it by hand with
`</dev/null`, or pipe it a payload, and never chain a commit after it with `;`.
