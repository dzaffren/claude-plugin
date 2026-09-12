# Git naming

Everything zuko writes into git follows this. One copy — never restate it in a
skill, or the two copies drift apart.

| Thing | Format | Example |
| ----- | ------ | ------- |
| Branch | `{type}/{slice}` | `feat/ship-naming` |
| Commit subject | `{type}({scope}): {subject}` | `feat(ship): standardise git naming` |
| Commit body | what changed and why, wrapped at 72 | — |
| PR title | the squash commit subject, unchanged | `feat(ship): standardise git naming` |

**Types:** `feat` `fix` `chore` `docs` `refactor` `test`. Nothing else.

**Scope:** the zuko stage or top-level area — `ship`, `build`, `spec`, `hooks`,
`scripts`, `docs`. Optional; `feat: …` is valid.

**Subject:** imperative, no trailing period, whole line ≤72 characters.

## Banned in every commit message and PR body

- `Co-Authored-By:` naming Claude or `noreply@anthropic.com`
- `Claude-Session:` and any `https://claude.ai/code/session_…` link
- `Generated with Claude Code`
- emojis, per `voice.md`

The harness re-injects an attribution instruction every session, so this will
keep being asked for. Say no. `scripts/block-attribution.sh` blocks the first
three at commit time, and `scripts/verify-ship-gates.sh` blocks them again for
the whole branch before the PR. To stop it at the source, the user sets
`attribution` in `~/.claude/settings.json`:

```json
{ "attribution": { "commit": "", "pr": "", "sessionUrl": false } }
```

Both strings replace the attribution text, so empty hides it.
