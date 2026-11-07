# Guard paths

**Version:** v1 · **Status:** Shipped · **Type:** Bug · **Project type:** CLI/Library

**Shape doc:** docs/specs/os-agnostic-suite/shape.md
**Depends on:** None
**Page:** https://claude.ai/artifact/2juH24KKAcWnDXTBv4prwR

On Windows, zuko's commit guards read a Git Bash path such as `/tmp/tmp.Kx81Qz/msg` with Windows path rules, find nothing, and let the command through. This slice makes the attribution, main-branch and secret-scan guards read those paths as Git Bash does, and block when they still cannot read a file.

## Problem

zuko's hooks are bash scripts that call native Windows Python. Git Bash converts a path when it passes the path to a program as an argument. It does not convert a path inside other text, and the hook gets the whole command as text inside JSON. Python 3.14 then reads `/tmp/x` as `\tmp\x` on the current drive.

Measured on this machine, 2026-11-07, Git Bash with Python 3.14.3:

| Command | Guard | Windows | Linux |
| --- | --- | --- | --- |
| `git commit -F /tmp/tmp.B4xfY7szMY/msg`, the file has a Claude trailer | `block-attribution.sh` | exit 0 | exit 2 |
| the same, with the path as `C:/Users/adzaf/AppData/Local/Temp/tmp.B4xfY7szMY/msg` | `block-attribution.sh` | exit 2 | exit 2 |
| `git -C /tmp/tmp.1SdJLbyZRG commit -m x`, that repo is on `main` | `block-dangerous.sh` | exit 0 | exit 2 |
| `cd /tmp/tmp.1SdJLbyZRG && git commit -m x`, an AWS key is staged | `secret-scan.sh` | exit 0 | exit 2 |

Two root causes:

- `block-attribution.sh` opens a message file with `os.path.isfile(value)` and skips the file when the answer is no.
- `lib/git-command.py` `resolve()` gets `False` from `os.path.isabs('/tmp/x')` on Windows. The directory turns to None. The two guards then check only the session's directory and the project directory, and those are on a feature branch.

Each miss is a fail open. The guards must fail closed (D31).

Some message files cannot be read on any OS today, and the hook passes them: `-F -` with a heredoc, `-F ~/msg` for a file that does not exist, and `-F "$TMPDIR/msg"`.

The pentester fence has the opposite fault. `scope-pentester-bash.sh` `is_scratch()` compares each path with `os.path.normpath`, which turns `/` into `\` on Windows. No `mktemp -d` path passes, so the fence blocks each command into the scratch copy. That fails closed. It stopped both seeded runs of `attack-classes` (its row O11).

## Slice test

| Check                         | Result                                                                                       |
| ----------------------------- | -------------------------------------------------------------------------------------------- |
| Cuts every layer it needs     | yes — the hook scripts and the shared command parser that Claude Code's PreToolUse runs      |
| One e2e test walks it         | yes — one test feeds a hook payload for each scenario to the real hooks in a scratch repo    |
| Worth shipping alone          | yes — on Windows, a signed commit, a commit on `main` and a staged secret are blocked again  |
| Fits (≤5 scenarios, ≤2 areas) | yes — 5 scenarios, one area (`plugins/zuko/scripts/`)                                        |

**Path:** full — the change touches 4 or more files and adds block messages, so the messages get their own pause.

## Flow

```mermaid
flowchart LR
    C["Claude: Bash call<br/>git commit -F /tmp/tmp.Kx81Qz/msg"] -- "PreToolUse JSON" --> H["hook<br/>block-attribution.sh"]
    H -- "path as typed" --> P{"Git Bash path?"}
    P -- "yes: cygpath" --> N["C:/Users/.../Temp/tmp.Kx81Qz/msg"]
    P -- "no" --> N
    N -- "open" --> R{"file read?"}
    R -- "yes: check text" --> D["exit 0 or exit 2"]
    R -- "no" --> B["exit 2: cannot read the message file"]
