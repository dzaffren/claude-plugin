# Tokenise linear

**Version:** v1 · **Status:** Built · **Type:** Bug · **Project type:** CLI/Library

**Depends on:** None

The command parser that six guards share refuses a command over 64 KB, so no
guard spends more than about 0.15 s parsing one. `block-dangerous.sh` blocks
a long command at once, and the flaky test that blocks `/release` stops.

## Problem

`git-command.py`'s `tokenise` is Python's `shlex`. `shlex` grows each word with
`self.token += nextchar` (`shlex.py:194`), so the parse time grows with the
square of a word's length.

| Input | `tokenise` | Guard on a 1.1 MB command |
| --- | --- | --- |
| 64 KB | 0.14 s | — |
| 128 KB | 0.32 s | — |
| 256 KB | 0.98 s | — |
| 1.1 MB | about 16 s | `scope-verifier-bash.sh` 19.6 s, `block-dangerous.sh` 21 s |

Two effects:

- `test-scope-verifier-bash.sh:176` gives the guard 20 s, so it fails about one
  run in two, on `main` too. `release.py plan` runs the suite, so `/release`
  is refused about half the time (2026-10-13).
- A hook that runs past its timeout does not block the call: "A timed-out
  `command`, `http`, or `mcp_tool` hook doesn't block the tool call"
  (code.claude.com/docs/en/hooks). The default timeout is 600 s, and
  `hooks.json` sets none. A long enough command would pass every guard
  unchecked. The size that reaches 600 s is about 6 to 7 MB, extrapolated and
  not measured.

## Slice test

| Check | Result |
| --- | --- |
| Cuts every layer it needs | yes. The shared parser, and the guards that call it through their existing refusal paths. |
| One e2e test walks it | yes. Real hook payloads of 1.1 MB, sent to `scope-verifier-bash.sh` and `block-dangerous.sh`. |
| Worth shipping alone | yes. `/release` stops failing on this test, and no guard can be timed out by a long command. |
| Fits (≤5 scenarios, ≤2 areas) | yes. 5 scenarios. One area: the shared parser and the tests of two of its callers. |

**Path:** light. A bug fix in three files, with no new interface, data or
dependency. Pauses 1 and 3 are one pause, and pause 2 is skipped.

## Flow

```mermaid
flowchart LR
    C["Bash command<br/>from Claude"] -- "hook payload" --> G["a guard:<br/>block-dangerous.sh, scope-verifier-bash.sh, ..."]
    G -- "command text" --> T["git-command.py<br/>tokenise"]
    T -- "64 KB or less:<br/>tokens" --> V["the guard's normal checks"]
    T -- "over 64 KB:<br/>TooLong, at once" --> R["block-dangerous.sh: block.<br/>Agent guards: block."]
    V -- "allow or block" --> C
    R -- "exit 2" --> C
```

Each guard parses as today up to 64 KB. Over that, `tokenise` raises
`TooLong`, a kind of `ValueError`, at once. `block-dangerous.sh` blocks the
command. It runs on every Bash call, so its block also covers the guards that
fall back to raw text (O4).

| Guard | Over the limit |
| --- | --- |
| `block-dangerous.sh:25` | Blocks: "this command is over 65536 characters". |
| `secret-scan.sh:15` | Falls back to raw text, as for any unparsed command. `block-dangerous.sh` blocks the call. |
| `block-attribution.sh:36` | Falls back to raw text. `block-dangerous.sh` blocks the call. |
| `scope-verifier-bash.sh:85` | Blocks: "a command that will not parse". |
| `scope-pentester-bash.sh:98` | Blocks: "a command that will not parse". |
| `block-pentest-target.sh:220` | Blocks while a live pentest runs. |
| `release-commit.py:65`, `:100` | Refuses the release-commit exception, so the main-branch guard blocks. |

## Acceptance criteria

```gherkin
Scenario: A long verifier command is refused at once
  Given the finding-verifier sends "git show main:" and 1,100,000 more characters
  When scope-verifier-bash.sh reads the hook payload
  Then it exits 2 with "a command that will not parse" and "over 65536 characters"
  And it finishes in under 2 seconds, where today it takes 19.6 seconds

Scenario: A long main-thread command is blocked at once
  Given the main thread runs "git status" and 1,100,000 more characters
  When block-dangerous.sh reads the hook payload
  Then it exits 2 with "Blocked: this command is over 65536 characters"
  And it finishes in under 2 seconds, where today it takes 21 seconds

Scenario: A long force push in any form is still blocked
  Given the main thread runs "git -C . push --force origin main" and 1,100,000 more characters
  When block-dangerous.sh reads the hook payload
  Then it exits 2 with "Blocked: this command is over 65536 characters"

Scenario: A long heredoc body still parses
  Given the main thread runs "cat > notes.md <<'EOF'", a 200,000-character body, "EOF", then "git push --force origin main"
  When block-dangerous.sh reads the hook payload
  Then the body is removed before the size check, the command parses, and it exits 2 for the force push

Scenario: The release suite no longer fails on the verifier test
  Given the branch with this fix
  When run.sh scope-verifier-bash runs 5 times in a row
  Then all 5 runs pass, where on main 1 run of 2 failed on 2026-10-13
```

