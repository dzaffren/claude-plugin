# Claude Code Plugin & Marketplace Conventions

Reference document for reviewing and authoring Claude Code plugins and marketplaces.
Sources: official docs at `code.claude.com/docs/en/` and `mrlm-xyz/demo-claude-marketplace`.

---

## Marketplace

### File location

`.claude-plugin/marketplace.json` at the repo root.

### Schema

```json
{
  "name": "kebab-case-id", // required — public-facing, used in /plugin install name@marketplace
  "owner": {
    // required
    "name": "Team or person name", // required
    "email": "optional@example.com" // optional
  },
  "metadata": {
    // optional block
    "description": "...",
    "version": "1.0.0",
    "pluginRoot": "./plugins" // prepended to relative source paths
  },
  "plugins": [
    // required — ARRAY not object
    {
      "name": "my-plugin", // required — kebab-case
      "source": "./plugins/my-plugin", // required — relative path starts with ./
      "description": "...",
      "version": "1.0.0",
      "author": { "name": "..." }
    }
  ]
}
```

### Common mistakes

- `plugins` must be an **array** `[...]`, not an object `{...}`
- `owner` is **required** — omitting it is a schema error
- Top-level `description` is not in the schema; use `metadata.description`
- Plugin `author` is a singular object `{name, email?}`, not an array of strings
- Relative `source` paths must start with `./`; `../` is not allowed
- Plugin names must be kebab-case (lowercase, digits, hyphens only); uppercase or spaces are rejected by Claude.ai marketplace sync

### Plugin source types

| Type                      | Example                                                                             |
| ------------------------- | ----------------------------------------------------------------------------------- |
| Relative path (same repo) | `"source": "./plugins/my-plugin"`                                                   |
| GitHub                    | `"source": {"source": "github", "repo": "owner/repo", "ref": "v1.0", "sha": "..."}` |
| Git URL                   | `"source": {"source": "url", "url": "https://...", "ref": "main"}`                  |
| Git subdirectory          | `"source": {"source": "git-subdir", "url": "...", "path": "tools/plugin"}`          |
| npm                       | `"source": {"source": "npm", "package": "@org/plugin", "version": "^2.0.0"}}`       |

Relative paths only work when the marketplace is added via git clone (not via direct URL to marketplace.json).

---

## Plugin

### Directory structure

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json          # manifest (only file allowed here)
├── commands/                # slash commands — *.md files
├── agents/                  # subagent definitions — *.md files
├── skills/
│   └── skill-name/
│       └── SKILL.md         # required entrypoint
├── hooks/
│   └── hooks.json
├── .mcp.json                # MCP server configs
├── .lsp.json                # LSP server configs
└── settings.json            # default settings when plugin enabled
```

### plugin.json schema

```json
{
  "name": "my-plugin",          // required — becomes skill namespace prefix
  "description": "...",         // shown in plugin manager
  "version": "1.0.0",           // semantic versioning
  "author": {                   // singular object, not array
    "name": "Team Name",
    "email": "optional"
  },
  "homepage": "https://...",
  "repository": "https://...",
  "license": "MIT",
  "keywords": ["tag1", "tag2"],
  "commands": ["./commands/"],              // optional custom paths
  "agents":   ["./agents/reviewer.md"],
  "skills":   ["./skills/verifier"],        // use ./ prefix
  "hooks":    "./hooks/extra.json",          // ONLY for additional hook files beyond hooks/hooks.json
  "mcpServers": { ... },
  "strict": true                            // default; false = marketplace entry is full definition
}
```

### Common mistakes

- `authors` (plural array) is not a valid field — use `author` (singular object)
- Paths in `commands`, `agents`, `skills` should be `./`-prefixed
- All directories (`commands/`, `agents/`, `skills/`, `hooks/`) go at the **plugin root**, NOT inside `.claude-plugin/`
- When `version` is set in both `plugin.json` and `marketplace.json`, `plugin.json` silently wins
- `hooks/hooks.json` is **auto-loaded** — do not reference it in the `hooks` field or you'll get a duplicate hooks error on install. Only use `hooks` for files at non-standard paths.

---

## Skills (SKILL.md)

### Frontmatter fields

```yaml
---
name: my-skill # display name; defaults to directory name
description: > # used by Claude to auto-invoke; also shown in /help
  What it does and when to use it.
