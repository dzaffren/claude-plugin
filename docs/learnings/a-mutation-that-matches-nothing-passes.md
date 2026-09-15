# A mutation test that matches nothing passes for the wrong reason

**Learned:** 2026-09-15 · **From:** /review on `readable-review-findings`

A guard is tested by breaking its input and asserting the guard complains. When
the break is a literal `str.replace`, and the text it looks for has since been
edited, the replace matches nothing, the "broken" file is the conforming one,
and the assertion passes. The suite stays green while the rule it names goes
untested.

It happened here twice in one slice:

- `test-check-report.sh` deleted a glossary line by its exact wording. The
  wording changed in `references/report.md` during the same review, the deletion
  stopped matching, and the test went from proving the rule to proving nothing.
  It failed loudly only because the *checker* had also improved.
- The path-stripping test named the rule it protected but exercised a different
  one. Removing the rule from the script left the suite at 22 passed.

Two habits close it:

1. Make the mutation assert it changed something. Three lines in the helper:
   `assert broken != text, "mutation matched nothing: %s" % expression`.
2. Prove the test can fail. Delete the rule from the code and watch that
   specific assertion go red before trusting it.

Mutating by pattern (`re.sub(r'^  token .*\n', ...)`) survives an edit to the
line's wording where a literal does not.