## Scope

**In:**

- `tokenise` raises `TooLong`, a kind of `ValueError`, for a command over
  65,536 characters after the heredoc bodies and line continuations are
  removed. `git-command.py` exits 4 for it, and `block-dangerous.sh` blocks.
- The test of the 1.1 MB verifier `git show` expects a block, not an allow.
- New cases in `test-block-dangerous.sh` for scenarios 2 to 4.

**Out:**

- A rewrite of `shlex` that parses any size in linear time. D51 rejects it.
- `"onFailure": "block"` on the guard hooks. No slice picks it up (O3).
- Raising the test's 20 s alarm. The guard would still take 20 s.

## Technical plan

### Approach

One check at the top of `tokenise`, after it removes the line continuations:
over the limit, raise `TooLong`, a kind of `ValueError`. The agent guards
catch it as a `ValueError` and block. `git-command.py`'s `main` exits 4 for it,
and `block-dangerous.sh` blocks on 4. `strip_heredocs` runs before `tokenise`
at every call site, so a long heredoc body never counts.

```mermaid
flowchart TB
    SV["scope-verifier-bash.sh:83"] -- "tokenise(strip_heredocs(cmd))" --> T["lib/git-command.py<br/>tokenise"]
    BD["block-dangerous.sh:25"] -- "stdin to main()" --> M["lib/git-command.py<br/>main"]
    M -- "tokenise(strip_heredocs(cmd))" --> T
    T -- "over 65,536 characters" --> E["TooLong"]
    E -- "caught as ValueError: block" --> SV
    M -- "exit 4" --> BD
    BD -- "deny" --> BD
```

The verifier guard catches the error and blocks. `block-dangerous.sh` gets
exit 4 from `main` and blocks. A short command that will not parse still gets
exit 3 and the raw-text checks, because bash cannot run it either.

```mermaid
sequenceDiagram
    participant H as Claude Code
    participant B as block-dangerous.sh
    participant P as git-command.py main
    H->>B: payload, "git -C . push --force origin main" + 1.1 MB
    B->>P: the command on stdin
    P->>P: strip_heredocs, then tokenise: over 65,536 characters
    P-->>B: exit 4, "the command is over 65536 characters"
    B-->>H: exit 2, "Blocked: this command is over 65536 characters"
```

