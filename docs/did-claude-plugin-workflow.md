# Org-Wide Claude Code Plugin — Multi-Stack Autonomous Workflow

## Overview

A single Claude Code plugin that gives every repo in your org the same autonomous workflow: hooks, agents, commands, verifiers. Repos install it with one command. The plugin auto-detects the tech stack and adapts.

```
did-claude-plugin/                   ← this repo (marketplace + plugin)
├── .claude-plugin/
│   └── marketplace.json             ← marketplace index (lists all plugins)
└── plugins/
    └── did-workflow/
        ├── .claude-plugin/
        │   └── plugin.json          ← plugin manifest
        ├── hooks/
        │   └── hooks.json           ← hook definitions
        ├── scripts/
        │   ├── block-dangerous.sh   ← universal safety gate (PreToolUse)
        │   ├── auto-format.sh       ← auto-detects stack, formats (PostToolUse)
        │   └── stop-verify.sh       ← delegates to verifier (Stop hook)
        ├── agents/
        │   ├── reviewer.md          ← scope-check judge (unwired, reserved for future use)
        │   └── feature-builder.md   ← sub-task implementer (worktree isolated)
        ├── commands/
        │   ├── spec.md              ← feature spec generator
        │   ├── build.md             ← spec executor
        │   └── migrate.md           ← migration runner
        ├── references/
        │   └── bdd-format.md        ← Gherkin format and scenario rules
        └── skills/
            └── verifier/
                ├── SKILL.md         ← agent-facing interface (opaque)
                └── scripts/
                    ├── verify.sh              ← dispatcher (detects stack)
                    ├── detect-stack.sh        ← stack detection logic
                    ├── verify-node-jest.sh    ← TypeScript/JS + Jest
                    ├── verify-node-vitest.sh  ← TypeScript/JS + Vitest
                    ├── verify-python.sh       ← Python + pytest
                    └── verify-java.sh         ← Java/Kotlin + Gradle/Maven
```

---

## Installation (per repo)

### Step 1 — Add the marketplace to the repo's `.claude/settings.json`

```json
{
  "extraKnownMarketplaces": {
    "org-tools": {
      "source": {
        "source": "github",
        "repo": "your-org/did-claude-plugin"
      }
    }
  },
  "enabledPlugins": {
    "did-workflow@org-tools": true
  }
}
```

### Step 2 — Install the plugin (one-time per machine, or auto via settings)

```
/plugin marketplace add your-org/did-claude-plugin
/plugin install did-workflow
```

That's it. The repo now has:
- Safety hooks (PreToolUse blocks dangerous commands)
- Auto-format on every file write (PostToolUse)
- Verification gate before agent stops (Stop hook)
- `/spec`, `/build`, `/migrate` commands
- `feature-builder`, `reviewer` agents
- Stack-aware verifier skill

Each repo still needs its own `CLAUDE.md` describing its specific architecture, conventions, and file layout. The plugin provides the workflow machinery; the CLAUDE.md provides the project-specific context.

---

## Plugin Manifest

### `.claude-plugin/marketplace.json`

```json
{
  "name": "org-claude-plugins",
  "description": "Internal plugin marketplace for DID-wide Claude Code workflows",
  "plugins": {
    "did-workflow": {
      "source": "./plugins/did-workflow"
    }
  }
}
```

### `plugins/did-workflow/.claude-plugin/plugin.json`

```json
{
  "name": "did-workflow",
  "version": "1.0.0",
  "description": "DID-wide autonomous coding workflow: hooks, agents, commands, and stack-aware verifiers.",
  "authors": ["Platform Team"],
  "agents": [
    "agents/reviewer.md",
    "agents/feature-builder.md"
  ],
  "commands": [
    "commands/spec.md",
    "commands/build.md",
    "commands/migrate.md"
  ],
  "skills": [
    "skills/verifier"
  ]
}
```

---

## Hooks

### `hooks/hooks.json`