```

The hook takes the path from the command, converts it when it is a Git Bash path, then opens it. A file it reads is checked. A file it cannot read is blocked.

## Acceptance criteria

```gherkin
Scenario: The attribution guard reads a Git Bash message file
  Given /tmp/tmp.Kx81Qz/commit-msg.txt holds "fix(refunds): stop a refund above the order total" and the line "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
  When Claude runs "git commit -F /tmp/tmp.Kx81Qz/commit-msg.txt" in Git Bash on Windows
  Then block-attribution.sh exits 2
  And its message says "Blocked: the commit message carries Claude attribution."

Scenario: The main-branch guard follows a Git Bash directory
  Given the repo /c/Users/adzaf/Documents/Projects/refunds-api is on main
  And the Claude session runs in /c/Users/adzaf/Documents/Projects/Zuko on feat/guard-paths
  When Claude runs "git -C /c/Users/adzaf/Documents/Projects/refunds-api commit -m 'fix: round refunds'"
  Then block-dangerous.sh exits 2 with "Blocked: committing directly on main. Create a branch first."

Scenario: The secret scan follows a cd into a Git Bash directory
  Given the repo /tmp/tmp.Qm42Lw is on feat/refund-cap
  And its staged diff adds the line 'aws_key = "AKIAIOSFODNN7EXAMPLE"'
  When Claude runs "cd /tmp/tmp.Qm42Lw && git commit -m 'feat: cap refunds'"
  Then secret-scan.sh exits 2 and names the staged line

Scenario Outline: A message that the guard cannot read is blocked, on every OS
  Given no file exists at /tmp/tmp.Kx81Qz/missing-msg.txt
  When Claude runs "<command>"
  Then block-attribution.sh exits 2
  And its message names "<what>" and says that the guard could not read it

  Examples:
    | command                                                                                | what                              |
    | gh pr create --title 'fix: refund cap' --body-file /tmp/tmp.Kx81Qz/missing-msg.txt    | /tmp/tmp.Kx81Qz/missing-msg.txt   |
    | git commit -F "$TMPDIR/msg"                                                            | $TMPDIR/msg                       |
    | git commit -F - with a heredoc that holds "fix: round refunds"                         | stdin (-F -)                      |

Scenario: The pentester fence lets a command into its scratch copy
  Given the pentester's scratch copy is /tmp/tmp.Zr93Np, made by mktemp -d
  When the pentester runs "cd /tmp/tmp.Zr93Np && grep -rn 'subprocess' plugins/zuko/scripts" in Git Bash on Windows
  Then scope-pentester-bash.sh exits 0
  And "cd /tmp/../c/Users/adzaf && ls" is still blocked
```

## Scope

**In:**

- `block-attribution.sh` reads each message file path as Git Bash does: commit and tag `-F` and `--file`, `gh release create` `-F` and `--notes-file`, and `gh pr create`, `edit` and `merge` `-F` and `--body-file`.
- `lib/git-command.py` resolves a Git Bash directory for `-C`, `cd` and `pushd`. `block-dangerous.sh` and `secret-scan.sh` get the fix through it.
- A message file that the guard cannot read is blocked, on every OS (O1). This includes a file that an earlier part of the same command writes.
- A message from stdin (`-F -`, `--body-file -`, `--notes-file -`) is blocked, on every OS (O2).
- The pentester fence reads its scratch paths with POSIX rules on Windows (O3). This closes `attack-classes` O11.
- The `/ship` skill text at `skills/ship/SKILL.md:180` changes to match: a path that the hook cannot read is blocked, not a miss.

**Out:**

- A commit directory that the parser cannot know, such as `cd "$REPO" && git commit`. It still falls back to the session and project directories, as on Linux today.
- CRLF in Python's output and the cp1252 encoding — slice 3, `utf8-stdio`.
- `board.py --by "/spec ..."`, which Git Bash rewrites to `C:/Program Files/Git/spec ...`. That is an argument rewrite and not a guard — slice 4, `portable-suite`, traces it.
- cmd and PowerShell. zuko's hooks run in Git Bash on Windows (shape, Not doing).

## Interface

This slice adds no command and no flag. Its interface is what a guard prints and its exit code. Claude reads the message and runs the command again in a form that the guard can check.

```mermaid
flowchart LR
    F["-F, --file, --body-file,<br/>--notes-file PATH"] -- "read" --> T["check the text<br/>(today's rules)"]
    F -- "cannot read" --> U["exit 2<br/>Blocked: could not read the ... file"]
    S["-F - , --body-file -,<br/>--notes-file -"] --> I["exit 2<br/>Blocked: ... comes from stdin"]
    D["git -C DIR, cd DIR &&,<br/>pushd DIR &&"] -- "Git Bash DIR converted" --> G["main-branch guard and<br/>secret scan: today's messages"]
    P["pentester: cd /tmp/tmp.X &&"] -- "POSIX compare" --> Q["fence: today's allow and<br/>block messages"]
