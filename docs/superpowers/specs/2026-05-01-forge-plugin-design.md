---
title: Forge — GitHub-first, design-conscious, security-aware Claude Code workflow plugin
status: approved
date: 2026-05-01
owner: Dzafran
marketplace: mjolnir
plugin: forge
---

# Forge Plugin — Design

## 1. Summary

**Forge** is a Claude Code plugin that delivers a spec-driven, test-disciplined coding workflow with system-design consciousness and security awareness baked in. It is installed from the **`mjolnir`** marketplace.

Forge is inspired by — but does not copy — the `did-workflow` plugin. It keeps the philosophy (spec before code, tests before claims, per-repo learnings) and improves on it with:

- **Multi-choice prompt UX** across interactive skills
- **Dedicated `/fix` fast-path** for bug work
- **System-design philosophy** woven into `/prd-refine` and `/build`
- **Auto-invoked `/security-review` gate** before every `/ship`
- **`/ship` upgrade**: atomic conventional commits + automatic semver bumps + CHANGELOG update + **no `Co-Authored-By` trailer**
- **GitHub-native** (`gh` CLI) with a thin adapter so GitLab/Gitea swap is a config change
- **Broader stack coverage**: Node, Python, Java, Go, Rust, Ruby, Terraform, C#/.NET
- **Auto-applied statusline** (model · tokens · cost · context bar; documented opt-out)

Users type: `/forge:discover`, `/forge:prd`, `/forge:build`, `/forge:fix`, `/forge:ship`, etc.

## 2. Guiding philosophies

These are the plugin's DNA. Every skill is designed against this list.

1. **Spec before code** — `/prd` + `/prd-refine` required before `/build`.
2. **Tests before claims** — no skill reports "done" without evidence (types, lint, tests pass). Stronger than mandated TDD; enforced by `stop-verify` hook.
3. **System-design consciousness** — `/prd-refine` adds a system-design section (components, interfaces, data flow, tradeoffs). `/build` surfaces design tradeoffs during task decomposition. An ADR is produced when a real tradeoff was made.
4. **Security-aware by default** — threat-model checklist in `/prd-refine`, auto-invoked `/security-review` before `/ship`, `secret-scan` PreToolUse hook on commits.
5. **Multi-choice first** — every interactive question offers numbered options with a recommended choice. Free-text only when options are genuinely wrong (e.g., "name your feature"). Multi-select allowed per-question.
6. **Learnings travel with code** — per-repo `docs/learnings/` captured at end of `/build` and optionally `/ship`.
7. **Atomic, semantic, semver-correct commits** — enforced by `/ship`; strict conventional-commit format (`feat:`, `fix:`, etc.); no `Co-Authored-By`.
8. **GitHub-native, vendor-neutral underneath** — all hosting calls go through a thin git-host adapter; `gh` is the v0.1 default.

## 3. Scope — v0.1

### In scope

| #   | Feature                                                                                |
| --- | -------------------------------------------------------------------------------------- |
| 1   | GitHub migration: all `glab` → `gh` across ship, build, learning-capturer              |
| 2   | Multi-choice prompt UX across `/discover`, `/prd`, `/grill-me`, `/fix`                 |
| 3   | `/fix` — dedicated bug-fix pipeline, root-cause-first                                  |
| 4   | System-design philosophy woven into `/prd-refine` and `/build`                         |
| 5   | `/ship` upgrade — atomic conventional commits + auto semver + CHANGELOG + no co-author |
| 6   | `/security-review` skill + `secret-scan` hook + threat-model section in `/prd-refine`  |
| 7   | Broader stack coverage: add Go, Rust, Ruby, Terraform, C#/.NET (10 stacks total)       |
| 8   | Statusline auto-apply via plugin `settings.json` + documented opt-out                  |

### Out of scope (deferred)

- Jira integration (did-workflow has it; skip for v0.1)
- MCP servers
- Evals harness
- Additional stacks: Kotlin, Swift, PHP, Elixir, Scala, Clojure, Haskell, Zig, Dart/Flutter

## 4. End-to-end workflow

Three entry paths, all converging at the security gate → ship exit.

### Feature path (full pipeline)

