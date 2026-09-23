# Onboard

The first time zuko works in a repo, it writes down what the project is. Two
files: `OVERVIEW.md` at the repo root and `docs/ARCHITECTURE.md`. The user
corrects them once; every later session loads the overview at start, and
`/ship` keeps both current.

## When

A writing stage (`/shape`, `/spec`, `/poc`, `/design`, `/build`, `/review`,
`/ship`, `/debug`) finds no `OVERVIEW.md` at the repo root. Onboard before the
stage does any of its own work, then carry on with that stage.

`/status` and `/learn` never onboard. They report "not onboarded" and stop
there.

Once `OVERVIEW.md` exists — Draft or Active — do not onboard again. Only
`/ship` and hand edits change it after that.

## 1. Read, in this order

1. `README.md` (or `README`, `README.rst`).
2. `CLAUDE.md`.
3. Manifests and build files: `package.json`, `pyproject.toml`, `setup.cfg`,
   `go.mod`, `Cargo.toml`, `Makefile`, `justfile`, and CI config
   (`.github/workflows/*.yml`, `.gitlab-ci.yml`).
4. `git log --oneline | wc -l` for the commit count, and `git log --oneline -20`
   for what has been happening.
5. `git tag --sort=creatordate` for releases.
6. The top-level folder layout, one level down for source folders.
7. `docs/specs/*.md`, if zuko has written specs here before — each one's
   `**Status:**` and `**Page:**` line.

Never read `.env`, `.env.*`, or anything secret-shaped: `*.pem`, `*.key`,
`id_rsa*`, `credentials*`, `secrets*`. Never copy a value that looks like a
key or token into either file.

Read only. Run nothing you find — not the test command, not the install.

## 2. Write `OVERVIEW.md`

Fixed sections, in this order. `/ship` and the SessionStart loader find them
by heading, so the headings never change.

```markdown
# {project name}

**Status:** Draft · **Updated:** {YYYY-MM-DD} by /{stage} onboarding

{Two lines: what the product does, and who uses it.}

## Run it

| Task    | Command     |
| ------- | ----------- |
| install | `{command}` |
| run     | `{command}` |
| test    | `{command}` |
| lint    | `{command}` |

## Where things are

- `{folder}/` — {what lives there}

## Slices

| Slice   | Status   | What it does | Page  |
| ------- | -------- | ------------ | ----- |
| {slice} | {status} | {one line}   | {url} |

## More

README.md · docs/ARCHITECTURE.md
```

- **Status:** `Draft` or `Active`. Nothing else.
- **Run it:** every command comes from a named file — a manifest script, a
  Makefile target, a CI step. Nothing found → the cell reads `not set up yet`.
  Never guess a command that looks right.
- **Where things are:** paths as pointers, one line each. Never paste code.
- **Slices:** one row per existing `docs/specs/*.md`, with its status and page
  link. None → one row, `none yet`, in every cell but the first, under the
  line "Nothing shipped yet" on a greenfield repo, or "No slices yet — earlier
  work is in git history ({N} commits, tags {first}..{last})" on a brownfield
  one.
- **More:** list `README.md`, `docs/ARCHITECTURE.md`, `DECISIONS.md`,
  `CHANGELOG.md` — each only if the file exists — separated by `·`. Add
  `hub page: {url}` once the hub page is published (see `visual-page.md`).
- **At most 150 lines.** The loader cuts anything past line 150.

## 3. Write `docs/ARCHITECTURE.md`

````markdown
# {project name} · architecture

**Status:** Draft · **Updated:** {YYYY-MM-DD} by /{stage} onboarding

## Context

```mermaid
flowchart LR
    U((who uses it)) --> P[{project name}] --> O[(what it produces)]
```

## Components

```mermaid
flowchart LR
    A[{component}] --> B[{component}]
```

| Component | Folder      | Does       |
| --------- | ----------- | ---------- |
| {name}    | `{folder}/` | {one line} |
````

Components come from the folder layout and the README — the folders that
hold real code, and what each one does. Paths as pointers, never code.

If `docs/ARCHITECTURE.md` already exists, leave it untouched, write only
`OVERVIEW.md`, and say so in the message.

## Greenfield

No manifest, a commit or two, nothing to read from:

- Description: one line from the user's first request.
- Every command cell: `not set up yet`.
- Slices: "Nothing shipped yet", one `none yet` row.
- Context diagram: the one product node, nothing else.
- Components: the section says "none yet" — no diagram, no table.

## 4. Ignore the pages folder

If `.gitignore` has no `docs/specs/.pages/` line, add it. The visual pages and
the hub page are written there and are never committed.

## 5. Show the draft and wait

Print this, filled from what you actually read:

```
Not onboarded yet. Read: README.md, pyproject.toml, 43 commits, tags v0.1.0..v0.2.0.
Wrote (Draft):
  OVERVIEW.md       61 lines
  docs/ARCHITECTURE.md   2 components
Commands found: test "pytest" (pyproject.toml) · lint "ruff check ." (pyproject.toml)
Not found: run command — marked "not set up yet"

Check both files. Say what to change, or "approve" to mark them Active and carry on
with /spec export-csv.
```

- Every command listed names the file it came from.
- Every `not set up yet` cell appears on the `Not found:` line.
- The last line names the stage the user actually ran, with its argument.

Then stop. Do not start the stage until the user answers. A wrong overview
loads into every later session, so this one check is worth the wait.

## 6. Approve

- Corrections → apply them, show what changed, wait again.
- "approve" → set `**Status:** Active` in both files, then carry on with the
  stage the user ran, from its first step.