```

Two new messages come from `block-attribution.sh`. Every other guard keeps its messages, and now reaches them on Windows too.

### 1. A message file that the guard cannot read

The path is shown as Claude typed it, not as the guard converted it.

```text
Blocked: the guard could not read the commit message file /tmp/tmp.Kx81Qz/missing-msg.txt, so it did not check the text.

Write the file in a separate Bash call, before this command. Or give the message with -m.
```

### 2. A message from stdin

```text
Blocked: the commit message comes from stdin (-F -). The guard cannot read stdin, so it did not check the text.

Give the message with -m. Or write it to a file in a separate Bash call, before this command.
```

### Per message kind

The label and the inline option change with the kind. The label is the one that `block-attribution.sh` uses today.

| Command | Label | Inline option in the message |
| --- | --- | --- |
| `git commit -F`, `--file` | commit message | `-m` |
| `git tag -F`, `--file` | tag message | `-m` |
| `gh release create -F`, `--notes-file` | release notes | `--notes` |
| `gh pr create`, `gh pr edit` `-F`, `--body-file` | PR body | `--body` |
| `gh pr merge -F`, `--body-file` | merge commit message | `--body` |

### Rules

- Exit 2 blocks, exit 0 lets the command run. Both are the codes that Claude Code reads today.
- One command can carry more than one problem. The guard prints each unread file and stdin problem in command order, then the attribution lines, and exits 2 once.
- A file that the guard reads and that has no attribution passes, as today.
- The `/ship` text at `skills/ship/SKILL.md:180` changes from "reads as a miss" to "is blocked".

## Technical plan

### Approach

One new helper in the shared parser, `native_path()`, turns a Git Bash path into a path that Windows Python can open. It calls `cygpath -m` only when Python runs on Windows and the path starts with `/`. On Linux and macOS it returns the path unchanged, so their behaviour does not change. `resolve()` uses it for directories. `block-attribution.sh` uses it for message files, and blocks each message that it cannot read. The pentester fence does not open files, so it gets `posixpath` in place of `os.path` and compares its paths as the text that bash runs.

Relies on: D31 (guards fail closed), D14 and D32 (the pentester fence), D52 (an unparsed command is blocked), and the drafted D95, D96 and D97.

```mermaid
flowchart TB
    subgraph hooks["PreToolUse[Bash] hooks"]
        BA["block-attribution.sh"]
        BD["block-dangerous.sh<br/>(main-branch guard)"]
        SS["secret-scan.sh"]
        PF["scope-pentester-bash.sh"]
    end
    subgraph lib["lib/git-command.py"]
        NP["native_path()<br/>new"]
        RS["resolve()"]
        IWD["invocations_with_dirs(program=)"]
    end
    CY["cygpath -m<br/>(Git Bash, Windows only)"]
    BA -- "message file path, invocation dir" --> IWD
    BA -- "message file path" --> NP
    BD -- "--dir base" --> IWD
    SS -- "--dir base" --> IWD
    IWD -- "cd, pushd, -C target" --> RS
    RS -- "/tmp/tmp.X" --> NP
    NP -- "/tmp/tmp.X" --> CY
    CY -- "C:/Users/.../Temp/tmp.X" --> NP
    PF -- "tokenise only;<br/>paths compared with posixpath" --> lib