```
/forge:discover  →  /forge:poc (optional)
       ↓
/forge:prd  →  grill-me gate  →  spec.md (business only)
       ↓
/forge:prd-refine
   · API + data model
   · system-design section
   · threat-model checklist
   · E2E test table
       ↓
/forge:build
   · task decomposition
   · parallel feature-builder agents (worktree isolated)
       ├── /forge:tdd (red-green-refactor)
       ├── /forge:e2e-create → /forge:e2e
       └── /forge:verifier (format · lint · types · tests)
   · merge to feature branch
       ↓
/forge:security-review  (auto-invoked by /forge:ship)
   · PASS  → continue
   · WARN  → user confirms/fixes
   · FAIL  → back to /forge:build
       ↓
/forge:ship
   · atomic conventional commits
   · auto semver bump
   · CHANGELOG update
   · gh pr create
       ↓
/forge:doc-architect  +  learning-capturer agent → /forge:learn
```

### Bug-fix fast path

```
/forge:fix
   1. Capture bug (multi-choice input)
   2. Write failing test that reproduces bug
   3. Investigate root cause (always — no shortcut)
   4. Minimal patch
   5. /forge:verifier
        ↓
/forge:security-review → /forge:ship
```

### Manual coding path

```
Manual edits  →  /forge:ship  →  /forge:security-review runs as step 0
```

## 5. Skill catalogue

| #   | Skill / Agent               | Trigger                                  | Phase         | Status                                           |
| --- | --------------------------- | ---------------------------------------- | ------------- | ------------------------------------------------ |
| 1   | `product-discovery`         | `/forge:discover`                        | Discovery     | kept + multi-choice                              |
| 2   | `poc`                       | `/forge:poc <name>`                      | Discovery     | kept                                             |
| 3   | `prd`                       | `/forge:prd <name>`                      | Spec          | kept + multi-choice                              |
| 4   | `prd-story-writer` (agent)  | auto from `/prd` (epics)                 | Spec          | kept                                             |
| 5   | `grill-me`                  | `/forge:grill-me` + inside `/prd`        | Spec          | kept + multi-choice                              |
| 6   | `prd-refine`                | `/forge:prd-refine <name>`               | Spec          | kept + system-design + threat-model              |
| 7   | `build`                     | `/forge:build <name>`                    | Build         | kept + `gh` swap                                 |
| 8   | `feature-builder` (agent)   | auto from `/build`                       | Build         | kept + `gh` swap                                 |
| 9   | `tdd`                       | auto + `/forge:tdd`                      | Build         | kept                                             |
| 10  | `e2e-create`                | auto + `/forge:e2e-create`               | Build         | kept                                             |
| 11  | `e2e`                       | auto + `/forge:e2e`                      | Build         | kept                                             |
| 12  | `verifier`                  | auto + `/forge:verifier`                 | Build         | kept + 5 new stacks                              |
| 13  | `reviewer` (agent)          | wired by `/build`                        | Build         | kept                                             |
| 14  | **`security-review`**       | `/forge:security-review` + auto pre-ship | Security gate | **NEW**                                          |
| 15  | **`fix`**                   | `/forge:fix`                             | Bug-fix       | **NEW**                                          |
| 16  | `ship`                      | `/forge:ship`                            | Ship          | upgraded (atomic + semver + no co-author + `gh`) |
| 17  | `doc-architect`             | `/forge:doc-architect` + auto post-merge | Post          | kept                                             |
| 18  | `learn`                     | `/forge:learn` + via capturer            | Post          | kept                                             |
| 19  | `learning-capturer` (agent) | auto post-build + post-ship              | Post          | kept                                             |

## 6. Hooks

| Hook              | When                               | What it does                                                                                            | Status            |
| ----------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------- | ----------------- |
| `block-dangerous` | PreToolUse · Bash                  | Blocks `rm -rf`, credential reads, `npm publish`, etc.                                                  | ported            |
| `changelog-guard` | PreToolUse · Bash                  | Blocks `git commit` when CHANGELOG.md exists but not staged                                             | ported            |
| **`secret-scan`** | PreToolUse · Bash (`git commit`)   | Greps staged diff for API keys / private keys / tokens / GitHub PATs. Allowlist via `.secretscanignore` | **NEW**           |
| `auto-format`     | PostToolUse · Write/Edit/MultiEdit | Formats on save. Adds `gofmt`, `rustfmt`, `rubocop -a`, `terraform fmt`, `dotnet format`                | ported + extended |
| `stop-verify`     | Stop                               | Runs verifier before agent exits                                                                        | ported            |

## 7. New skills — detailed design

### 7.1 `/forge:fix` (NEW)

**Purpose:** Go from "I see a bug" to "PR open" without PRD ceremony, while enforcing reproduce-first discipline.

**Flow:**

