# A skill's allowed-tools must cover every command its subagents run

**Learned:** 2026-09-26 · **From:** owasp-lens build

The third seeded `/review` run gave the finding-verifier `git show` and a hook
that allowed it, yet 53 of its `git show` calls came back "Permission to use Bash
has been denied". The review skill's `allowed-tools` granted `Bash(git diff *)`
but not `Bash(git show *)`, and under `claude -p` nothing prompts, so an ungranted
command is refused. Each refusal cost a turn, and verifiers that ran out of turns
dropped real findings as "not confirmed". Adding `Bash(git show *)` to
`skills/review/SKILL.md` took the denials to zero in the next run.

Two more things kept costing turns after that. The agent kept sending searches to
Bash (`grep -r`, `find`) for the hook to block, and a blocked call that only said
"no" got retried in a new spelling. Once the block message named the tool to use
("To search or list files, use the Grep or Glob tool; to read a file, use Read."),
turn-limit events fell from 16 to 4.

## The rule

When a subagent gains a command, add it to the `allowed-tools` of every skill that
dispatches that subagent, then count the permission denials in a headless run.
The count should be zero. A guard that blocks an agent says what to use instead,
not only that the call was refused.