disable-model-invocation: true # true = user-only invocation (manual /name only)
user-invocable: false # false = Claude-only (hidden from / menu)
allowed-tools: Read, Grep, Glob # tools Claude may use without approval when skill is active
model: claude-opus-4-6 # override model for this skill
effort: high # low/medium/high/max — overrides session level
context: fork # run in isolated subagent context
agent: Explore # which subagent to use (with context: fork)
hooks: { ... } # hooks scoped to this skill's lifecycle
shell: bash # or powershell (requires CLAUDE_CODE_USE_POWERSHELL_TOOL=1)
---
```

### String substitutions (resolved before Claude sees the content)

| Variable                | Resolves to                                                                                          |
| ----------------------- | ---------------------------------------------------------------------------------------------------- |
| `$ARGUMENTS`            | All text typed after the skill name                                                                  |
| `$ARGUMENTS[N]` or `$N` | Nth argument (0-based)                                                                               |
| `${CLAUDE_SESSION_ID}`  | Current session ID                                                                                   |
| `${CLAUDE_SKILL_DIR}`   | Absolute path to the directory containing this SKILL.md — use in bash injections and file references |

`${CLAUDE_SKILL_DIR}` is substituted at skill load time, so when Claude reads the skill, it sees the resolved absolute path. This enables skills to reference sibling files (`${CLAUDE_SKILL_DIR}/references/template.md`) portably regardless of where the plugin is installed.

### Dynamic context injection (bash injection)

Backtick syntax runs shell commands before the skill content reaches Claude:

```markdown
Current branch: !`git branch --show-current`
PR diff: !`gh pr diff`
```

This is preprocessing — Claude only sees the output, not the command.

### Supporting files

Skills can have sibling files (templates, examples, scripts). Reference them from SKILL.md:

```markdown
- For format rules, see [bdd-format.md](bdd-format.md)
- For the template, see [template-story.md](template-story.md)
```

Keep SKILL.md under 500 lines; move detailed material to referenced files.

### Invocation behaviour

| Frontmatter                      | User can invoke | Claude can invoke | Context loading               |
| -------------------------------- | --------------- | ----------------- | ----------------------------- |
| (default)                        | yes             | yes               | Description always in context |
| `disable-model-invocation: true` | yes             | no                | Description NOT in context    |
| `user-invocable: false`          | no              | yes               | Description always in context |

---

## Agents

### Frontmatter fields

```yaml
---
name: my-agent
description: >
  When Claude should use this agent. Be specific.
tools: # restrict available tools
  - Read
  - Grep
  - Glob
  - Bash
isolation: worktree # run in isolated git worktree
---
```

`isolation: worktree` creates a temporary branch/worktree for the agent — useful for parallel execution from commands. Changes are preserved; the worktree is cleaned up if no changes were made.

---

## Commands

### Format

```markdown
---
description: One-line description shown in /help
---

Given: $ARGUMENTS

## Instructions...
```

Commands are simpler than skills — no auto-invocation, no `${CLAUDE_SKILL_DIR}`, no supporting files. Skills are preferred; commands are kept for backward compatibility.

---

## Hooks

### hooks.json structure

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash", // tool name or regex
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/gate.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/format.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/verify.sh"
          }
        ]
      }
    ]
  }
}
```

### Available hook events

- `PreToolUse` — before a tool runs; can deny with JSON output
- `PostToolUse` — after a tool runs
- `Stop` — when the agent loop ends
- `Notification` — on Claude notifications

### Hook variables