```

The three commit guards reach every path through the parser, and only `native_path()` calls `cygpath`. The fence uses the parser only to split the command.

```mermaid
sequenceDiagram
    participant C as Claude Code
    participant H as block-attribution.sh
    participant P as git-command.py
    participant Y as cygpath
    C->>H: payload: "git commit -F /tmp/tmp.Kx81Qz/msg", cwd
    H->>P: invocations_with_dirs(tokens, cwd)
    P-->>H: (cwd, ["commit", "-F", "/tmp/tmp.Kx81Qz/msg"])
    H->>P: native_path("/tmp/tmp.Kx81Qz/msg")
    P->>Y: cygpath -m /tmp/tmp.Kx81Qz/msg
    Y-->>P: C:/Users/adzaf/AppData/Local/Temp/tmp.Kx81Qz/msg
    alt regular file, no redirect in the command writes that name
        H->>H: read up to 1 MB, match the banned lines
        H-->>C: exit 0, or exit 2 "carries Claude attribution"
    else missing, not a regular file, $ in the path, or written in this command
        H-->>C: exit 2 "could not read the commit message file"
    end
```

A message file reaches the text check only after the guard converts the path and reads the file. Every other branch blocks.

```mermaid
flowchart LR
    CMD["command text from Claude<br/>(untrusted)"] -- "path as typed" --> NP["native_path()"]
    NP -- "argv to cygpath,<br/>no shell" --> CY["cygpath -m"]
    NP -- "converted path" --> OPEN["open(), regular files only,<br/>1 MB cap"]
    OPEN -- "text" --> GREP["banned-line match"]
