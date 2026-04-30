# Forge Foundation (Milestone 1 of 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an installable `forge` plugin in the `mjolnir` marketplace that ports `did-workflow` content under the new brand, runs on GitHub, and auto-applies the statusline.

**Architecture:** This milestone is a **port + rebrand**. Copy the existing `plugins/did-workflow/` tree into `plugins/forge/`, swap every `did-workflow` reference to `forge`, every `glab` call to `gh`, and add two brand-new files (`plugins/forge/settings.json` and `plugins/forge/scripts/statusline.sh`). No behavior changes to skills beyond the rename. All functional upgrades (`/fix`, `/security-review`, `/ship` atomic-commits, multi-choice, new stacks) land in Milestones 2 and 3.

**Tech Stack:** Bash scripts, Markdown skill/agent definitions, JSON manifests (marketplace, plugin, hooks, settings). Validation via `claude plugin validate`.

**Related specs:**

- Design: `docs/superpowers/specs/2026-05-01-forge-plugin-design.md`
- Conventions: `docs/claude-plugin-conventions.md`

**Follow-up milestones (separate plans):**

- **M2 — Functional upgrades:** `/ship` atomic-commits + semver, `/fix` skill, `/security-review` skill, `secret-scan` hook, multi-choice refits (`/discover`, `/prd`, `/grill-me`), `/prd-refine` system-design + threat-model additions
- **M3 — Stack expansion:** Go, Rust, Ruby, Terraform, C#/.NET verifier scripts + `auto-format.sh` extensions

---

## File Structure

Files this milestone will touch:

**Create (new brand):**

- `.claude-plugin/marketplace.json` — **overwrite** existing; rename marketplace `did-claude-plugins` → `mjolnir`, point plugin to `./plugins/forge`
- `plugins/forge/.claude-plugin/plugin.json` — new manifest; name `forge`, version `0.1.0-alpha`
- `plugins/forge/settings.json` — sets `statusLine.command`
- `plugins/forge/scripts/statusline.sh` — two-line statusline script
- `README.md` — **overwrite** existing; forge-branded quickstart + opt-out note for statusline
- `CHANGELOG.md` — **overwrite** existing; reset under `## [0.1.0-alpha]`

**Copy-then-modify (port from did-workflow):**

- `plugins/forge/hooks/hooks.json`
- `plugins/forge/scripts/block-dangerous.sh`
- `plugins/forge/scripts/changelog-guard.sh`
- `plugins/forge/scripts/auto-format.sh`
- `plugins/forge/scripts/stop-verify.sh`
- `plugins/forge/agents/feature-builder.md` — + `gh` swap
- `plugins/forge/agents/reviewer.md`
- `plugins/forge/agents/prd-story-writer.md`
- `plugins/forge/agents/learning-capturer.md`
- `plugins/forge/skills/**` — 13 skill dirs copied wholesale
- `plugins/forge/skills/verifier/scripts/**` — 7 existing verifier scripts

**Delete:**

- `plugins/did-workflow/` — removed after the copy, once validation passes

**Unchanged:**

- `docs/` (except `docs/superpowers/plans/` which gains this file)

---

## Task 0: Prepare clean working branch

**Files:**

- Repo root

- [ ] **Step 0.1: Verify we're on main and clean-ish**

Run:

```bash
cd /Users/gpdzaf/Documents/claude-plugin
git status
git branch --show-current
```

Expected: branch `main`; working tree has only untracked `.DS_Store`, untracked deletion of `did-claude-plugin.zip`, and the committed spec + plan files from brainstorming. No other staged changes.

- [ ] **Step 0.2: Create a feature branch for this milestone**

Run:

```bash
git checkout -b feature/forge-foundation
```

Expected: `Switched to a new branch 'feature/forge-foundation'`.

- [ ] **Step 0.3: Remove the stale zip artifact**

Run:

```bash
git rm did-claude-plugin.zip 2>/dev/null || true
git status
```