- `${CLAUDE_PLUGIN_ROOT}` — plugin's installed directory; **only substituted in hooks.json strings**, NOT passed as an env variable to shell scripts
- Shell scripts launched by hooks must find their own path via `dirname "$0"` if they need to reference sibling files

### Deny response format (PreToolUse)

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Human-readable reason"
  }
}
```

### Block response format (Stop hook)

```json
{ "decision": "block", "reason": "Human-readable reason" }
```

### Hook stdin

All hooks receive a JSON object on stdin. Key fields:

- `tool_input.command` — for Bash hooks
- `tool_input.file_path` — for Write/Edit hooks (NOT present in MultiEdit — MultiEdit has an array of edits)
- `stop_hook_active` — `true` if already in a stop-triggered re-run (use to avoid infinite loops)

---

## Variables Reference

| Variable                | Available in                                                             | Resolves to                                                                                                        |
| ----------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| `${CLAUDE_PLUGIN_ROOT}` | SKILL.md content, agent content, hooks.json, .mcp.json, monitor commands | Plugin's installed cache directory (substituted inline in skill/agent content too, per official plugins-reference) |
| `${CLAUDE_PLUGIN_DATA}` | hooks.json, .mcp.json                                                    | Persistent data directory (survives updates)                                                                       |
| `${CLAUDE_SKILL_DIR}`   | SKILL.md content                                                         | Directory containing the SKILL.md file                                                                             |
| `${CLAUDE_SESSION_ID}`  | SKILL.md content                                                         | Current session ID                                                                                                 |
| `$ARGUMENTS`            | SKILL.md, commands                                                       | Text after skill/command name                                                                                      |
| `$ARGUMENTS[N]` / `$N`  | SKILL.md                                                                 | Nth positional argument                                                                                            |

---

## Validation

```bash
claude plugin validate .          # from terminal
/plugin validate .                # from within Claude Code
```

Checks: `plugin.json`, skill/agent/command frontmatter, `hooks/hooks.json` syntax.

### Common validation errors

| Error                                             | Cause                      | Fix                                      |
| ------------------------------------------------- | -------------------------- | ---------------------------------------- |
| `File not found: .claude-plugin/marketplace.json` | Missing manifest           | Create it                                |
| `plugins[0].source: Path contains ".."`           | `../` in source path       | Use paths relative to marketplace root   |
| `Duplicate plugin name`                           | Two plugins with same name | Rename one                               |
| `YAML frontmatter failed to parse`                | Bad YAML in SKILL.md       | Fix YAML syntax                          |
| `Invalid JSON syntax` in hooks.json               | Malformed hooks            | Fix JSON — this blocks the entire plugin |

---

## Workflow Patterns

### Spec → Build handoff

- `spec` skill creates `specs/{ticket}-{name}/spec.md` (subdirectory, not flat file)
- `build` command must resolve `../specs/{name}/spec.md` or `specs/{name}/spec.md`
- Section names used in `build` must match section names in the spec template; if template changes, update both

### Stop hook + verifier pattern

- Stop hook runs after agent loop ends
- Use `stop_hook_active` flag to prevent infinite loop
- Cap retries with a temp file keyed by `${CLAUDE_SESSION_ID:-default}`
- Exit 0 (no output) = pass; output JSON block = re-run

### Parallel execution pattern

- Mark sub-tasks as INDEPENDENT in spec
- `build.md` spawns one `feature-builder` agent per INDEPENDENT task
- `feature-builder` uses `isolation: worktree` for safe parallel execution
- SEQUENTIAL tasks run in order, each depending on previous output

---

## Reserved Marketplace Names

Cannot be used: `claude-code-marketplace`, `claude-code-plugins`, `claude-plugins-official`, `anthropic-marketplace`, `anthropic-plugins`, `agent-skills`, `knowledge-work-plugins`, `life-sciences`, and names that impersonate official Anthropic marketplaces.
