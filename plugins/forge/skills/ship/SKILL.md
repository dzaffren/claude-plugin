---
name: ship
description: >
  Ships changes from working directory to a GitHub pull request in one command.
  Orchestrates: branch creation, commit, push, and PR. Detects current git state
  and starts from the right step. Use this skill when the user says "ship it",
  "ship this", "open a PR", "create a pull request", "push and create PR",
  "commit and push", "get this into review", or runs /ship. Also triggers when
  the user has finished manual coding and wants to get changes into a pull
  request without a full /build pipeline. Accepts optional arguments for ticket
  ID or description.
---

# Ship

Ship changes from working directory to a GitHub pull request. Detects where you are in the git workflow and picks up from the right step.

**Plain language & trust:** apply `${CLAUDE_PLUGIN_ROOT}/references/plain-language.md` to every choice, summary, and recommendation you show the user (the commit-plan and review-gate prompts, and the final report / PR summary) — plain wording, a stated reason behind each recommendation, and technical detail only when the user asks.

**Arguments:** `$ARGUMENTS` — optional ticket ID (e.g., `PROJ-123`), description, the `--gates-cleared` token, or any combination.

Parse arguments:

- **`--gates-cleared` token** — if present, strip it out first, then treat this run as "gates-cleared mode" (see Step 0). It signals that the caller (`/forge:build` Phase 5) already ran the security-review and code-reviewer gates before its pre-commit checkpoint, so this ship must skip Step 0 and Step 0.5. Strip the token before extracting the ticket/description.
- Extract ticket ID: matches pattern `[A-Z]+-\d+` (e.g., `PROJ-123`, `DASH-456`)
- Remaining text after ticket extraction is the description

---

## Step 0 — Security Review (gate)

**Gates-cleared mode:** if `--gates-cleared` was passed (see Arguments), skip this step **and** Step 0.5 entirely and go straight to Step 1 — `/forge:build`'s loop already ran both gates before its pre-commit checkpoint (ADR-002). Only the build loop should pass this token; a normal `/ship` never does, so the standalone path below is unchanged.

Otherwise, run the gate as normal. Before anything else, invoke the `security-review` skill against the uncommitted diff (working tree + index). Hand off the current branch and the target branch (detected in Step 5; default `main`).

Interpret the result:

- **PASS** — silent, continue to Step 1.
- **WARN** — surface findings and ask the user multi-choice:
  ```
  security-review returned <N> WARN-level finding(s). Choose:
    1. Fix findings now — abort /ship, return to coding
    2. Accept findings and proceed — findings will be appended to the PR body
    3. Walk me through each finding
  Recommended: 1
  ```
  On `1` or `3`, stop. On `2`, stash the findings summary for Step 5 (PR body).
- **FAIL** — stop with the findings printed. Do not commit, do not push, do not open a PR.

If `security-review` is unavailable (skill not installed), log a one-line notice and continue — do not block. This keeps `/ship` usable outside forge installs.

---

## Step 0.5 — Code Review (gate)

**Gates-cleared mode:** skip this step too if `--gates-cleared` was passed (see Step 0) — the build loop already ran code review before its checkpoint.

Invoke the `code-reviewer` agent against the uncommitted diff (working tree + index). The agent returns a JSON array of findings with `severity` (`info|warn|fail`), `category`, `description`, and `fix` (`{type: auto, patch}` or `{type: manual}`).

Interpret the result:

- **No findings** (`[]`) — silent, continue to Step 1.
- **Only `auto`-fixable findings** — save each finding's patch to a temp file, apply with `git apply <patch>`, re-run the `verifier` skill on the changed files. If verify passes, continue to Step 1 with a one-line summary for the commit notes in Step 3: `Auto-fixed <N> review finding(s): <one-line categories>`. If verify fails after patching, reverse **only the applied patches** with `git apply -R <patch>` for each (in reverse order) — do **NOT** use `git checkout -- <files>`, which would discard the user's pre-existing uncommitted work along with the patch. Stop with the error.
- **`manual` findings present (no `fail`)** — surface to the user multi-choice:
  ```
  code-reviewer returned <A> auto-fix(es) and <M> manual finding(s). Choose:
    1. Show me each finding (walk through one at a time)
    2. Apply auto-fixes and include manual findings in the PR body
    3. Abort /ship, return to coding
  Recommended: 2
  ```
  On `1`, walk through findings one at a time, asking per-finding whether to apply / skip / edit. On `2`, apply auto patches, stash manual findings for Step 5 (PR body). On `3`, stop.