Relies on: D31 (the commit guards fail closed on a payload they cannot read),
D9 (the verifier's Bash is scoped by a hook), and D51.

### Changes

| File | Change | Why |
| --- | --- | --- |
| `plugins/zuko/scripts/lib/git-command.py:105` | `MAX_COMMAND_CHARS = 65536` and `class TooLong(ValueError)`. `tokenise` raises `TooLong("the command is over 65536 characters")` when the text is longer, after `CONTINUATION.sub`. `main` exits 4 for it. | Scenarios 1 to 4. |
| `plugins/zuko/scripts/block-dangerous.sh:25` | On exit 4, deny: "Blocked: this command is over 65536 characters, too long to check. Put the long text in a heredoc or a file, then run it again." | Scenarios 2 and 3. O4. |
| `plugins/zuko/scripts/tests/test-scope-verifier-bash.sh:176` | The 1.1 MB verifier `git show` expects exit 2 and "over 65536 characters". The 20 s alarm stays. | Scenario 1. |
| `plugins/zuko/scripts/tests/test-block-dangerous.sh` | Long commands as hook payloads written to a file, as the `huge()` helper in `test-scope-verifier-bash.sh:164` does. An env var cannot hold 1.1 MB. Five forms, each blocked with the long-command message: `git status`, `git -C . push --force`, `git -C . commit`, `cd repo && git commit`, `git commit -F msg.txt`. | Scenarios 2 to 4. |

Reusing: each agent guard's `except ValueError` path, unchanged. The `huge()`
payload helper's file handoff.

### Earn-it

| Added | Triggered by |
| --- | --- |
| `MAX_COMMAND_CHARS` | Scenarios 1 to 3. A bound on the parse is what stops the 20 s guard and the timeout. |

### Non-functionals

| | |
| --- | --- |
| **Load** | A parse is 0.14 s at most, at the limit. `block-dangerous.sh` parses twice for each Bash call, so a main-thread call spends 0.3 s at most there. |
| **Breaks first** | A real command over 64 KB, with no heredoc, is blocked. The block message names the limit and says to use a heredoc or a file. |
| **Security surface** | The guards' input is Claude's command text. Over the limit, `block-dangerous.sh` and the agent guards block. No secret and no stored data. |
| **Proof it works** | `release.py plan` passes its test gate, and `run.sh scope-verifier-bash` passes 5 runs in a row. |
| **Rollout** | No flag. Rollback: `git revert` the fix commit. |

### Test plan

| Scenario | Test |
| --- | --- |
| 1. Verifier command refused | `test-scope-verifier-bash.sh`: the 1.1 MB `git show` case, exit 2 and the message. Its 20 s alarm bounds the time; the guard took 0.34 s. |
| 2. Main-thread long command blocked | `test-block-dangerous.sh`: a 1.1 MB `git status`, exit 2, the message, under 2 s. |
| 3. Long force push blocked | `test-block-dangerous.sh`: `git -C . push --force`, `git -C . commit`, `cd repo && git commit` and `git commit -F`, each 1.1 MB, exit 2 with the long-command message. |
| 4. Long heredoc body | `test-block-dangerous.sh`: `git-command.py` parses a 200,000-character body and a force push, exit 0, and prints `push --force origin main`. A 70,000-character command with no heredoc exits 4 and names the limit. A short unbalanced quote still exits 3. |
| 5. Release suite | Run `run.sh scope-verifier-bash` 5 times by hand, then `release.py plan`. |

```bash
bash plugins/zuko/scripts/tests/run.sh scope-verifier-bash
bash plugins/zuko/scripts/tests/run.sh block-dangerous
bash plugins/zuko/scripts/tests/run.sh
```

**E2E:** `test-block-dangerous.sh` and `test-scope-verifier-bash.sh` send real
hook payloads of 1.1 MB to the real guards.

### Chunks

Single chunk. The tests first, then the one line in `git-command.py`.

### Risks

| Risk | Mitigation |
| --- | --- |
| A real command over 64 KB, with no heredoc, is blocked. | The message says to put the long text in a heredoc or a file, which is not counted. |
| The raw-text fallback misses `git -C . push`, `cd other && git commit` and a `-F` message file. | Over the limit, `block-dangerous.sh` blocks instead of using the fallback (O4). A short command that will not parse keeps the fallback, because bash cannot run it either. |
| A caller that does not catch `ValueError` crashes on a long command. | Every caller catches it, and `TooLong` is a `ValueError`. A crash in a hook exits non-zero, and each guard script turns that into a block. |

### Decisions to record

Recorded as D51.

## Review

2026-10-13 · 4 raw findings, 3 survived, 3 fixed.

- A10 Mishandling of Exceptional Conditions · `plugins/zuko/scripts/lib/git-command.py:113` · a long `git -C . push --force` or `git -C . commit` is blocked, not checked as raw text · `43e994f`
- A10 Mishandling of Exceptional Conditions · `plugins/zuko/scripts/lib/git-command.py:113` · a long `cd other && git commit` is blocked before the secret scan falls back · `43e994f`
- A10 Mishandling of Exceptional Conditions · `plugins/zuko/scripts/lib/git-command.py:113` · a long `git commit -F` is blocked before the attribution check falls back · `43e994f`

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | A command is too long to parse quickly. Refuse to parse it over a limit, so each guard takes its own cannot-parse path, or parse every size with a new linear parser? | question | spec p1 | user | Resolved | Refuse over a limit. Each guard takes the cannot-parse path it already has, and no caller changes. 2026-10-13 |
| O2 | What is the limit, after heredoc bodies are removed? | question | spec p1 | user | Resolved | 64 KB: 65,536 characters after the heredoc bodies are removed. A parse takes 0.14 s at the limit. 2026-10-13 |
| O3 | Also set `"onFailure": "block"` on the guard hooks, so a hook that times out blocks the call? It needs Claude Code 2.1.295 or later; this machine has 2.1.296. | question | spec p1 | user | Resolved | No. With the limit, no guard runs near the 600 s timeout, and what older Claude Code versions do with the field is not known. 2026-10-13 |
| O4 | `/review`: scenario 2 said "Then it exits 0, because the raw text holds no force push, no recursive delete and no commit". The raw-text checks miss `git -C . push --force`, `cd other && git commit` and a `git commit -F` file, so a long command with any of these ran unchecked. | flag | review | user | Decided alone | Chose: `block-dangerous.sh` blocks every command over 64 KB, and the hook's block covers the other guards. Other: a parser with no limit that is linear for any size, the other answer to O1. Undo: git revert 43e994f, then spec the linear parser through /spec. 2026-10-13 |

_Never delete this section or its rows. See references/ledger.md._

## Glossary

- **Quadratic** — the time grows with the square of the input, so twice the
  input takes four times as long.
- **Fail closed** — a guard that cannot check a command blocks it.
- **Heredoc** — the `<<'EOF' … EOF` block that gives a command a long body
  from inside the command text.
- **e2e** — end-to-end: one test that walks the whole slice.
- **Pentest** — a penetration test: `/release` attacks the code it ships, and a
  live pentest sends real requests to a running app.
