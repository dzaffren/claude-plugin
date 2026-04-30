---
name: doc-architect
description: >
  Generates or incrementally updates a docs/architecture.md file for any repo,
  with mermaid diagrams and Claude-Code-friendly structure. Use this skill after
  implementing a feature, after completing a build, after a spec has been built,
  when the user says "update the architecture docs", "generate architecture",
  "document the architecture", "update docs", "refresh the arch doc", or "keep
  the architecture doc in sync". Also auto-trigger when a build or spec skill
  has just completed and the user asks to document what was built. Works on any
  repo — reads the codebase to produce a grounded architecture document.
---

# Doc Architect

Generate or incrementally update `docs/architecture.md` for the current repo.
The output is structured so Claude Code can read it as grounding context for
future coding tasks.

## Step 1: Determine Mode

Check whether `docs/architecture.md` already exists at the repo root using the
Glob tool.

| Condition | Mode |
|-----------|------|
| File does not exist | **Create** — generate from scratch |
| File exists | **Update** — read it, preserve unchanged sections, update only what changed |

If the `docs/` directory does not exist, create it before writing.

## Step 2: Context Loading

Load the following in order. Stop at 20 files total.

1. Read `CLAUDE.md` at the repo root (if it exists) — conventions, stack, layout.
2. Read the repo's manifest file to identify tech stack and dependencies:
   - Node/JS: `package.json`
   - Python: `pyproject.toml` or `setup.py`
   - Rust: `Cargo.toml`
   - Java/Kotlin: `pom.xml` or `build.gradle`
   - Go: `go.mod`
3. Use Glob to survey the top-level directory structure (pattern `**/*`, depth 2).
4. If in **Update** mode, read the existing `docs/architecture.md` in full.
5. Identify the 3-5 most important source directories by file count. Read one key
   entry point file per major layer (e.g., `src/index.ts`, `src/main.py`,
   `app/router.ts`, `src/App.tsx`).
6. If `$ARGUMENTS` is provided, focus context loading on the area described
   (e.g., "data layer" → read files in `src/data/` or `src/db/`).

**Hard limit: 20 files total.** Prioritize manifests, entry points, and config.

## Step 3: Load Template

Read the architecture template before generating:

`${CLAUDE_SKILL_DIR}/references/template-architecture.md`

This defines the output format. Fill in its sections with repo-specific content.

## Step 4: Generate or Update Sections

### Create mode

Fill every section from scratch using what you learned in Step 2. Every section
must contain concrete, repo-specific content — no generic placeholders.

### Update mode

For each section:

1. Compare what the existing doc says against what you now observe in the codebase.
2. If the section is still accurate, **preserve it unchanged** — do not rewrite for style.
3. If the section is outdated or incomplete, **update only the changed parts**.
4. If a section is missing from the existing doc, **add it**.
5. Add a `<!-- last-updated: YYYY-MM-DD -->` comment at the very top of the file.

### Section-specific guidance

**System Overview**
Write a 2-3 sentence summary: what the system does, who uses it, primary
responsibilities. Include a Mermaid `graph TD` component diagram showing the
top-level modules and their relationships.

**Data Flow**
Describe the primary data paths through the system. Include a Mermaid
`sequenceDiagram` for the most important user-facing flow (e.g., request
lifecycle, build pipeline, data ingestion). Add a second diagram for a
secondary flow if significantly different.

**Directory Structure & Module Boundaries**
Show the directory tree (depth 2-3) with one-line descriptions per directory.
Draw a Mermaid `graph LR` showing module dependencies and direction. Mark
which modules are public API vs internal.

**Tech Stack & Dependencies**
Table of language, framework, key libraries, build tools, external service
integrations grouped by purpose (runtime, dev, test). Include a Mermaid
`graph TD` showing integration points with external systems (databases, APIs,
queues, auth providers, etc.).

**Key Patterns & Conventions**
Document the architectural patterns in use (layered, event-driven, plugin
system, monorepo, etc.). Note naming conventions, file organization rules,
error handling patterns, and testing patterns. This section is the most
valuable for Claude Code grounding — be specific.

**Configuration & Environment**
Table of environment variables and config files with purpose and required/optional.

## Step 5: Quality Rules

Before writing the file, verify every item. Fix any failures.

- [ ] No `[TBD]`, `[placeholder]`, `TODO`, or `[Insert X]` markers in any section
- [ ] At least 4 Mermaid diagrams present (component, sequence, module boundary, integration)
- [ ] All Mermaid diagrams use valid syntax
- [ ] All referenced file paths and directory names exist in the repo
- [ ] Dependency names match the actual manifest file
- [ ] In Update mode: unchanged sections are preserved verbatim
- [ ] Document reads top-down — a new developer can understand the system linearly
- [ ] Total length is under 500 lines (excluding mermaid blocks) — if longer, more candidates for Step 6

## Step 6: Flag Extraction Candidates

At the bottom of `docs/architecture.md`, add a **Companion Doc Candidates** section.
For each section that exceeds 80 lines or covers a topic deep enough to stand alone,
suggest a companion doc. Only add suggestions that are genuinely warranted.

Example:
```
## Companion Doc Candidates

- `docs/data-model.md` — Data Flow section contains extensive schema detail
- `docs/api-reference.md` — API endpoints and contracts could be a dedicated reference
- `docs/deployment.md` — Infrastructure and deployment details warrant their own doc
```

If no section qualifies, omit this section entirely.

## Step 7: Write and Report

1. Write the completed document to `docs/architecture.md`.
2. Tell the user:
   - The file path written
   - Whether this was a **Create** or **Update**
   - In Update mode: which sections were added or changed
   - Companion doc candidates (if any)
3. STOP. Do not make any other changes to the repo.