Hook scripts are referenced via `${CLAUDE_PLUGIN_ROOT}`, which Claude Code resolves
to the plugin installation directory at runtime.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/block-dangerous.sh"
        }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [{
          "type": "command",
          "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/auto-format.sh"
        }]
      }
    ],
    "Stop": [
      {
        "hooks": [{
          "type": "command",
          "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/stop-verify.sh"
        }]
      }
    ]
  }
}
```

> **Note:** The permissions block (deny list) from earlier versions was removed from
> hooks config. Permissions should be managed in each repo's `.claude/settings.json`
> or via managed policy, as they're organization-specific.

---

## Stack Detection

### `skills/verifier/scripts/detect-stack.sh`

The foundation of the whole plugin. Every other script calls this to know what stack
it's dealing with. Returns one line per detected stack (useful for monorepos); callers
use `| head -1` to get the primary.

```bash
#!/bin/bash
# Outputs one or more of: node-jest, node-vitest, python, java-gradle, java-maven, unknown
# One per line. For primary stack only: pipe through | head -1

STACKS=""

if [ -f "package.json" ]; then
  DEPS=$(cat package.json)
  if echo "$DEPS" | grep -q '"vitest"'; then
    STACKS="${STACKS}node-vitest\n"
  elif echo "$DEPS" | grep -q '"jest"'; then
    STACKS="${STACKS}node-jest\n"
  else
    STACKS="${STACKS}node-jest\n"
  fi
fi

if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "Pipfile" ]; then
  STACKS="${STACKS}python\n"
fi

if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
  STACKS="${STACKS}java-gradle\n"
elif [ -f "pom.xml" ]; then
  STACKS="${STACKS}java-maven\n"
fi

if [ -z "$STACKS" ]; then
  echo "unknown"
else
  echo -e "$STACKS" | grep -v '^$'
fi
```

---

## Hook Scripts

### `scripts/block-dangerous.sh` — PreToolUse safety gate

Patterns are anchored to command boundaries to avoid false positives when commands
contain those words as arguments (e.g., `grep "curl"` or `echo "rm -rf"`).

```bash
#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then exit 0; fi

# Destructive filesystem/DB — anchored to command start
if echo "$COMMAND" | grep -qEi '(^|;|&&|\|\|)\s*(rm\s+-rf|DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE\s+TABLE|FORMAT\s+[A-Z]:|mkfs)'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Destructive command blocked by org policy."}}'
  exit 0
fi

# Network access — standalone curl/wget/etc invocations
if echo "$COMMAND" | grep -qEi '(^|;|&&|\|\|)\s*(curl|wget|nc|ncat|ssh|scp)\s'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Network access blocked. Agents run in isolated environments."}}'
  exit 0
fi

# Secret/credential file reads (cat, less, etc. against secret files)
if echo "$COMMAND" | grep -qEi '(cat|echo|cp|mv|less|more|head|tail|nano|vim)\s.*(\.(env|pem)|credentials|secrets|master\.key|private\.key|api_key)'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Credential/secret access blocked by org policy."}}'
  exit 0
fi

# Database destruction
if echo "$COMMAND" | grep -qEi '(db:drop|db:reset|migrate\s+reset|db\s+push\s+--force|dropDatabase|flush\s+--all)'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Database destruction blocked by org policy."}}'
  exit 0
fi

# Publishing
if echo "$COMMAND" | grep -qEi '(^|;|&&|\|\|)\s*(npm\s+publish|pip\s+upload|twine\s+upload|gradle\s+publish|mvn\s+deploy)\s'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Package publishing blocked. Use CI/CD for releases."}}'
  exit 0
fi

exit 0
```

### `scripts/auto-format.sh` — PostToolUse auto-formatter

```bash
#!/bin/bash
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then exit 0; fi

case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx)
    npx prettier --write "$FILE" 2>/dev/null || true
    npx eslint "$FILE" --fix 2>/dev/null || true
    ;;
  *.py)
    python -m black "$FILE" 2>/dev/null || true
    python -m ruff check "$FILE" --fix 2>/dev/null || true
    ;;
  *.java)
    command -v google-java-format &>/dev/null && google-java-format --replace "$FILE" 2>/dev/null || true
    ;;
  *.kt|*.kts)
    command -v ktlint &>/dev/null && ktlint --format "$FILE" 2>/dev/null || true
    ;;
  *.json|*.css|*.scss|*.md|*.yaml|*.yml)
    npx prettier --write "$FILE" 2>/dev/null || true
    ;;