1. **Capture bug** — multi-choice input:

   ```
   How do you want to describe the bug?
     1. Paste stack trace / error output
     2. Describe reproduction steps
     3. Link a GitHub issue (I'll fetch it via `gh`)
     4. Explain in my own words

   Recommended: 1
   ```

2. **Reproduce** — Claude writes a failing test that captures the bug. Asks user:

   ```
   Does this failing test reproduce the bug?
     1. Yes — proceed
     2. No — let me correct the repro
     3. Show me the test again
   ```

3. **Investigate root cause** — always. No shortcut. Claude surfaces hypothesis + supporting code references and gets user confirmation before patching.

4. **Minimal patch** — smallest change that makes the failing test pass. No adjacent cleanup.

5. **`/forge:verifier`** — format + lint + types + tests must pass.

6. **Auto-invoke `/forge:security-review`** → if PASS/WARN-accepted, hand off to `/forge:ship`.

**Outputs:** Two atomic commits — one with the failing test (`test(<scope>): reproduce <bug>`), one with the fix (`fix(<scope>): <what>`). Bisect-friendly.

**Why this shape:** Reproduce-first is the strongest discipline for bug work. Multi-choice input removes friction for the user.

### 7.2 `/forge:security-review` (NEW)

**Purpose:** Block risky diffs before they leave the machine.

**Checks against the diff:**

| Category         | What it looks for                                                                                                                                |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Injection        | SQL string concatenation, `exec`/`eval` with user input, shell injection via template strings                                                    |
| Authn/Authz      | New routes without auth decorators/middleware (stack-aware), role checks missing                                                                 |
| Secrets          | API keys, private keys, `.env` values, tokens in source                                                                                          |
| Crypto           | `md5`/`sha1` used for security, hardcoded IVs, `Math.random()` for tokens                                                                        |
| Dependencies     | CVE scan via `gh` Dependabot alerts, `npm audit`, `pip-audit`, `govulncheck`, `cargo audit`, `bundler-audit`, `dotnet list package --vulnerable` |
| Input validation | Missing validation on request bodies, deserialization of untrusted data                                                                          |
| Logging          | PII / tokens appearing in log lines                                                                                                              |

**Output states:**

- **`PASS`** — silent, proceeds
- **`WARN`** — surfaces findings, prompts user multi-choice:
  ```
  Findings: <N> warn-level issues. Choose:
    1. Fix findings now (return to /build)
    2. Accept findings and proceed (logged in PR description)
    3. Discuss findings — walk me through each one
  ```
- **`FAIL`** — blocks `/ship`; agent returns to `/build` with findings.

**Integration:** `/forge:ship` invokes `/forge:security-review` as **step 0** of its pipeline. `/ship` refuses to run without a PASS or WARN-accepted result.

## 8. Changed skills — detailed design

### 8.1 `/forge:ship` (upgraded)

**Flow:**

```
Step 0. Run /forge:security-review
         · FAIL  → block
         · WARN  → user confirms via multi-choice
         · PASS  → continue

Step 1. Detect git state (on branch? staged? pushed?)

Step 2. Propose atomic commit groupings from the diff
         · Multi-choice:
             I plan 3 commits:
               1. feat(auth): add JWT validation
               2. test(auth): JWT validation cases
               3. docs: update auth README
             Accept? (y / edit / regroup)

Step 3. Commit with strict conventional-commit format
         · type(scope): imperative description, <=72 chars
         · type ∈ {feat, fix, refactor, perf, docs, test, chore, build, ci}
         · Regex-validated before commit runs
         · NO Co-Authored-By trailer

Step 4. Auto semver bump (silent)
         · BREAKING CHANGE footer  → major
         · feat                    → minor
         · fix / refactor / perf   → patch
         · docs / test / chore/ci  → no bump
         · Writes version to package.json / pyproject.toml / Cargo.toml / go.mod tag / *.csproj / etc.

Step 5. Update CHANGELOG.md (Keep-a-Changelog format)

Step 6. Push branch

Step 7. gh pr create
         · Uses .github/pull_request_template.md if present
         · Appends security-review summary to PR body

Step 8. Optional: invoke learning-capturer agent
```

**Helper scripts** under `skills/ship/scripts/`:

- `propose-commits.sh` — analyzes diff, suggests atomic groupings
- `conventional-commit.sh` — validates format; rejects non-conforming messages
- `bump-semver.sh` — derives bump from commit types, writes to stack-appropriate version file
- `update-changelog.sh` — prepends Keep-a-Changelog entry