Expected: the zip is marked for deletion (or already absent from the index).

- [ ] **Step 0.4: Commit the cleanup**

Run:

```bash
git commit -m "chore: drop stale did-claude-plugin.zip"
```

Expected: one commit created. If nothing to commit, skip.

---

## Task 1: Rename marketplace to `mjolnir`

**Files:**

- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1.1: Rewrite `.claude-plugin/marketplace.json`**

Overwrite the file with this exact content:

```json
{
  "name": "mjolnir",
  "owner": {
    "name": "Dzafran"
  },
  "metadata": {
    "description": "Mjolnir marketplace — forge and future Claude Code tooling by Dzafran",
    "version": "0.1.0-alpha"
  },
  "plugins": [
    {
      "name": "forge",
      "source": "./plugins/forge",
      "description": "GitHub-first, spec-driven, design-conscious, security-aware Claude Code workflow with multi-choice prompts and atomic commits.",
      "version": "0.1.0-alpha",
      "author": {
        "name": "Dzafran"
      }
    }
  ]
}
```

- [ ] **Step 1.2: Validate the marketplace JSON syntax**

Run:

```bash
python3 -c "import json; json.load(open('.claude-plugin/marketplace.json'))" && echo OK
```

Expected: prints `OK`.

- [ ] **Step 1.3: Commit**

