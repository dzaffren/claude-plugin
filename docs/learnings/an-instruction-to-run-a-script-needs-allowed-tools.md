# A skill that tells you to run a script needs that script in allowed-tools

**Learned:** 2026-09-15 · **From:** /build on `readable-review-findings`

`skills/review/SKILL.md` gained one line telling the stage to run
`check-report.sh` before printing. Its frontmatter allowed
`Bash(git diff *) Bash(git status *) Bash(git log *) Bash(git stash list)` and
nothing else, so the instruction would have asked for a tool the skill is not
allowed to use — a prompt for permission mid-report, or a skipped check.

Adding an instruction to a skill means reading its `allowed-tools` line in the
same edit. The check is mechanical: every command the new text names must match
a pattern already there, or the pattern goes in with it.

The same trap sits in the pre-existing text: `/review` says "re-run the full
suite and the e2e test" while allowing no test runner at all. Written before
this lesson, still there, and worth fixing the next time that file is open.
