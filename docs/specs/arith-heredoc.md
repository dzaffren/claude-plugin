# Arith heredoc

**Version:** v1 · **Status:** Built · **Type:** Bug · **Project type:** CLI/Library

**Depends on:** `fail-closed-parse` — this adds a second thing the walk refuses

The shared parser refuses a `<<` inside `(( ))`, `$(( ))`, `$[ ]` or `${ }`,
where bash reads it as a shift, so it no longer hides the lines after it from
the guards. Found by the v2.4.1 pentest; fixed through `/debug`.

## Problem

`openers_in` in `lib/git-command.py` read every unquoted `<<` as a heredoc
opener. Inside arithmetic and `${ }`, bash reads `<<` as a bit shift and runs
the next line. The parser dropped that line as a heredoc body, up to a line
equal to the word after `<<`. Each row has a force push on line 2 and `X` on
line 3. Run against `main` at `0e1abfa` (v2.4.1) on 2026-10-13; v2.4.0 gives
the same result:

| Line 1                                            | bash runs line 2 | Parser exit | Parser sees line 2 |
| ------------------------------------------------- | ---------------- | ----------- | ------------------ |
| `(( 1 << X ))`                                    | yes              | 0           | no                 |
| `x=$(( 1 << X ))`                                 | yes              | 0           | no                 |
| `x=$[ 1 << X ]`                                   | yes              | 0           | no                 |
| `echo ${V:1<<X}`                                  | yes              | 0           | no                 |
| `for (( i = 1 << X; i < 0; i++ )); do :; done`    | yes              | 0           | no                 |
| `((cat << X); (true))`                            | no, a heredoc    | 0           | no                 |

`block-dangerous.sh` greps the parser's output for a force push, so it exited 0.

```
(( 1 << X ))                  bash: a shift, then runs line 2
git push --force origin main
X
      │
      ▼
openers_in: any unquoted << is a heredoc ──► drops lines 2-3
      │
      ▼
tokenise sees no push ──► block-dangerous.sh exits 0
```

The last row is why the walk cannot skip the brackets: bash tries `((` as
arithmetic, fails, and reads it again as two subshells and a real heredoc.

## Slice test

| Check                         | Result                                                              |
| ----------------------------- | ------------------------------------------------------------------- |
| Cuts every layer it needs     | yes — the parser and the hook's test                                |
| One e2e test walks it         | yes — `test-block-dangerous.sh` feeds each command to the real hook |
| Worth shipping alone          | yes — closes a force-push bypass                                    |
| Fits (≤5 scenarios, ≤2 areas) | yes — 3 scenarios, 1 area (hook and gate scripts)                   |

**Path:** light — a bug fix in one function plus its tests, with no new
interface, data or dependency.

## Acceptance criteria

```gherkin
Scenario: a << inside arithmetic or an expansion is refused
  Given a command whose line 1 is (( 1 << X )), x=$(( 1 << X )), x=$[ 1 << X ],
    echo ${V:1<<X}, a for (( )) loop with 1 << X, or ((cat << X); (true))
  And line 2 is git push --force origin main, and line 3 is X
  When block-dangerous.sh sees it
  Then it exits 2
  And the block says "cannot tell whether this << starts a heredoc"

Scenario: a stray closer or a backslash-newline does not end the count
  Given line 1 is echo ${V:-)<<X}, or x=$( and a backslash-newline before ( 1 << X ))
  And line 2 is git push --force origin main, and line 3 is X
  When block-dangerous.sh sees it
  Then it exits 2

Scenario: a heredoc after the arithmetic, and a quoted <<, still parse
  Given (( 1 )) && cat << X, or x=$(( (1 + 2) * 3 )); cat <<X, with a body and X
  Or echo "$(( 1 << 2 ))"
  When the parser reads it, with a force push after
  Then it prints the push
```

## Scope

**In:** `openers_in` and `strip_heredocs`'s walk state; the tests that prove it.

**Out:**

- A heredoc inside a double-quoted command substitution hides the lines after
  it in the same way. See O2.
- `secret-scan.sh` and `block-attribution.sh` still check the raw text when the
  parser refuses (D52). `block-dangerous.sh` runs on every Bash call and blocks.

## Technical plan

### Approach