Run:

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat(marketplace): rename to mjolnir, point to forge plugin"
```

---

## Task 2: Create `plugins/forge/` by copying `plugins/did-workflow/`

**Files:**

- Create: `plugins/forge/**` (mirror of `plugins/did-workflow/`)

- [ ] **Step 2.1: Copy the entire plugin tree**

Run:

```bash
cp -R plugins/did-workflow plugins/forge
```

- [ ] **Step 2.2: Verify the copy is complete**

Run:

```bash
diff -r plugins/did-workflow plugins/forge && echo IDENTICAL
```

Expected: prints `IDENTICAL`.

- [ ] **Step 2.3: List the new top-level plugin contents for reference**

Run:

```bash
ls plugins/forge/
ls plugins/forge/.claude-plugin/
ls plugins/forge/skills/ | wc -l
```

Expected: top-level has `.claude-plugin`, `agents`, `hooks`, `scripts`, `skills`. `.claude-plugin` contains `plugin.json`. `skills/` line count is 15 (matches the existing did-workflow skills count including workspace dirs).

- [ ] **Step 2.4: Stage the copy (do NOT commit yet — next tasks modify these files)**

Run:

```bash
git add plugins/forge
git status | head -5
```

Expected: `plugins/forge/...` files appear as new files staged.

---

## Task 3: Rewrite `plugins/forge/.claude-plugin/plugin.json`

**Files:**

- Modify: `plugins/forge/.claude-plugin/plugin.json`

- [ ] **Step 3.1: Overwrite `plugin.json` with forge manifest**

Replace the file's entire contents with:

```json
{
  "name": "forge",
  "version": "0.1.0-alpha",
  "description": "GitHub-first, spec-driven, design-conscious, security-aware Claude Code workflow with multi-choice prompts and atomic commits.",
  "author": {
    "name": "Dzafran"
  },
  "agents": [
    "./agents/reviewer.md",
    "./agents/feature-builder.md",
    "./agents/prd-story-writer.md",
    "./agents/learning-capturer.md"
  ],
  "skills": [
    "./skills/verifier",
    "./skills/prd",
    "./skills/prd-refine",
    "./skills/build",
    "./skills/doc-architect",
    "./skills/tdd",
    "./skills/grill-me",
    "./skills/e2e",
    "./skills/e2e-create",
    "./skills/ship",
    "./skills/product-discovery",
    "./skills/poc",
    "./skills/learn"
  ]
}
```

Note: `hooks/hooks.json` is auto-loaded — do NOT list it in a `hooks` field (would cause duplicate-hooks error per `docs/claude-plugin-conventions.md` line 116).

- [ ] **Step 3.2: Validate JSON syntax**

Run:

```bash
python3 -c "import json; json.load(open('plugins/forge/.claude-plugin/plugin.json'))" && echo OK
```

Expected: prints `OK`.

---

## Task 4: Global rebrand `did-workflow` → `forge` inside `plugins/forge/`

**Files:**

- Modify: every file under `plugins/forge/` that mentions `did-workflow` or `did-claude-plugin`

- [ ] **Step 4.1: List files that reference the old names (for awareness)**

Run:

```bash
grep -rl "did-workflow\|did-claude-plugin" plugins/forge/ 2>/dev/null | head -40
```

Expected: a list of markdown and possibly shell files. Note the count.

- [ ] **Step 4.2: Replace `did-workflow` → `forge` across the tree**

Run (macOS `sed -i ''` syntax):

```bash
grep -rl "did-workflow" plugins/forge/ 2>/dev/null | while read -r f; do
  sed -i '' 's/did-workflow/forge/g' "$f"
done
```

- [ ] **Step 4.3: Replace `did-claude-plugin` → `mjolnir` across the tree (marketplace references in docs/examples inside skills)**

Run:

```bash
grep -rl "did-claude-plugin" plugins/forge/ 2>/dev/null | while read -r f; do
  sed -i '' 's/did-claude-plugin/mjolnir/g' "$f"
done
```

- [ ] **Step 4.4: Verify no stale references remain**

Run:

```bash
grep -rn "did-workflow\|did-claude-plugin" plugins/forge/ 2>/dev/null
```

Expected: no output (grep exits non-zero when nothing matches — that's the success signal here).

- [ ] **Step 4.5: Commit the rebrand**

Run:

```bash
git add plugins/forge
git commit -m "feat(forge): port plugin tree from did-workflow under forge brand"
```

Expected: large commit covering all ported files.

---

## Task 5: Swap `glab` → `gh` inside `plugins/forge/`

**Files:**

- Modify: any file under `plugins/forge/` that invokes the GitLab CLI

- [ ] **Step 5.1: Locate `glab` references**

Run:

```bash
grep -rn "glab " plugins/forge/ 2>/dev/null
grep -rn "gitlab.com" plugins/forge/ 2>/dev/null
grep -rn "merge request\|MR \|mr " plugins/forge/ 2>/dev/null | head -30
```

Expected: a list of occurrences in skill SKILL.md files (primarily `ship`, `build`, `learning-capturer` agent). Record the set.

- [ ] **Step 5.2: Replace `glab` command invocations with `gh`**

Most `glab` commands have a `gh` twin. Apply these blanket substitutions:

```bash
grep -rl "glab " plugins/forge/ 2>/dev/null | while read -r f; do
  sed -i '' \
    -e 's/glab mr create/gh pr create/g' \
    -e 's/glab mr view/gh pr view/g' \
    -e 's/glab mr list/gh pr list/g' \
    -e 's/glab mr merge/gh pr merge/g' \
    -e 's/glab mr close/gh pr close/g' \
    -e 's/glab mr comment/gh pr comment/g' \
    -e 's/glab mr diff/gh pr diff/g' \
    -e 's/glab issue create/gh issue create/g' \
    -e 's/glab issue view/gh issue view/g' \
    -e 's/glab api/gh api/g' \
    -e 's/glab auth/gh auth/g' \
    -e 's/glab repo/gh repo/g' \
    -e 's/glab /gh /g' \
    "$f"
done
```

- [ ] **Step 5.3: Replace terminology in prose (`merge request`/`MR` → `pull request`/`PR`)**

This is prose-level wording inside SKILL.md files. Be surgical — only where the word refers to the GitLab-specific concept, not the generic "merge" verb. Use the following grep to inspect and hand-edit:

```bash
grep -rn "merge request\|\bMR\b" plugins/forge/ 2>/dev/null
```

For each match:

- If the prose discusses the hosted review artifact, change `merge request` → `pull request`, `MR` → `PR`.
- If the word is part of a generic sentence ("after the merge completes"), leave it alone.

Apply the edits manually via the Edit tool, one occurrence at a time. Do NOT use a blanket sed here — false positives are likely.

- [ ] **Step 5.4: Replace `gitlab.com` references with a neutral GitHub equivalent or remove them**

Run:

```bash
grep -rn "gitlab.com" plugins/forge/ 2>/dev/null
```

For each hit, edit manually: either replace with `github.com/<user>/<repo>` placeholder or remove the URL if it referred to the plugin repo. Do NOT invent real GitHub repo URLs.

- [ ] **Step 5.5: Verify no stale GitLab references remain**

Run:

```bash
grep -rn "glab " plugins/forge/ 2>/dev/null
grep -rn "gitlab.com" plugins/forge/ 2>/dev/null
```

Expected: no output from both.

- [ ] **Step 5.6: Commit the GitLab → GitHub swap**

Run:

```bash
git add plugins/forge
git commit -m "refactor(forge): swap glab for gh across ship/build/learning-capturer"
```

---

## Task 6: Add the statusline script

**Files:**

- Create: `plugins/forge/scripts/statusline.sh`

- [ ] **Step 6.1: Write `plugins/forge/scripts/statusline.sh`**

Create the file with these exact contents (per the existing `statusline` prompt at repo root):

```bash
#!/bin/bash
# forge statusline — two-line status bar for Claude Code.
# Line 1: <model> | <tokens> | <cost> | ctx:[bar] <%>
# Line 2: <cwd with ~> (<git branch>)
#
# Colors (ANSI):
#   cyan bold  = model
#   yellow     = tokens
#   green      = cost
#   ctx bar/pct: green <40%, orange 40-60%, red >=60%
#   blue       = cwd
#   yellow bold= branch
#   dim        = separators and empty bar cells

set -eu

INPUT=$(cat)

# --- extract fields ---
MODEL=$(printf '%s' "$INPUT" | jq -r '.model.display_name // "claude"')
IN_TOKENS=$(printf '%s' "$INPUT" | jq -r '.context_window.total_input_tokens // 0')
OUT_TOKENS=$(printf '%s' "$INPUT" | jq -r '.context_window.total_output_tokens // 0')
COST=$(printf '%s' "$INPUT" | jq -r '.cost.total_cost_usd // 0')
PCT=$(printf '%s' "$INPUT" | jq -r '.context_window.used_percentage // empty')
CWD=$(printf '%s' "$INPUT" | jq -r '.workspace.current_dir // empty')

TOTAL=$((IN_TOKENS + OUT_TOKENS))

# --- format tokens: 12.3k / 1.2M / raw ---
if [ "$TOTAL" -ge 1000000 ]; then
  TOK=$(awk -v t="$TOTAL" 'BEGIN{ printf "%.1fM", t/1000000 }')
elif [ "$TOTAL" -ge 1000 ]; then
  TOK=$(awk -v t="$TOTAL" 'BEGIN{ printf "%.1fk", t/1000 }')
else
  TOK="$TOTAL"
fi

# --- format cost: $0.0000 ---
COST_FMT=$(awk -v c="$COST" 'BEGIN{ printf "$%.4f", c }')

# --- ANSI helpers ---
RESET=$'\033[0m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'
GREEN=$'\033[32m'
RED=$'\033[31m'
ORANGE=$'\033[38;5;208m'
BLUE=$'\033[34m'

# --- context bar ---
CTX_SECTION=""
if [ -n "$PCT" ] && [ "$PCT" != "null" ]; then
  PCT_INT=$(awk -v p="$PCT" 'BEGIN{ printf "%d", p }')
  if [ "$PCT_INT" -lt 40 ]; then
    CTX_COLOR="$GREEN"
  elif [ "$PCT_INT" -lt 60 ]; then
    CTX_COLOR="$ORANGE"
  else
    CTX_COLOR="$RED"
  fi
  FILLED=$(awk -v p="$PCT_INT" 'BEGIN{ printf "%d", (p/10)+0.0001 }')
  [ "$FILLED" -gt 10 ] && FILLED=10
  [ "$FILLED" -lt 0 ] && FILLED=0
  EMPTY=$((10 - FILLED))
  BAR=""
  i=0
  while [ "$i" -lt "$FILLED" ]; do BAR="${BAR}#"; i=$((i+1)); done
  DOTS=""
  i=0
  while [ "$i" -lt "$EMPTY" ]; do DOTS="${DOTS}."; i=$((i+1)); done
  CTX_SECTION=" ${DIM}|${RESET} ${CTX_COLOR}ctx:[${BAR}${DIM}${DOTS}${RESET}${CTX_COLOR}] ${PCT_INT}%${RESET}"
fi

LINE1="${BOLD}${CYAN}${MODEL}${RESET} ${DIM}|${RESET} ${YELLOW}${TOK}${RESET} ${DIM}|${RESET} ${GREEN}${COST_FMT}${RESET}${CTX_SECTION}"

# --- line 2: cwd + branch ---
CWD_DISPLAY="$CWD"
if [ -n "$CWD" ]; then
  case "$CWD" in
    "$HOME"*) CWD_DISPLAY="~${CWD#$HOME}" ;;
  esac
fi

BRANCH=""
if [ -n "$CWD" ]; then
  BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null || true)
fi

if [ -n "$BRANCH" ]; then
  LINE2="${BLUE}${CWD_DISPLAY}${RESET} ${DIM}(${RESET}${BOLD}${YELLOW}${BRANCH}${RESET}${DIM})${RESET}"
else
  LINE2="${BLUE}${CWD_DISPLAY}${RESET}"
fi

printf '%b\n%b\n' "$LINE1" "$LINE2"
```

- [ ] **Step 6.2: Make the script executable**

Run:

```bash
chmod +x plugins/forge/scripts/statusline.sh
ls -l plugins/forge/scripts/statusline.sh
```

Expected: permissions show `-rwxr-xr-x`.

- [ ] **Step 6.3: Smoke-test the statusline with fake input**

Run:

```bash
cat <<'EOF' | plugins/forge/scripts/statusline.sh
{
  "model": {"display_name": "claude-opus-4.7"},
  "context_window": {"total_input_tokens": 12345, "total_output_tokens": 678, "used_percentage": 35},
  "cost": {"total_cost_usd": 0.1234},
  "workspace": {"current_dir": "/tmp"}
}
EOF
```

Expected: two lines printed; first line contains the model name, `13.0k`, `$0.1234`, and a green bar with `35%`; second line shows `/tmp` in blue with no `()` (git branch empty).

- [ ] **Step 6.4: Smoke-test with no percentage (bar section omitted)**

Run:

```bash
cat <<'EOF' | plugins/forge/scripts/statusline.sh
{
  "model": {"display_name": "claude"},
  "context_window": {"total_input_tokens": 0, "total_output_tokens": 0},
  "cost": {"total_cost_usd": 0},
  "workspace": {"current_dir": "/tmp"}
}
EOF
```

Expected: first line ends after `$0.0000` (no `ctx:[...]` section); second line shows `/tmp`.

- [ ] **Step 6.5: Commit**

Run:

```bash
git add plugins/forge/scripts/statusline.sh
git commit -m "feat(forge): add two-line statusline script"
```

---

## Task 7: Wire the statusline into `plugins/forge/settings.json`

**Files:**

- Create: `plugins/forge/settings.json`

- [ ] **Step 7.1: Write `plugins/forge/settings.json`**

Create the file with these exact contents:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh"
  }
}
```

- [ ] **Step 7.2: Validate JSON**

Run:

```bash
python3 -c "import json; json.load(open('plugins/forge/settings.json'))" && echo OK
```

Expected: prints `OK`.

- [ ] **Step 7.3: Commit**

Run:

```bash
git add plugins/forge/settings.json
git commit -m "feat(forge): auto-apply statusline via plugin settings.json"
```

---

## Task 8: Rewrite top-level `README.md` for forge

**Files:**

- Modify: `README.md` (at repo root — overwrite existing)

- [ ] **Step 8.1: Overwrite `README.md`**

Replace the file's entire contents with:

````markdown
# Forge — a Claude Code workflow plugin

Installed from the **mjolnir** marketplace. Forge delivers a spec-driven, test-disciplined coding workflow with system-design consciousness and security awareness baked in.

## What's in v0.1-alpha

Milestone 1 ships a working port of the did-workflow pipeline under the forge brand, on GitHub (via `gh`), with a built-in statusline. Functional upgrades (`/fix`, `/security-review`, atomic-commit `/ship`, multi-choice prompts, new stacks) land in later milestones.

- Skills: `/forge:discover`, `/forge:poc`, `/forge:prd`, `/forge:prd-refine`, `/forge:grill-me`, `/forge:build`, `/forge:tdd`, `/forge:e2e-create`, `/forge:e2e`, `/forge:verifier`, `/forge:ship`, `/forge:doc-architect`, `/forge:learn`
- Agents: `feature-builder`, `reviewer`, `prd-story-writer`, `learning-capturer`
- Hooks: `block-dangerous`, `changelog-guard`, `auto-format`, `stop-verify`
- Statusline: model · tokens · cost · context bar · cwd + git branch

## Prerequisites

- Claude Code installed and authenticated
- `gh` (GitHub CLI) installed and authenticated (`gh auth status` should report OK)
- Git

## Install

From inside Claude Code:

```
/plugin
```

Navigate to **Marketplace → Add marketplace** and paste this repo's clone URL. Then install `forge@mjolnir`.

Restart Claude Code after install so the statusline applies.

## Disabling the statusline

The plugin sets `statusLine.command` in its own `settings.json`. To override it with your own statusline (or restore the default), add your preferred command to your user `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /path/to/your/own/statusline.sh"
  }
}
```

User settings override plugin settings.

## Workflow (M1 scope)

Follows the same pipeline as did-workflow; the in-flight upgrades to `/ship`, `/fix`, `/security-review`, and interactive skills arrive in M2 and M3 (see `docs/superpowers/specs/2026-05-01-forge-plugin-design.md`).

## Contributing

PRs welcome. See `docs/claude-plugin-conventions.md` and the design spec at `docs/superpowers/specs/2026-05-01-forge-plugin-design.md`.
````

- [ ] **Step 8.2: Commit**

Run:

```bash
git add README.md
git commit -m "docs: rewrite README for forge v0.1-alpha"
```

---

## Task 9: Reset root `CHANGELOG.md` for forge

**Files:**

- Modify: `CHANGELOG.md` (at repo root — overwrite existing)

- [ ] **Step 9.1: Overwrite `CHANGELOG.md`**

Replace contents with:

```markdown
# Changelog

All notable changes to the forge plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [0.1.0-alpha] - 2026-05-01

### Added

- Initial forge plugin under the mjolnir marketplace
- Ported skills, agents, hooks, scripts, and verifier from did-workflow under the forge brand
- GitHub-native command set (`gh` replaces `glab` in ship, build, learning-capturer, and related skills)
- Two-line statusline (`scripts/statusline.sh`) auto-applied via plugin `settings.json`

### Notes

- v0.1-alpha is a foundation release. Functional upgrades (atomic-commit `/ship`, `/fix`, `/security-review`, multi-choice prompts, broader stack coverage) land in subsequent milestones per `docs/superpowers/specs/2026-05-01-forge-plugin-design.md`.
```

- [ ] **Step 9.2: Commit**

Run:

```bash
git add CHANGELOG.md
git commit -m "docs: reset CHANGELOG for forge 0.1.0-alpha"
```

---

## Task 10: Validate the plugin and marketplace

**Files:**

- Read-only: `.claude-plugin/marketplace.json`, `plugins/forge/**`

- [ ] **Step 10.1: Run Claude Code's plugin validator**

Run:

```bash
claude plugin validate .
```

Expected: reports the `mjolnir` marketplace and the `forge` plugin with no errors. If errors appear:

- `Duplicate plugin name` → ensure Task 11 has not yet removed `plugins/did-workflow`; validator sees both. This is expected at this step. Continue.
- `YAML frontmatter failed to parse` in any skill → open the skill and fix syntax.
- `Invalid JSON` → re-run the JSON validate commands from Tasks 1, 3, 7.

- [ ] **Step 10.2: Confirm the validator finds both plugins (pre-cleanup)**

The output should list two plugins: `did-workflow` and `forge`. This is expected at this point — Task 11 will remove did-workflow.

- [ ] **Step 10.3: (No commit — this task is read-only validation)**

---

## Task 11: Remove the legacy `plugins/did-workflow/` directory

**Files:**

- Delete: `plugins/did-workflow/` (entire subtree)

- [ ] **Step 11.1: Sanity-check forge is complete before deleting did-workflow**

Run:

```bash
diff -r plugins/did-workflow plugins/forge | head -30
```

Expected: differences are limited to the rebrand edits (name/version/path strings). No "Only in plugins/did-workflow" lines reporting missing files in forge. If there are, investigate before deleting.

- [ ] **Step 11.2: Delete the legacy plugin**

Run:

```bash
git rm -r plugins/did-workflow
```

- [ ] **Step 11.3: Verify marketplace.json still only references forge**

Run:

```bash
grep -n "did-workflow\|forge" .claude-plugin/marketplace.json
```

Expected: only `forge` appears.

- [ ] **Step 11.4: Re-run validator — should now report only forge**

Run:

```bash
claude plugin validate .
```

Expected: one plugin (`forge`) reported; no errors.

- [ ] **Step 11.5: Commit the removal**

Run:

```bash
git commit -m "chore: remove legacy plugins/did-workflow after forge port"
```

---

## Task 12: Smoke-test the forge plugin locally

**Files:**

- Read-only

- [ ] **Step 12.1: Install the local marketplace into Claude Code**

From inside Claude Code (new session):

```
/plugin
```

Steps:

1. Marketplace → Add marketplace
2. Paste the absolute path of this repo: `/Users/gpdzaf/Documents/claude-plugin`
3. Press enter

Expected: marketplace `mjolnir` installs; `forge` appears in the plugin list.

- [ ] **Step 12.2: Install forge**

Inside `/plugin`:

1. Install `forge@mjolnir`
2. Enable the plugin

Expected: install completes without errors.

- [ ] **Step 12.3: Restart Claude Code**

Exit and relaunch:

```bash
exit
claude
```

Expected: the forge two-line statusline appears at the bottom (model · tokens · cost · cwd · branch).

- [ ] **Step 12.4: Confirm the slash commands are available**

Type `/forge:` inside Claude Code.

Expected: autocomplete shows the 13 forge skills (`/forge:build`, `/forge:discover`, `/forge:doc-architect`, `/forge:e2e`, `/forge:e2e-create`, `/forge:grill-me`, `/forge:learn`, `/forge:poc`, `/forge:prd`, `/forge:prd-refine`, `/forge:ship`, `/forge:tdd`, `/forge:verifier`).

- [ ] **Step 12.5: Confirm the statusline can be disabled**

Open `~/.claude/settings.json` and add:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash -c 'echo override'"
  }
}
```

Restart Claude Code. Expected: statusline shows the word `override` instead of the forge two-liner. Remove the override after confirming.

- [ ] **Step 12.6: (No commit — this task is smoke test only)**

---

## Task 13: Final commit of any remaining cleanup and open PR

**Files:**

- Any residual files

- [ ] **Step 13.1: Check git status for anything uncommitted**

Run:

```bash
git status
```

Expected: clean working tree (or only untracked `.DS_Store` / local-only files).

- [ ] **Step 13.2: Add `.gitignore` entry for `.DS_Store` if not already present**

Run:

```bash
grep -q '^\.DS_Store$' .gitignore || echo '.DS_Store' >> .gitignore
git diff .gitignore
```

If `.gitignore` changed:

```bash
git add .gitignore
git commit -m "chore: ignore macOS .DS_Store"
```

- [ ] **Step 13.3: Push the branch**

Run:

```bash
git push -u origin feature/forge-foundation
```

Expected: push succeeds. If the remote does not exist yet, stop and ask the user to set up the GitHub repo first.

- [ ] **Step 13.4: Open the PR via `gh`**

Run:

```bash
gh pr create --title "feat(forge): v0.1-alpha foundation (port from did-workflow)" --body "$(cat <<'EOF'
## Summary

- Renamed marketplace `did-claude-plugins` → `mjolnir`
- Ported `plugins/did-workflow/` → `plugins/forge/`; version `0.1.0-alpha`
- Swapped all `glab` calls for `gh`; updated MR/merge-request prose to PR/pull-request where appropriate
- Added auto-applied two-line statusline (`plugins/forge/scripts/statusline.sh` + `settings.json`)
- Replaced root `README.md` and `CHANGELOG.md` under the forge brand
- Removed legacy `plugins/did-workflow/` after validation

## Test plan

- [ ] `claude plugin validate .` reports only `forge` with no errors
- [ ] `/plugin` install succeeds against this repo's local path
- [ ] Statusline renders after restart; shows model, tokens, cost, context bar, cwd, branch
- [ ] Statusline override in `~/.claude/settings.json` replaces the forge version
- [ ] `/forge:` autocomplete lists all 13 skills
- [ ] Smoke-run one skill end-to-end (e.g., `/forge:learn` audit mode) to confirm shell scripts resolve paths correctly

## Follow-ups (separate PRs / plans)

- M2 — atomic-commit `/ship` + semver + `/fix` + `/security-review` + multi-choice refits + `secret-scan` hook + `/prd-refine` design/threat-model additions
- M3 — Go / Rust / Ruby / Terraform / C#/.NET verifier scripts + `auto-format.sh` extensions
EOF
)"
```

Expected: PR URL printed.

- [ ] **Step 13.5: Return the PR URL to the user**

---

## Definition of Done (M1)

- ✅ Marketplace is `mjolnir`; plugin is `forge@mjolnir`, version `0.1.0-alpha`
- ✅ `claude plugin validate .` passes with zero errors
- ✅ `/plugin` install from the local path succeeds
- ✅ All 13 forge skills listed under `/forge:` autocomplete
- ✅ Statusline renders after install; user override in `~/.claude/settings.json` works
- ✅ No `glab` or `gitlab.com` references remain under `plugins/forge/`
- ✅ Legacy `plugins/did-workflow/` deleted
- ✅ PR opened on GitHub

---

## What's NOT in this plan (deferred to M2 and M3)

M2 (write a new plan later):

- `/forge:fix` skill (new)
- `/forge:security-review` skill (new)
- `/forge:ship` atomic-commit + semver + no-co-author upgrade
- `secret-scan` PreToolUse hook (new script + hook wiring)
- Multi-choice prompt refits across `/forge:discover`, `/forge:prd`, `/forge:grill-me`, `/forge:fix`
- `/forge:prd-refine` system-design section + threat-model checklist additions

M3 (write a new plan later):

- Verifier stack additions: Go, Rust, Ruby, Terraform, C#/.NET
- `auto-format.sh` additions for those stacks
- `detect-stack.sh` additions for those stacks