- **Any `fail` severity** — surface findings and ask multi-choice:
  ```
  code-reviewer returned <F> fail-level finding(s). Choose:
    1. Show me each fail (walk through one at a time)
    2. Abort /ship, return to coding
  Recommended: 1
  ```
  Do not auto-continue on `fail`. On `2`, stop.

If auto patches are applied, they are folded into the commit plan in Step 3a: either merged into the originating group (if the fix lives inside one group's files) or added as a separate `refactor: address code-review findings` commit at the end of the plan.

If the `code-reviewer` agent is unavailable, log a one-line notice and continue — matches the `security-review` fallback.

---

## Step 1 — State Detection

Run these commands to determine the current position:

```bash
git branch --show-current
git status --porcelain
git diff --stat
git diff --cached --stat
git log @{upstream}..HEAD --oneline 2>/dev/null
```

Determine the entry point:

| Condition                                                        | Entry point                             |
| ---------------------------------------------------------------- | --------------------------------------- |
| On `main`/`master`/`develop` with uncommitted changes            | Step 2 (Branch) — **MUST** branch first |
| On `main`/`master`/`develop` with no changes                     | **STOP** — nothing to ship              |
| On a non-protected branch with uncommitted changes               | Step 3 (Commit)                         |
| On a non-protected branch, all committed, unpushed commits exist | Step 4 (Push)                           |
| On a non-protected branch, pushed, no PR exists                  | Step 5 (PR)                             |
| On a non-protected branch, pushed, PR already exists             | Report existing PR URL and **STOP**     |

To check for an existing PR: `gh pr list --head "$(git branch --show-current)" --state open`

**Protected branches**: `main`, `master`, `develop`. NEVER commit directly to these.

---

## Step 2 — Branch Creation

Read `${CLAUDE_SKILL_DIR}/references/branch-conventions.md`.

1. Infer the branch type from the nature of the changes or conversation context. Default to `feature/` if ambiguous.
2. If a ticket ID was provided in `$ARGUMENTS` or is known from the conversation, include it.
3. Generate a kebab-case description slug (2-5 words) from the changes or conversation.
4. Create the branch from current HEAD:

```bash
git checkout -b {type}/{ticket-id}-{description}
# or without ticket:
git checkout -b {type}/{description}
```

**Do not** ask the user for a base branch — use the current branch as the base.

Proceed to Step 3.

---

## Step 3 — Commit (atomic, conventional, semver-aware)

Read `${CLAUDE_SKILL_DIR}/references/commit-conventions.md`.

### 3a — Propose atomic groupings

Run `bash ${CLAUDE_SKILL_DIR}/scripts/propose-commits.sh` to seed a grouping
plan from the diff. Refine the output into a concrete commit list (the script
is a heuristic — you are expected to override its scopes/types where the diff
tells a clearer story). Then present the plan to the user multi-choice:

```
I plan <N> commit(s):
  1. feat(auth): add oauth2 login flow
  2. test(auth): cover oauth2 callback edge cases
  3. docs: update auth README
Choose:
  1. Accept plan
  2. Regroup (I'll re-draft)
  3. Edit — walk me through the groupings
Recommended: 1
```

### 3b — Validate each message

For every commit, pipe the drafted message through:

```bash
printf '%s' "$MSG" | bash ${CLAUDE_SKILL_DIR}/scripts/conventional-commit.sh -
```

If the validator fails, fix the message and re-validate. Do not commit until it
passes. The validator enforces the subject rules from
`references/commit-conventions.md` **and** rejects any `Co-Authored-By:` trailer
— forge commits must not include one.

### 3c — Update CHANGELOG (if present)

If `CHANGELOG.md` is tracked (`git ls-files CHANGELOG.md`), run
`bash ${CLAUDE_SKILL_DIR}/scripts/update-changelog.sh <type> <subject>` for
each non-skipped commit **before** you stage its files. The script places the
entry under the appropriate Keep-a-Changelog heading inside `[Unreleased]`;
`test`/`chore`/`ci`/`build`/`style`/`revert` types are no-ops. Stage
`CHANGELOG.md` together with the commit's other files so the changelog-guard
hook accepts the commit.

### 3d — Stage and commit

Stage specific files per group. **NEVER** stage `.env`, credentials, secrets,
or large binaries. Prefer naming files explicitly over `git add -A`. Commit via
HEREDOC:

```bash
git commit -m "$(cat <<'EOF'
type(scope): imperative description

Optional body explaining what and why.

Refs: TICKET-123
EOF
)"
```

Add a `Refs: TICKET-123` footer when a ticket ID is known. **Never** add a
`Co-Authored-By:` trailer — the validator blocks it.

### 3e — Auto semver bump + changelog release

After the last commit, derive the bump and apply it:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/bump-semver.sh origin/<base>..HEAD --apply
status=$?
```

(Use `main` or the detected base branch in place of `<base>`.) The script
prints `<level> <old> <new> <manifest-summary>` on stdout, and exits non-zero
when a bump is required but cannot be applied.

**Exit-code gate (check this first).** `bump-semver.sh` exits non-zero when a
version bump is required but it cannot read or write the JSON manifests — most
commonly because `jq` is not installed (the script reads and writes
`plugin.json` / `marketplace.json` through `jq`). If `status` is non-zero, do
**NOT** parse stdout and do **NOT** treat this as a docs-only ship — that would
silently leave versions stale. Surface the script's stderr and ask the user
multi-choice:

```
bump-semver could not apply the version bump:
  <stderr from bump-semver.sh>
Choose:
  1. Stop — fix the tooling (e.g. install jq) and re-run /ship
  2. Proceed without a version bump — push and open the PR; the version and
     CHANGELOG stay unbumped, to be cut on a later ship
Recommended: 1
```

On `1`, stop the ship. On `2`, skip the rest of Step 3e (no release commit) and
proceed to Step 4; note in the Step 6 report that the release bump was skipped
and why. Only when `status` is `0` do you parse the four stdout fields and apply
the skip rule below.

**Skip rule.** If `<level>` is `none` or `<manifest-summary>` is `none`, skip
Step 3e entirely and proceed to Step 4 — this covers docs-only ships and
repos with no detectable manifest.

**Manifest-summary shapes.** Otherwise `<manifest-summary>` takes one of two
shapes that determine what to stage:

- **Single file path** (e.g. `package.json`, `Cargo.toml`, `pyproject.toml`) —
  the script wrote exactly that one manifest. Stage it directly.
- **`claude-plugin:N`** where `N` is the count of in-scope plugins — the
  script already wrote every in-scope `plugins/<slug>/.claude-plugin/plugin.json`
  file **and** `.claude-plugin/marketplace.json`. Do **not** treat
  `claude-plugin:N` as a literal file path. Stage all written files via the
  glob plus the marketplace manifest.

Then rotate the changelog into a dated release heading:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/update-changelog.sh --release <new>
```

This turns `[Unreleased]` into `[<new>] - <date>` and opens a fresh empty
`[Unreleased]`. Tolerate these non-fatal stderr notices and continue with
just the manifest bump:

- `no CHANGELOG.md in cwd; skipping`
- `no [Unreleased] section found; nothing to release`

Stage the manifest(s) and changelog together, then create a single release
commit. Validate the subject through `conventional-commit.sh` — it must be
exactly `chore(release): bump to <new>` with no `Co-Authored-By:` trailer:

```bash
# Standard single-file manifest:
git add <manifest-summary> CHANGELOG.md
# Or, for claude-plugin:N:
git add plugins/*/.claude-plugin/plugin.json .claude-plugin/marketplace.json CHANGELOG.md

printf '%s' "chore(release): bump to <new>" \
  | bash ${CLAUDE_SKILL_DIR}/scripts/conventional-commit.sh -
git commit -m "chore(release): bump to <new>"
```

Example subject: `chore(release): bump to 0.4.0`.

Note: pre-release suffixes (e.g. `-alpha`) are stripped by the numeric bump —
a repo at `0.3.0-alpha` with a `feat` commit bumps to `0.4.0`, not
`0.4.0-alpha`. Pre-release orchestration is deliberately out of scope; bump
to a fresh version and re-tag as pre-release manually if needed.

Bump rules (highest wins): `BREAKING CHANGE` / `!` → major; `feat` → minor;
`fix` / `refactor` / `perf` → patch; `docs` / `test` / `chore` / `ci` / `style`
/ `build` / `revert` → no bump.

Proceed to Step 4.

---

## Step 4 — Push

1. Check if the branch has an upstream: `git rev-parse --abbrev-ref @{upstream} 2>/dev/null`
2. If no upstream: `git push -u origin $(git branch --show-current)`
3. If upstream exists: `git push`

Proceed to Step 5.

---

## Step 5 — PR Creation

Read `${CLAUDE_SKILL_DIR}/references/pr-template.md`.

Use `gh pr create` to create the pull request.

1. **Target branch**: determine the branch this was created from. Check if `main` is an ancestor (`git merge-base --is-ancestor main HEAD`). If not, try `develop`. If neither, ask the user.
2. **Title**: if there is a single commit, use its subject line. If multiple commits, synthesize a descriptive summary title. Max 72 characters.
3. **Body**: fill in the PR template:
   - **Summary**: 1-3 bullet points — what changed and why
   - **Ticket**: link to ticket if ID is known, otherwise `N/A`
   - **Changes**: logical change groups or key commits
   - **How to Test**: inferred from the nature of the changes
   - **Security Review**: only if `security-review` returned WARN and the user accepted — append the findings summary (one bullet per finding with category + file path) under a `## Security Review — accepted warnings` section
   - **Checklist**: standard review checklist
4. **Draft**: create as draft if the user said "draft".
5. Create the PR:

```bash
gh pr create \
  --title "title here" \
  --body "$(cat <<'EOF'
## Summary

- bullet 1
- bullet 2

## Ticket

TICKET-123 or N/A

## Changes

- change group 1
- change group 2

## How to Test

1. step 1
2. step 2

## Checklist

- [ ] Code follows project conventions
- [ ] Tests added/updated for changed behavior
- [ ] No unrelated changes included
- [ ] Branch is up to date with target
EOF
)" \
  --base main \
  --head "$(git branch --show-current)"
```

6. If `gh` is not authenticated, tell the user to run `gh auth login` and stop.

**Do not** mention Claude, Claude Code, or any AI tool in the PR title, body, or commit messages.

---

## Step 6 — Report

Tell the user:

- Which steps were executed (branch → commit → push → PR)
- The PR URL (from gh output)
- Any steps that were skipped and why

---

## Step 7 — Capture Learnings (optional — driven by caller or argument)

Learning capture has two flavors here; run whichever applies.

### 7a — Post-ship capture

If `ship` was invoked from `/build` (Phase 6 of that skill), or the user
explicitly asks to capture learnings (`/ship --learn` or a message like
"capture anything worth remembering from this session"), invoke the
`learning-capturer` agent with the diff, commit messages, and any in-session
corrections as signals. The agent proposes candidates; surface them to the
user for approval; approved candidates are handed to the `learn` skill.

For each approved candidate, the `learn` skill responds with
`CAPTURED: <type>-<slug>` (or `UPDATED: <type>-<slug>` for dedupe merges).
Record each `<type>-<slug>` into an in-memory list for this ship session —
Step 8 consumes this list to update the changelog.

If no trigger, skip. This step is opt-in when ship is run manually — capture
shouldn't fire on every casual push.

### 7b — Learn from PR comments

If the user says `/ship --learn-from-comments` (or equivalent — "pull
lessons from the PR review", "what should I remember from the PR
comments"), and the PR created in Step 5 has review comments:

1. Fetch comments: `gh pr view <PR-number> --json comments,reviews` (or `gh api repos/{owner}/{repo}/pulls/{pull_number}/comments` for per-file review comments) for the current PR.
2. Filter to comments containing a learn-marker: `#learn`, or the phrases
   "next time", "going forward", "for the future", "always", "never" (case
   insensitive). This is a coarse filter — the user will approve each
   candidate.
3. For each matched comment, build a candidate and pass the set to
   `learning-capturer` for the normal approve / hand-off-to-`learn` flow.
4. Record the `<type>-<slug>` values from each `CAPTURED:` / `UPDATED:`
   response into the same session list used in 7a — Step 8 consumes it.

Do not capture silently and do not auto-filter to zero — if nothing matches
the markers, report that so the user knows to check the PR manually if they
expected lessons.

---

## Step 8 — Sync learnings into CHANGELOG

Runs only if Step 7 captured ≥1 learning this session. If Step 7 was skipped
or captured nothing, skip this step entirely. Also skip if `CHANGELOG.md` is
not tracked in the repo.

Use the session list of `<type>-<slug>` values that Step 7a/7b recorded from
the `learn` skill's `CAPTURED:` / `UPDATED:` responses. That list is the
source of truth; do not re-scan `docs/learnings/` to guess which entries are
"new".

For each captured slug, read its file (`docs/learnings/<type>-<slug>.md`) for
the `name`, `type`, and `description` frontmatter fields. Append a
`### Learnings` subsection to the `[Unreleased]` block of `CHANGELOG.md`,
one bullet per learning:

```markdown
### Learnings

- **[name]** ([type]) — [description]. See `docs/learnings/[type]-[slug].md`.
```

Insert under the existing `## [Unreleased]` heading, after any existing
subsections (`### Added`, `### Changed`, etc.) but before the next version
heading. Append directly — `update-changelog.sh` does not currently have a
learnings mode, so do not invoke it for this step.

Commit and push the changelog update:

```bash
git add CHANGELOG.md
git commit -m "docs: sync learnings to changelog"
git push
```

The changelog-guard hook accepts a standalone CHANGELOG commit. Because this
commit lands after Step 5 opened the PR, the push updates the existing PR.

After the push completes, emit a one-line follow-up to the user:

```
Updated CHANGELOG.md with <N> captured learning(s). PR has been updated.
```
