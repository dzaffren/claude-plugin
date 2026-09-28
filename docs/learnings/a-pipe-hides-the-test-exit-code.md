# A pipe into tail hides the test runner's exit code

**Learned:** 2026-09-28 · **From:** /review regression-review

`run.sh regression-review | tail -1 && git commit` committed with one check
failing: the chain tested `tail`'s exit status, not `run.sh`'s. It printed
"70 passed, 1 failed" and committed anyway.

## The rule

When a commit depends on the suite, run the suite on its own and gate on its
exit code (`run.sh; echo "exit $?"`, or redirect to a file and `tail` the file
after). Never put a pipe between the runner and the `&&`.