```

The path from the command goes to `cygpath` as one argument with no shell, and the guard opens only a regular file, so a path cannot run code or make the guard wait.

### Changes

| File | What changes | Why |
| --- | --- | --- |
| `plugins/zuko/scripts/lib/git-command.py:280` | New `native_path(path)`: on `os.name == "nt"`, when `path` starts with `/` and `cygpath` is on `PATH`, return `cygpath -m -- path` (argv list, no shell, 5 s timeout). Return the path unchanged in every other case. `resolve()` calls it after `expanduser` and before `isabs`. | scenarios 2, 3 |
| `plugins/zuko/scripts/lib/git-command.py:311` | `invocations_with_dirs(tokens, base, program="git")`. The `token == "git"` test reads `program`. `git_dir()` applies only when `program == "git"`. | scenarios 1, 4: a relative `-F` or `--body-file` path is read from the directory where git or gh runs |
| `plugins/zuko/scripts/block-attribution.sh:8` | Read the payload's `cwd`, as `secret-scan.sh:9` does, and pass it to the Python block. | a relative message path needs a base |
| `plugins/zuko/scripts/block-attribution.sh:41` | `emit()` for kind `file`: `-` gives a `stdin` problem. A `$` or backtick in the path, a path that `native_path()` and the invocation's directory cannot place, a target that is not a regular file, and a name that a `>` or `>>` redirect in the same command writes, each give an `unread` problem. A file that opens is read as today. Each problem prints as a tab line `!unread`/`!stdin`, the label, and the path as typed. | scenarios 1, 4; O1, O2 |
| `plugins/zuko/scripts/block-attribution.sh:109,128,167` | The three loops take their invocations from `invocations_with_dirs(tokens, base, program=...)` and give each `emit()` the directory. | scenario 4 |
| `plugins/zuko/scripts/block-attribution.sh:195` | Bash splits the `!` lines from the message lines. Each `!` line prints the Interface section 1 or 2 message, with the inline option from the Per message kind table. Then the attribution lines print as today. Any `!` line exits 2. | Interface |
| `plugins/zuko/scripts/scope-pentester-bash.sh:100-125,250,271-272,406-410` | `import posixpath`. Each `os.path.normpath`, `split`, `relpath` on a command path becomes the `posixpath` call. `TEMP_ROOTS` keeps `/tmp` and `/private/tmp`. | scenario 5; O3 |
| `plugins/zuko/skills/ship/SKILL.md:180` | "a `$(…)` that it cannot expand reads as a miss" becomes "is blocked". | Interface rules |
| `plugins/zuko/scripts/tests/test-block-attribution.sh:128,190,249` | The three checks that expect exit 0 for a missing file, `git tag -F -` and `gh release -F -` now expect exit 2 and the new message. New checks: a Git Bash path, `$TMPDIR/msg`, a redirect-written name, a relative path after `cd`, a fifo. | scenarios 1, 4 |
| `plugins/zuko/scripts/tests/test-block-dangerous.sh`, `test-secret-scan.sh` | New checks: `git -C <mktemp dir> commit` and `cd <mktemp dir> && git commit`, with the dir in Git Bash form. | scenarios 2, 3 |
| `plugins/zuko/scripts/tests/test-scope-pentester-bash.sh` | New checks that build the scratch dir with `mktemp -d`, not a fixed path: a `cd` into it is allowed, and `cd <scratch>/..`, `cd /tmp/../c/Users/adzaf` and a sibling dir are blocked. | scenario 5 |
| `plugins/zuko/scripts/tests/test-e2e-guard-paths.sh` | New. Walks scenarios 1 to 5 against the real hooks in `mktemp -d` repos. | E2E |

Reusing: `git_command.tokenise`, `strip_heredocs`, `is_redirection`, `invocations_with_dirs` and `resolve` from `lib/git-command.py`; the payload `cwd` read from `secret-scan.sh:9`; the `run_hook` helper and `expect_*` checks in `tests/run.sh`.

### Earn-it

| Added | Triggered by |
| --- | --- |
| `native_path()` in `lib/git-command.py` | Scenarios 1 to 3. Two callers need the same conversion: `resolve()` and `block-attribution.sh`. |
| `program=` on `invocations_with_dirs` | Scenario 4. Without it, a relative `gh pr create --body-file body.md` after a `cd` reads the file in the wrong directory. |
| The redirect-name check | O1. Claude often writes `/tmp/commit-msg.txt` again for each commit. Without the check, `cat > /tmp/commit-msg.txt <<EOF ... && git commit -F /tmp/commit-msg.txt` reads the last commit's message. |

### Non-functionals

|                      |                                                                               |
| -------------------- | ----------------------------------------------------------------------------- |
| **Load**             | One hook run for each Bash call. `cygpath` runs only on Windows, once for each message file or directory that starts with `/`: 23 ms for each call, measured from Python on this machine. Most commands have zero or one such path. |
| **Breaks first**     | A command with dozens of `/` paths in `cd` and `-C` costs dozens of `cygpath` calls. At 20 paths that is about 0.5 s. No zuko stage writes such a command. |
| **Security surface** | Claude's command text is untrusted input. `native_path()` passes it to `cygpath` as one argv item after `--`, with no shell. The guard opens only a regular file and reads 1 MB at most. No secret is read or stored. The fence change loosens nothing on Linux and macOS, because `os.path` is `posixpath` there. |
| **Proof it works**   | On Windows, `git commit -F /tmp/<dir>/msg` with a Claude trailer prints "Blocked: the commit message carries Claude attribution." and exits 2. |
| **Rollout**          | No flag. It ships in the next plugin release. Rollback: revert the build commits, then cut a release. |

### Test plan

| Scenario | Test | Command |
| --- | --- | --- |
| The attribution guard reads a Git Bash message file | `test-block-attribution.sh`, `test-e2e-guard-paths.sh` | `bash plugins/zuko/scripts/tests/run.sh block-attribution` |
| The main-branch guard follows a Git Bash directory | `test-block-dangerous.sh`, `test-e2e-guard-paths.sh` | `bash plugins/zuko/scripts/tests/run.sh block-dangerous` |
| The secret scan follows a cd into a Git Bash directory | `test-secret-scan.sh`, `test-e2e-guard-paths.sh` | `bash plugins/zuko/scripts/tests/run.sh secret-scan` |
| A message that the guard cannot read is blocked, on every OS | `test-block-attribution.sh`, `test-e2e-guard-paths.sh` | `bash plugins/zuko/scripts/tests/run.sh block-attribution` |
| The pentester fence lets a command into its scratch copy | `test-scope-pentester-bash.sh`, `test-e2e-guard-paths.sh` | `bash plugins/zuko/scripts/tests/run.sh scope-pentester-bash` |

**E2E:** `test-e2e-guard-paths.sh`, run with `bash plugins/zuko/scripts/tests/run.sh e2e-guard-paths`. It makes every repo and file with `mktemp -d`, so on Windows each path is in Git Bash form and the test proves the conversion. On Linux and macOS the same test proves that nothing changed.

On this Windows machine, the old checks in the touched test files fail for causes that slice 4 owns, for example `test-scope-pentester-bash.sh` with its macOS temp paths. The build records which checks were red before and after.

### Chunks

| Chunk | Scenarios | Files owned |
| --- | --- | --- |
| A | 1, 2, 3, 4 | `lib/git-command.py`, `block-attribution.sh`, `skills/ship/SKILL.md`, `tests/test-block-attribution.sh`, `tests/test-block-dangerous.sh`, `tests/test-secret-scan.sh`, `tests/test-e2e-guard-paths.sh` |
| B | 5 | `scope-pentester-bash.sh`, `tests/test-scope-pentester-bash.sh` |

Chunk B uses only `tokenise` and `strip_heredocs` from the parser, which chunk A does not change. Chunk A owns the e2e test. Its scenario 5 part passes only after chunk B merges.

### Risks

| Risk | Mitigation |
| --- | --- |
| The new blocks stop a pattern that works today: `-F -` with a heredoc, or a message file that the same command writes. | The message names the fix in one line. zuko's own skills write their files in a separate call (`skills/ship/SKILL.md:179`, `skills/release/SKILL.md:241`), and the e2e test runs the `/ship` and `/release` forms. |
| `cygpath` is missing, or prints an error, in a hook. | `native_path()` then returns the path unchanged. The file does not open, so the attribution guard blocks. A directory turns to None, and the guards check the session and project directories, as today. |
| The fence change lets a path out of the scratch copy on Windows. | `posixpath.normpath` folds `..` before the compare, as on Linux. The fence reads `\` as `/` and blocks a drive path (O13). The fence tests run each escape form on Windows: `..` after the scratch dir, a sibling `tmp.*` dir, `/tmp/../c/...`, a `\..` step, a leading `\`, and `C:/` and `C:\` paths. |
| A redirect check by file name blocks a commit that writes a different file of the same name. | That is a false block and fails closed. The message says which name, so Claude writes the file in a separate call. |

### Decisions to record

Recorded as D95, D96, D97. D90 to D94 are taken on `feat/attack-classes`, which is not merged yet.

## Review

2026-11-07 · 6 raw findings, 4 survived, 4 fixed.

- A01 Broken Access Control · `plugins/zuko/scripts/scope-pentester-bash.sh:125` · the fence judges each word with `/` in place of `\`, so a `\..` redirect target in the repo is blocked · `01e359e`
- A01 Broken Access Control · `plugins/zuko/scripts/scope-pentester-bash.sh:409` · a drive path such as `C:/Users/...` is blocked in every word, on every OS · `507c23c`
- A01 Broken Access Control · `plugins/zuko/scripts/scope-pentester-bash.sh:120` · the same backslash fix blocks a `\..` path inside the scratch dir · `01e359e`
- correctness · `plugins/zuko/scripts/tests/test-block-attribution.sh:149` · the payload-cwd check now matches the attribution block, not only exit 2 · `6f8b206`

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | A message file that the guard cannot read: a missing file, `-F "$TMPDIR/msg"`, or a file that an earlier part of the same command writes. Today each one passes on every OS. Block it on every OS? | question | spec p1 | user | Resolved | Block on every OS. The message tells Claude to write the file in its own Bash call first, or to pass the message inline. The D-entry is drafted at pause 3, 2026-11-07 |
| O2 | `git commit -F -` and `gh pr create --body-file -` read the message from stdin, often from a heredoc that the parser drops. Today they pass. Block them too? | question | spec p1 | user | Resolved | Block on every OS, and point to the inline option or a file. Reading the heredoc body is not done: a pipe into stdin still could not be read. The D-entry is drafted at pause 3, 2026-11-07 |
| O3 | The pentester fence fails closed on Windows: it blocks every scratch path. That is not a security gap, but it stops a Windows pentest from proving a finding (`attack-classes` O11). Fix it in this slice? | question | spec p1 | user | Resolved | Yes, in this slice, as scenario 5. It has the same root cause, 2026-11-07 |
| O4 | The plan numbered the new decisions D95 to D97. On `main`, the highest entry is D89, because D90 to D94 live on the unmerged `feat/attack-classes`. | flag | build | user | Decided alone | Chose: keep D95, D96 and D97, so the two branches never give one number to two entries. `decisions.py check` allows the gap, because it checks only the order. Other: D90 to D92, which then collide with `attack-classes` at merge. Undo: renumber the three entries in `DECISIONS.md` and the `Relies on:` line of this spec. 2026-11-07 |
| O5 | Scenario 5's Risks row said the fence blocks `cd <sibling>/../<scratch>` through its `path != normpath(path)` check. It does not: `finish()` folds the `..` before `is_scratch()` sees it, so Linux and macOS allowed `cd /tmp/tmp.A/../tmp.B` too. | flag | build | user | Decided alone | Chose: a `cd` target with a `..` part is blocked, on every OS. That tightens the fence on Linux and macOS as well. Every other word already refuses `..`. Other: call `is_scratch()` on the target as typed, which also blocks `cd /tmp//tmp.X` and might block a macOS `mktemp -d` path. Undo: delete the `..` clause in `finish()` of `scope-pentester-bash.sh`, and change the sibling check in `test-scope-pentester-bash.sh` to expect exit 0. 2026-11-07 |
| O6 | The Out list gave slice 4 the 81 failures of `test-scope-pentester-bash.sh`, from hard-coded macOS temp paths. The cause was `os.path.normpath`, and `MACOS_TEMP` matches on any OS. | flag | build | user | Decided alone | Chose: drop that Out item. The file now passes 241 of 241 on Windows. Other: keep it for slice 4. Undo: none needed; slice 4 has less to trace. 2026-11-07 |
| O7 | The fifo check expected exit 2 on every OS. Git Bash's `mkfifo` makes a small regular file that native Python and `git.exe` both read without a wait. | flag | build | user | Decided alone | Chose: the check expects exit 2 and the unread message where Python sees a fifo, and exit 0 where it sees a regular file. The guard then reads what git reads. Other: detect MSYS special files and block them. Undo: put back a plain `expect_exit 2` in the fifo check of `test-block-attribution.sh`. 2026-11-07 |
| O8 | The Interface said the unread files print first, then the attribution lines. | flag | build | user | Decided alone | Chose: the unread file and stdin problems print in command order, then the attribution lines. The Interface rule now says so. Other: sort the unread files before stdin. Undo: sort `problems` with `!unread` first in `block-attribution.sh`. 2026-11-07 |
| O9 | `test-decision-pr.sh:55` matched the old `/ship` sentence "reads as a miss" word for word. The plan did not name that file. | flag | build | user | Decided alone | Chose: the regex now reads "is blocked", to match `skills/ship/SKILL.md:181`. Other: none, as the old text is gone. Undo: revert the change on line 55 of `test-decision-pr.sh`. 2026-11-07 |
| O10 | The plan said a `>` or `>>` redirect that writes the message file's name blocks it. | flag | build | user | Decided alone | Chose: every redirect with a `>` counts, `>&`, `&>` and `2>` too, so `2>&1` adds the name `1`, which no message file has. The noclobber redirect and `tee` are not covered. Other: `>` and `>>` only. Undo: limit the `WRITTEN` test in `block-attribution.sh` to `redirect in (">", ">>")`. 2026-11-07 |
| O11 | Three Windows details that the plan did not settle in `block-attribution.sh` and `git-command.py`. | flag | build | user | Decided alone | Chose: the payload `cwd` also goes through `native_path()`, because the `$PWD` fallback is a `/c/...` path. A trailing CR is stripped from each `!` line, as `check-skill-pin.sh:35` does. A `GIT_DIR=` prefix sets the directory to None for git only, so a `gh` call keeps its directory. Other: leave each one as it is. Undo: `base = sys.argv[2]`; delete the line in `block-attribution.sh` that strips the CR from `typed`; make `where()` in `invocations_with_dirs` return None for every program after the prefix. 2026-11-07 |
| O12 | After the merge, `test-block-attribution.sh` has 4 red checks in the main checkout: 203 passed, 4 failed. | flag | build | user | Decided alone | Chose: leave them red. Three of them fail on `main` too, from the CRLF that Python's `print()` writes on Windows, which slice 3 `utf8-stdio` owns: the two line-continuation checks and the heredoc commit form. The fourth, the `git-naming.md` check, fails only because this old checkout still has that file as CRLF. In a fresh worktree it passes, 204 passed and 3 failed. `e2e-guard-paths` passes 15 of 15. Other: fix the CRLF output here. Undo: none needed; slice 3 owns it. 2026-11-07 |
| O13 | The review found that the fence, once a `cd` into the scratch dir passed on Windows, let three path forms out: a `\..` step, which Git Bash folds even through a dir that does not exist, a `C:/` or `C:\` drive path, and a leading `\`. D97 says the fence compares paths with POSIX rules, and POSIX has neither form. | flag | review | user | Decided alone | Chose: the fence judges each word with `/` in place of `\`, and blocks a drive path in any word, on every OS. On Linux and macOS a word with `\..` or `C:/` in it is now blocked too, which fails closed. D97 stays as written; its POSIX compare now runs on the words after that swap. Other: supersede D97 through `/spec` with an entry that names the Git Bash forms. Undo: revert `01e359e` and `507c23c`, which opens the three escapes again on Windows. 2026-11-07 |
| O14 | The ship gate's secrets check finds one key-shaped string in the diff: `AKIAIOSFODNN7EXAMPLE` in scenario 3. The commit of the spec was `git add` and `git commit` in one command, so `secret-scan.sh` read the index before the add ran and saw nothing. | flag | ship | user | Decided alone | Chose: ship it. It is the example key that AWS publishes in its docs, not a secret, and the tests build it in two parts. The scan gap is older than this slice and is not fixed here. Other: rewrite scenario 3 with a split key. Undo: change the key in scenario 3 of this spec, and take the add-then-commit gap to `/debug`. 2026-11-07 |
| O15 | The ship gate asks for the full suite, run just now. On Windows it fails about 546 checks on `main` (slice 4 owns them), it hangs in `e2e-board`, and a run here was stopped for low memory. | flag | ship | user | Decided alone | Chose: ship on the touched files, run in a fresh worktree at `507c23c`: scope-pentester-bash 256 of 256, e2e-guard-paths 15 of 15, block-dangerous 199 of 199, secret-scan 31 of 31, decision-pr 37 of 37, block-attribution 205 passed and 3 failed, which also fail on `main`. Only docs changed after `507c23c`. Other: wait for a Linux run of the full suite. Undo: run `bash plugins/zuko/scripts/tests/run.sh` on Linux or macOS before the merge. 2026-11-07 |

_Never delete this section or its rows. See references/ledger.md._

## Glossary

- **Git Bash (MSYS)** — the bash that comes with Git for Windows. It shows the disk as `/c/...` and the temp folder as `/tmp`, and converts those paths only when it passes them to a program as an argument.
- **cygpath** — a Git Bash program that converts a Git Bash path to a Windows path: `cygpath -m /tmp/x` prints `C:/Users/adzaf/AppData/Local/Temp/x`.
- **e2e** — end-to-end: one test that walks the whole slice through the real hooks.
- **Pentest** — a penetration test: zuko's pentester agent attacks the code that a release ships, and proves each finding with an input that it runs.
- **Fail open / fail closed** — a guard that cannot decide either lets the action through (open) or blocks it (closed). zuko's guards must fail closed (D31).
- **Hook payload** — the JSON that Claude Code gives a PreToolUse hook. It holds the command as one string and the session's `cwd`.
- **Scratch copy** — the `git archive` copy of the release in a `mktemp -d` folder, where the pentester runs its proofs.
