# A hook reads a file option's path as written, not as the shell expands it

**Learned:** 2026-10-13 · **From:** decision-pr build

`block-attribution.sh` reads a `gh pr create --body-file` file to check the
PR body. It gets the command text from the hook payload, before the shell
runs it. A path written as `"$(git rev-parse --git-dir)/zuko-pr-body.md"`
reaches the hook as that literal text. `os.path.isfile` says no, the hook
reads nothing, and the body goes through unchecked. A relative path resolves
against the hook's working directory, which need not be the repo.

## The rule

When a skill passes a file to a command that a hook reads, the skill finds
the absolute path first (`git rev-parse --absolute-git-dir`) and writes it
out in full in the command. Prove it in the e2e: send the command with that
path to the hook, once with a clean file (exit 0) and once with a file that
the hook must block (exit 2). Only the blocked case shows that the hook read
the file.