`openers_in` carries a stack, `closers`, in the walk state from line to line.
Outside quotes, `((`, `$((`, `$[` and `${` push the bracket that closes them.
While the stack is not empty, an opener of the top's kind pushes again, and
the top's closer pops it; a bracket of another kind is text. A `<<` (not
`<<<`) while the stack is not empty raises `ValueError`, so the parser exits 3,
and `block-dangerous.sh` blocks the command (D52).

The walk reads one line at a time, but bash joins lines at a backslash-newline.
The walk keeps the character before one, `tail`, and refuses the command when
it and the next line's first character make `((`, `$(`, `${`, `$[` or `<<`.

Relies on: D52, D53.

### Changes

| File                                                 | What changes                                                     | Why            |
| ---------------------------------------------------- | ---------------------------------------------------------------- | -------------- |
| `plugins/zuko/scripts/lib/git-command.py:152`        | `openers_in` keeps a stack of brackets and refuses a `<<` inside them | scenarios 1, 2 |
| `plugins/zuko/scripts/lib/git-command.py:114`        | `openers_in` refuses an opener split by a backslash-newline           | scenario 2     |
| `plugins/zuko/scripts/tests/test-block-dangerous.sh` | eleven refused forms through the hook, five forms that still parse    | scenarios 1-3  |

### Non-functionals

|                      |                                                                                              |
| -------------------- | -------------------------------------------------------------------------------------------- |
| **Load**             | unchanged; one more check for each character outside quotes                                  |
| **Breaks first**     | a real shift such as `echo $((1<<3))` is blocked. None of 9,338 recorded commands changed     |
| **Security surface** | closes the v2.4.1 pentest's rejected finding: a force push after `(( 1 << X ))`              |
| **Proof it works**   | `bash plugins/zuko/scripts/tests/run.sh block-dangerous` gives 165 passed                    |
| **Rollout**          | no flag: a hook script. Rollback is `git revert` of the fix commit                            |

### Test plan

**E2E:** `bash plugins/zuko/scripts/tests/run.sh block-dangerous` pipes each
command as a real hook payload into `block-dangerous.sh`. The eleven refused
forms failed before the fix (exit 0) and pass after it. The full suite gives
2400 passed, 0 failed.

### Decisions to record

Recorded as D55.

## Review

2026-10-13 · 2 raw findings, 2 survived, 2 fixed.

- correctness · `plugins/zuko/scripts/lib/git-command.py:156` · a bracket closes only its own kind, so the `)` in `${V:-)<<X}` no longer ends the count · `d72512d`
- correctness · `plugins/zuko/scripts/lib/git-command.py:114` · refuse a backslash-newline that splits `$((`, `${`, `$[` or `<<` · `546782c`

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | The walk cannot tell a shift from a heredoc inside `((`. Refusing it blocks a real shift such as `echo $((1<<3))`. | flag | /debug | user | Decided alone | Chose: refuse a `<<` inside `(( ))`, `$(( ))`, `$[ ]` or `${ }`; none of 9,303 recorded commands changed. Other: read it as a shift, which lets `((cat << X); (true))` hide a heredoc body. Undo: git revert 546782c d72512d 5c7c20f, newest first. 2026-10-13 |
| O2 | `/debug` found a second gap of this kind: a heredoc inside a double-quoted command substitution, `echo "$(cat <<EOF` with a quote in its body, hides the lines after it. bash runs them, and the parser exits 0. v2.4.1 has it too. | flag | /debug | user | Decided alone | Chose: leave it out of this fix, which reads `<<` outside quotes only. Other: fix both here. Undo: run /zuko:debug on it. 2026-10-13 |
| O3 | `/review`: a backslash-newline between `$(` and `(` makes `$((` for bash, but the walk reads one line at a time and started no count. | flag | review | user | Decided alone | Chose: refuse the command when a backslash-newline splits `((`, `$(`, `${`, `$[` or `<<`, which also blocks a rare `$` then `(cmd)` split. Other: join the continued lines before the walk, which costs time that grows with the square of the joined lines (D51). Undo: git revert 546782c. 2026-10-13 |

_Never delete this section or its rows. See references/ledger.md._

## Glossary

- **Pentest** — the security test `/release` runs on the code it ships
- **e2e** — end-to-end: one test that walks the whole slice as a user would
- **Bit shift** — `1 << 3` moves the bits of 1 left by 3 places, which gives 8
- **Command substitution** — `$( … )` runs a command and puts its output there