### 8.2 `/forge:prd-refine` (extended)

Adds two new sections to the template:

**System-design section:**

- Components and their responsibilities
- Interfaces (HTTP, events, DB schemas)
- Data flow diagram (mermaid)
- Tradeoffs considered — produces an ADR under `docs/adr/` if a real decision was made

**Threat-model checklist:**

- Data classification (PII? secrets? public?)
- Attack surface (new endpoints? deserializers? user-uploaded content?)
- Authn/authz changes
- Dependency additions (security posture of new packages)

### 8.3 Multi-choice refits (`/discover`, `/prd`, `/grill-me`)

Pattern applied consistently:

```
Question: <one clear sentence>

Options:
  1. <most-common option>
  2. <option>
  3. <option>
  4. Other — I'll type my own answer

Why it matters: <1–2 lines>
Recommended: <#>
```

**Rules:**

- Max 4 options + "Other"
- Recommended choice always shown
- Multi-select allowed when the question is naturally additive (user answers "1, 3")
- Redundant questions show the inferred answer pre-selected (user overrides if needed)

**Skills affected:**

- `/forge:discover` — outcome, opportunity, solution, persona questions
- `/forge:prd` — work type (bug/feature/refactor/infra/security), persona, success metric
- `/forge:grill-me` — every interrogation question offers 2–4 recommended answers
- `/forge:fix` — bug input type, reproduction confirmation, security-review warn handling

## 9. Statusline (auto-apply)

**Files:**

- `plugins/forge/settings.json` — sets `statusLine.command` to `${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh`
- `plugins/forge/scripts/statusline.sh` — two-line statusline per existing statusline prompt:
  - **Line 1:** `<model name> | <total tokens> | <cost> | ctx:[bar] <%>`
  - **Line 2:** `<cwd with ~> (<git branch>)`
- `README.md` — "Disabling the statusline" section with one-line override

**On install:** Claude Code merges plugin `settings.json` into user config; statusline applies immediately.

**Opt-out:** User sets `statusLine.command` to their preferred value in `~/.claude/settings.json`, which overrides the plugin's.

## 10. Repository layout

```
<repo root>/
├── .claude-plugin/
│   └── marketplace.json              # name: mjolnir
├── .gitignore
├── CHANGELOG.md
├── README.md
├── docs/
│   ├── adr/
│   │   └── 001-marketplace-layout.md
│   ├── guides/
│   │   ├── engineer.md
│   │   └── product-owner.md
│   └── plugin-conventions.md
└── plugins/
    └── forge/
        ├── .claude-plugin/
        │   └── plugin.json            # name: forge, version: 0.1.0
        ├── settings.json              # statusline auto-apply
        ├── hooks/
        │   └── hooks.json
        ├── scripts/
        │   ├── block-dangerous.sh
        │   ├── changelog-guard.sh
        │   ├── secret-scan.sh         # NEW
        │   ├── auto-format.sh         # + Go/Rust/Ruby/Terraform/.NET
        │   ├── stop-verify.sh
        │   └── statusline.sh          # NEW
        ├── agents/
        │   ├── feature-builder.md     # + gh swap
        │   ├── reviewer.md
        │   ├── prd-story-writer.md
        │   └── learning-capturer.md
        └── skills/
            ├── product-discovery/     # multi-choice refit
            ├── poc/
            ├── prd/                   # multi-choice refit
            ├── prd-refine/            # + system-design + threat-model
            ├── grill-me/              # multi-choice refit
            ├── build/                 # + gh swap
            ├── tdd/
            ├── e2e-create/
            ├── e2e/
            ├── verifier/
            │   └── scripts/
            │       ├── detect-stack.sh       # + Go/Rust/Ruby/Terraform/.NET
            │       ├── verify.sh             # + new dispatch cases
            │       ├── verify-node-jest.sh
            │       ├── verify-node-vitest.sh
            │       ├── verify-python.sh
            │       ├── verify-java-gradle.sh
            │       ├── verify-java-maven.sh
            │       ├── verify-go.sh          # NEW
            │       ├── verify-rust.sh        # NEW
            │       ├── verify-ruby.sh        # NEW
            │       ├── verify-terraform.sh   # NEW
            │       └── verify-dotnet.sh      # NEW
            ├── ship/                  # atomic + semver + no co-author + gh
            │   └── scripts/
            │       ├── propose-commits.sh      # NEW
            │       ├── conventional-commit.sh  # NEW
            │       ├── bump-semver.sh          # NEW
            │       └── update-changelog.sh     # NEW
            ├── security-review/       # NEW
            ├── fix/                   # NEW
            ├── doc-architect/
            └── learn/
```