esac

exit 0
```

### `scripts/stop-verify.sh` — Stop hook verification gate

Delegates to `verify.sh` rather than reimplementing logic. 2-round retry cap.

```bash
#!/bin/bash
INPUT=$(cat)
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

if [ "$STOP_ACTIVE" = "true" ]; then exit 0; fi

RETRY_FILE="/tmp/claude-verify-${CLAUDE_SESSION_ID:-default}"
COUNT=$(cat "$RETRY_FILE" 2>/dev/null || echo 0)

if [ "$COUNT" -ge 2 ]; then
  echo "Verification cap reached (2 rounds). Flagging for human review." >&2
  rm -f "$RETRY_FILE"
  exit 0
fi

CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null)
if [ -z "$CHANGED_FILES" ]; then
  rm -f "$RETRY_FILE"
  exit 0
fi

echo $((COUNT + 1)) > "$RETRY_FILE"

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULT=$(bash "$PLUGIN_DIR/skills/verifier/scripts/verify.sh" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ] || echo "$RESULT" | grep -q "^FAIL"; then
  ERRORS=$(echo "$RESULT" | grep -v "^PASS" | head -10 | tr '\n' ' ')
  echo "{\"decision\":\"block\",\"reason\":\"Verification failed (round $((COUNT + 1))/2): $ERRORS\"}"
else
  rm -f "$RETRY_FILE"
fi

exit 0
```

---

## Verifier Skill

*(See `skills/verifier/SKILL.md` and `skills/verifier/scripts/` for full implementation.)*

The verifier skill is the agent-facing interface for running checks. Agents call it as
a black box — they don't need to know the internals. The skill dispatches to
stack-specific scripts based on `detect-stack.sh`.

---

## Agents (stack-agnostic)

See `agents/` directory. All agents read the repo's CLAUDE.md first and stay within
spec scope. Key agents:

- **reviewer** — scope-check only, not quality review; unwired, reserved for future use if scope creep becomes an issue
- **feature-builder** — single sub-task implementer, runs in isolated worktree

---

## Commands (stack-agnostic)

See `commands/` directory. The full spec → build pipeline:

- **/spec** — generates a grounded spec from a feature request, waits for human approval
- **/build** — executes an approved spec using parallel feature-builder agents
- **/migrate** — runs a pattern-based code migration in batches

---

## Per-Repo Setup

After installing the plugin, each repo still needs its own CLAUDE.md.
This is the one thing that cannot be shared — it describes the specific
project's architecture, conventions, and file layout.

### Bootstrap command

Run this in any repo after installing the plugin to generate a starter CLAUDE.md:

```bash
claude -p "Analyze this project. Read package.json or build files, \
explore src/ structure, look at existing tests, check for linting config. \
Then generate a CLAUDE.md file at the repo root following this template:

# {Project Name}
## Tech Stack
## Architecture (actual folder structure)
## Commands (from package.json scripts / Makefile / build.gradle)
## Coding Standards (inferred from existing code)
## Agent Rules (non-negotiable safety rules)
## Context Loading (which files to read first)
## Specs Location"
```

---

## Rollout Plan

### Week 1: Pilot on 2 repos
1. Push this repo to `your-org/did-claude-plugin` (or rename)
2. Install on 2 repos (ideally different stacks)
3. Generate CLAUDE.md for each via bootstrap command
4. Run 5 features through /spec → /build manually
5. Tune CLAUDE.md based on what you observe

### Week 2: Expand to 5 repos
1. Pick 3 more repos (mix of stacks)
2. Install plugin, generate CLAUDE.md
3. Run features, collect failure patterns
4. Open PRs to this repo to fix hooks/verifiers based on failures

### Week 3+: Roll to all repos
1. Announce plugin to org — share the `extraKnownMarketplaces` snippet
2. Each team: add settings.json snippet + generate CLAUDE.md
3. Platform team maintains this repo
4. Feedback flywheel: analyze sessions → open PRs → improve plugin

### Ongoing maintenance
This repo gets PRs like any other code:
- New verifier scripts for new stacks
- Updated safety hooks as new risks emerge
- Improved agent prompts based on failure analysis
- Version bumps when Claude Code plugin API changes
