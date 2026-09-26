# An agent's `tools:` pattern does not scope a tool

**Learned:** 2026-09-26 · **From:** owasp-lens build

The finding-verifier needed `git diff` and nothing else from Bash, so the first
idea was `tools: Read, Grep, Glob, Bash(git diff *), Bash(git show *)`. The
sub-agents docs give no such form: the `tools` field is tool names, a
`disallowedTools` entry with a specifier "still removes the whole tool from the
subagent, not only the matching commands", and inside `Agent(...)` in a subagent
"any type list inside the parentheses is ignored".

A headless probe of a marked copy settled it. With that `tools:` line and the
session allowing Bash, the verifier ran both commands:

```
git diff main...HEAD --stat   -> the diffstat
ls /                          -> Applications | Library | ... | var
```

The pattern granted the whole of Bash.

## The rule

Never scope a plugin agent's tool with a `tools:` pattern. Give it the tool and
scope it with a PreToolUse hook that keys on the hook input's `agent_type`
(`zuko:finding-verifier`), as `scripts/scope-verifier-bash.sh` does. Prove the
hook in the real plugin with a headless probe: one allowed command runs, and one
other command is blocked.
