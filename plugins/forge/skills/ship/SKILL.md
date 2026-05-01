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

**Arguments:** `$ARGUMENTS` — optional ticket ID (e.g., `PROJ-123`), description, or both.

Parse arguments:

- Extract ticket ID: matches pattern `[A-Z]+-\d+` (e.g., `PROJ-123`, `DASH-456`)
- Remaining text after ticket extraction is the description

---

## Step 0 — Security Review (gate)

Before anything else, invoke the `security-review` skill against the uncommitted diff (working tree + index). Hand off the current branch and the target branch (detected in Step 5; default `main`).

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

### 3e — Auto semver bump

After the last commit, derive the bump and apply it:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/bump-semver.sh origin/<base>..HEAD --apply
```

(Use `main` or the detected base branch in place of `<base>`.) The script
prints `<level> <old> <new> <manifest>`. If `<level>` is `none` or `<manifest>`
is `none`, skip. Otherwise stage the bumped manifest and create a single
release commit:

```bash
git commit -m "chore(release): bump to <new>"
```

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

Do not capture silently and do not auto-filter to zero — if nothing matches
the markers, report that so the user knows to check the PR manually if they
expected lessons.
