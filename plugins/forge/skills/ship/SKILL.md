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

To check for an existing PR: `gh pr list --source-branch=$(git branch --show-current) --state=opened`

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

## Step 3 — Commit

Read `${CLAUDE_SKILL_DIR}/references/commit-conventions.md`.

1. Run `git status --porcelain` to see all changes.
2. Run `git diff` (unstaged) and `git diff --cached` (staged) to understand what changed.
3. Analyze the changes:
   - **Type**: auto-detect from the nature of the diff (`feat`, `fix`, `refactor`, `test`, `chore`, `docs`, `style`, `perf`, `ci`, `build`, `revert`).
   - **Scope**: auto-detect from the primary module or directory touched.
   - **Subject**: draft in imperative mood, lowercase, no period, max 72 chars.
4. If the changes span multiple logical concerns (e.g., a feature and its tests, or changes across distinct modules), create **multiple commits** rather than one monolithic commit. Each commit must be a self-contained, passing state.
5. Add a `Refs: TICKET-123` footer when a ticket ID is known.
6. Stage specific files. **NEVER** stage `.env`, credentials, secrets, or large binaries. Prefer naming files explicitly over `git add -A`.
7. **Changelog guard**: check if `CHANGELOG.md` is tracked in the repo (`git ls-files CHANGELOG.md`). If it is:
   - Update the `[Unreleased]` section with a summary of the change under the appropriate heading (`Added`, `Changed`, `Fixed`, etc.)
   - Stage `CHANGELOG.md` alongside the other changes
   - This must happen **before** the commit — the changelog-guard hook will block the commit otherwise.
8. Commit using a HEREDOC for the message:

```bash
git commit -m "$(cat <<'EOF'
type(scope): imperative description

Optional body explaining what and why.

Refs: TICKET-123
EOF
)"
```

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
   - **Checklist**: standard review checklist
4. **Draft**: create as draft if the user said "draft".
5. Create the PR:

```bash
gh pr create \
  --title "title here" \
  --description "$(cat <<'EOF'
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
  --target-branch main \
  --source-branch "$(git branch --show-current)" \
  --no-editor
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

1. Fetch comments: `gh api projects/:id/merge_requests/:iid/notes` for the
   current PR.
2. Filter to comments containing a learn-marker: `#learn`, or the phrases
   "next time", "going forward", "for the future", "always", "never" (case
   insensitive). This is a coarse filter — the user will approve each
   candidate.
3. For each matched comment, build a candidate and pass the set to
   `learning-capturer` for the normal approve / hand-off-to-`learn` flow.

Do not capture silently and do not auto-filter to zero — if nothing matches
the markers, report that so the user knows to check the PR manually if they
expected lessons.