## 11. Verifier — stack coverage

### Stacks supported in v0.1 (10 total)

| Stack         | Detect                                                         | Format               | Lint             | Type                   | Test             |
| ------------- | -------------------------------------------------------------- | -------------------- | ---------------- | ---------------------- | ---------------- |
| Node + Jest   | `package.json` with `jest`                                     | prettier             | eslint           | tsc                    | jest             |
| Node + Vitest | `package.json` with `vitest`                                   | prettier             | eslint           | tsc                    | vitest           |
| Python        | `requirements.txt` / `pyproject.toml` / `setup.py` / `Pipfile` | black                | ruff             | mypy (if present)      | pytest           |
| Java/Gradle   | `build.gradle(.kts)`                                           | google-java-format   | gradle check     | javac                  | gradle test      |
| Java/Maven    | `pom.xml`                                                      | google-java-format   | mvn verify       | javac                  | mvn test         |
| **Go**        | `go.mod`                                                       | gofmt -l             | go vet           | (built-in)             | go test ./...    |
| **Rust**      | `Cargo.toml`                                                   | cargo fmt --check    | cargo clippy     | cargo check            | cargo test       |
| **Ruby**      | `Gemfile`                                                      | rubocop -a           | rubocop          | sorbet tc (if present) | rspec / minitest |
| **Terraform** | `*.tf` files                                                   | terraform fmt -check | tflint           | terraform validate     | (n/a)            |
| **C#/.NET**   | `*.csproj` / `*.sln`                                           | dotnet format        | (build warnings) | dotnet build           | dotnet test      |

### Stacks deferred to v0.2+

Kotlin (closest — reuses Gradle), Swift, PHP, Elixir, Scala, Clojure, Haskell, Zig, Dart/Flutter.

## 12. Success criteria

- v0.1 installs from GitHub via `/plugin marketplace add <user>/mjolnir` → `/plugin install forge@mjolnir`
- `/forge:prd` → `/forge:prd-refine` → `/forge:build` → `/forge:ship` completes a simple feature end-to-end, producing atomic conventional commits, a semver bump, a CHANGELOG entry, and a GitHub PR
- `/forge:fix` produces two atomic commits (failing-test + fix) and a PR
- `/forge:security-review` blocks a diff that contains a hardcoded API key (FAIL) and warns on `md5` used for security (WARN)
- `secret-scan` hook blocks a `git commit` that stages a file containing `ghp_xxx...`
- Statusline displays on plugin install; disabling via user `settings.json` works
- `/forge:verifier` passes a sample repo in each of the 10 supported stacks
- Multi-choice prompts show the "Recommended" option in `/forge:discover`, `/forge:prd`, `/forge:grill-me`, `/forge:fix`

## 13. Out of scope / future milestones

**v0.2 candidates:**

- Kotlin verifier
- Jira integration (port from did-workflow)
- Evals harness
- Git-host adapter abstraction (formalize the `gh` → `glab` swap)

**v0.3+ candidates:**

- Swift, Terraform AWS-specific checks, PHP
- MCP server integrations
- Threat-model automation (read spec → propose STRIDE categories)
- `/forge:init` as a broader one-time setup skill (statusline + preferred PR template + etc.)

## 14. Open questions (none blocking)

None. All design decisions are captured above.

## 15. Total file inventory for v0.1

- Marketplace files: 8
- Plugin manifest: 1
- Plugin `settings.json` (statusline): 1
- Hooks: 1 (`hooks.json`)
- Scripts under `plugins/forge/scripts/`: 6 total — 4 ported (`block-dangerous.sh`, `changelog-guard.sh`, `auto-format.sh`, `stop-verify.sh`), 2 new (`secret-scan.sh`, `statusline.sh`)
- Agents: 4 (all ported; `gh` swap in feature-builder)
- Skills: 15 (13 ported with edits, 2 new: `security-review`, `fix`)
- Verifier stack scripts: 12 (7 ported, 5 new)
- Ship helper scripts: 4 new

Rough effort split:

- **Port + minor edit:** ~60% of work (did-workflow → forge rebrand + `gh` swap + multi-choice refits)
- **Net-new work:** `secret-scan.sh`, `statusline.sh`, `/security-review`, `/fix`, 5 verifier stacks, 4 ship scripts, `prd-refine` system-design + threat-model sections, plugin `settings.json`
