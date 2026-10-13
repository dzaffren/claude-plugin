# Quoted subst heredoc

**Version:** v1 · **Status:** Built · **Type:** Bug · **Project type:** CLI/Library

**Depends on:** `arith-heredoc` — this closes the gap that its O2 left out

The shared parser refuses a heredoc inside a double-quoted `$( )` or
backticks when a line of its body changes the parser's quotes. Such a heredoc
no longer hides the lines after it from the guards. Found by the `/debug` of
`arith-heredoc`; fixed through `/debug`.

## Problem

`openers_in` in `lib/git-command.py` read all text inside `"…"` with the rules
for a double-quoted string. Inside `"$( )"`, bash reads a new command, and a
`<<` there opens a real heredoc. bash skips the quotes in its body. The parser
read them. One `"` in the body closed the parser's string, and the `"` after
the heredoc opened a new one. So the lines after the heredoc became text.

Each row is a heredoc inside `"$( )"` or backticks, with `say "hi` in its body. After the
`)"` line come a force push and a lone `"`. Run against `main` at `4ef85fe` on
2026-10-13, with bash 5.1.8; v2.4.1 gives the same result:

| Heredoc form                                      | bash runs the push | Parser exit | Parser sees the push |
| ------------------------------------------------- | ------------------ | ----------- | -------------------- |
| `echo "$(cat <<EOF`                               | yes                | 0           | no                   |
| `echo "$(cat <<'EOF'`                             | yes                | 0           | no                   |
| `echo "$(cat <<-EOF`, with a tab before `EOF`     | yes                | 0           | no                   |
| `` echo "`cat <<EOF ``, closed by `` ` ``          | yes                | 0           | no                   |
| `echo "$(cat <<EOF`, with an indented `EOF` first | yes                | 0           | no                   |
| `echo "$(cat <<\EOF`                              | yes                | 0           | no                   |
| `echo "$(cat <<EOF-1`, closed by `EOF-1`          | yes                | 0           | no                   |
| `echo "$(cat <<EOF`, with `foo\` before `EOF`     | yes                | 0           | no                   |

`block-dangerous.sh` greps the parser's output for a force push, so it exited 0.

```
echo "$(cat <<EOF             bash: a heredoc inside $( )
say "hi                       bash: body text, not a quote
EOF
)"
git push --force origin main  bash: runs it
"
      |
      v
openers_in: the " in the body ends the string --> the " in )" starts one
      |
      v
tokenise reads the push as text --> block-dangerous.sh exits 0
```

The body cannot be dropped, as other heredoc bodies are.
`block-attribution.sh` reads the commit body inside the `-m` word of the
standard commit form, `git commit -m "$(cat <<'EOF'`.

## Slice test

| Check                         | Result                                                              |
| ----------------------------- | ------------------------------------------------------------------- |
| Cuts every layer it needs     | yes — the parser and the tests of the two hooks that read it        |
| One e2e test walks it         | yes — `test-block-dangerous.sh` feeds each command to the real hook |
| Worth shipping alone          | yes — closes a force-push bypass                                    |
| Fits (≤5 scenarios, ≤2 areas) | yes — 3 scenarios, 1 area (hook and gate scripts)                   |

**Path:** light — a bug fix in two functions plus their tests, with no new
interface, data or dependency.

## Acceptance criteria

```gherkin
Scenario: a quote in a heredoc body inside "$( )" is refused
  Given a command with a heredoc inside "$( )" or backticks, and say "hi in its body
  And the delimiter is EOF, 'EOF' or a <<-EOF with a tab, or an indented EOF comes first
  And a force push and a lone " come after the )" line
  When block-dangerous.sh sees it
  Then it exits 2
  And the block says "cannot tell whether the lines after a heredoc"

Scenario: a body with no known end is refused
  Given the heredoc is <<\EOF, or <<EOF-1, or a body line foo\ comes before EOF
  And a force push and a lone " come after the )" line
  When block-dangerous.sh sees it
  Then it exits 2
  And the block says "cannot tell where a heredoc"

Scenario: the standard commit form still parses, with its body
  Given git commit -m "$(cat <<'EOF'" with a body that holds "quotes", it's, backticks and $(dollar)
  When the parser reads it
  Then it prints the commit, with the body in the -m word
  And block-dangerous.sh blocks it on main as a commit on main
  And block-attribution.sh blocks a Claude trailer in that body as the commit message
```

## Scope

**In:** `openers_in` and `strip_heredocs`, and the tests that prove them.

**Out:**

- A command inside a double-quoted `$( )` is never read, so
  `echo "$(git push --force origin main)"` passes the guard. See O3.
- A single quote inside `"$( )"`, as in `"$(echo 'a"b')"`, changes the
  parser's quotes in the same way, with no heredoc. See O3.
- The other heredoc path reads some delimiters differently from bash. See O4.
- A `"two words"` phrase in the commit body cuts the `-m` word. See O5.

## Technical plan

### Approach

Once the walk is lost, `openers_in` notes each `<<` inside double quotes in
the state, as `inner`. It notes the delimiter, whether it is `<<-`, and
whether it is quoted. It notes only the ones on a line outside such a body.
`strip_heredocs` keeps the body lines, so the `-m` word keeps its text.

For each body line, `strip_heredocs` compares the walk's state before and after
the line. A change raises `ValueError`, so the parser exits 3, and
`block-dangerous.sh` blocks the command (D52). The body ends at a line that is
exactly the delimiter, or the delimiter after tabs for `<<-`, as in bash.

The walk then needs no rule for where bash ends the body early. Inside backticks,
bash ends it at the next backtick, and bash 5.1 also ends it at a line `EOF)`.
Up to that point, each line left the state as it was. So bash and the walk are
both in the double-quoted string again. A later line that changes the state is
refused, so here the walk can only block too much.

The walk must not end a body before bash does, so it refuses:

- A delimiter that it does not read whole, such as `<<\EOF` or `<<EOF-1`.
- A backslash at the end of the line with the `<<`, or at the end of a body
  line when the delimiter is not quoted. bash joins the next line to it.
- A heredoc that the walk would drop, on the line with the `<<` or in the body.

Relies on: D52, D53, D55.

### Changes

| File                                                     | What changes                                                                          | Why            |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------- | -------------- |
| `plugins/zuko/scripts/lib/git-command.py:32`             | `INNER_HEREDOC` reads a delimiter only when a blank, `;&\|()<>` or the line end follows it | scenario 2     |
| `plugins/zuko/scripts/lib/git-command.py:140`            | `openers_in` notes each `<<` in double quotes once the walk is lost                      | scenarios 1, 2 |
| `plugins/zuko/scripts/lib/git-command.py:218`            | `strip_heredocs` refuses a body line that changes the state, or a body with no known end | scenarios 1, 2 |
| `plugins/zuko/scripts/tests/test-block-dangerous.sh:462` | eight refused forms through the hook, two forms that still parse, the commit form        | scenarios 1-3  |
| `plugins/zuko/scripts/tests/test-block-attribution.sh:451` | the commit form with and without a Claude trailer through the hook                     | scenario 3     |

### Non-functionals

|                      |                                                                                                                        |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| **Load**             | unchanged; one compare of the walk's state for each line                                                               |
| **Breaks first**     | a body line with a quoted phrase that holds an apostrophe, such as `the "can't" case`. 2 of 9,410 recorded commands are newly refused |
| **Security surface** | closes the force-push bypass in O2 of `arith-heredoc`                                                                  |
| **Proof it works**   | `bash plugins/zuko/scripts/tests/run.sh block-dangerous` gives 188 passed                                              |
| **Rollout**          | no flag: a hook script. Rollback is `git revert` of the fix commit                                                     |

The replay ran each of 9,410 recorded Bash commands through the parser on
`main` and on the fix. `main` refuses 4, and the fix refuses 6. The 2 new
refusals are pull-request bodies in the `"$(cat <<'EOF'` form. Each holds a
quoted phrase with an apostrophe, which `main` read only because later
apostrophes made pairs. One more command, of the same form, is refused by
both, with a new reason. No command that parses in both gives other
invocations, so each `-m` body is the same.

### Test plan

**E2E:** `bash plugins/zuko/scripts/tests/run.sh block-dangerous` pipes each
command as a real hook payload into `block-dangerous.sh`. Before the fix, 16
checks failed: the hook exited 0 for each of the eight refused forms, with no
block message. They pass after it.
`bash plugins/zuko/scripts/tests/run.sh block-attribution` gives 148 passed.
The full suite gives 2426 passed, 0 failed.

### Decisions to record

Draft for `DECISIONS.md`:

```
## D56 · 2026-10-13 · The shared parser refuses a heredoc body in `"$( )"` that changes its quotes

Why: inside a double-quoted `$( )` or backticks, bash skips the quotes in
a heredoc body, and the parser read them. One `"` in the body made the
lines after the heredoc text, and a force push there passed
block-dangerous.sh (main 4ef85fe, v2.4.1). Each body line must now leave
the parser's state as it found it.
Rejected: a check only at the line that ends the body (bash ends it at
the next backtick inside backticks, and bash 5.1 also at a line `EOF)`),
dropping the body as other heredoc bodies are (block-attribution.sh reads
the commit body in the `-m` word), refusing each `<<` inside `"$( )"` (it
blocks the standard commit form).
Source: specs/quoted-subst-heredoc.md
Status: active
```

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | The parser can check each body line, or only the line that ends the body. A check of each line refuses 2 of 9,410 recorded commands that `main` read. A check of the end line refuses neither. | flag | /debug | user | Decided alone | Chose: check each body line, so the walk needs no rule for where bash ends the body early. Backticks and bash 5.1's `EOF)` end it early. Other: check only the end line, with a rule for each place where bash ends the body. Undo: git revert e8211f3, then spec the end-line check through /spec. 2026-10-13 |
| O2 | A body with no known end: a delimiter such as `<<\EOF` or `<<EOF-1`, or a backslash that bash joins. Refusing it also blocks text such as `"$(date) <<EOF"`, where bash reads `<<` as text. | flag | /debug | user | Decided alone | Chose: refuse it; no recorded command was refused for it. Other: read each delimiter form and each backslash join as bash does. Undo: git revert e8211f3. 2026-10-13 |
| O3 | `/debug` found two more gaps inside `"$( )"`. `echo "$(git push --force origin main)"` passes the guard, because the parser never reads the command in it. A single quote, as in `"$(echo 'a"b')"`, changes the parser's quotes with no heredoc. bash runs the lines after it. Both are on `main`. | flag | /debug | user | Decided alone | Chose: leave them out of this fix. Both need the walk to follow the nested command as bash does. The first also needs new words for the callers. Other: fix them here. Undo: spec them through /spec. 2026-10-13 |
| O4 | `/debug` found gaps in the other heredoc path. It ends a body at an indented `EOF`, reads `<<EOF-1` as `EOF`, misses `<<\EOF`, and ignores a backslash before the delimiter line. Each hides lines that bash runs, on `main`. | flag | /debug | user | Decided alone | Chose: leave them out of this fix. Other: fix them here. Undo: run /zuko:debug on them. 2026-10-13 |
| O5 | `/debug` found that a `"two words"` phrase in the body of the standard commit form cuts the `-m` word. `block-attribution.sh` then misses a Claude trailer after it, on `main`. | flag | /debug | user | Decided alone | Chose: leave it out of this fix, which keeps the words as `main` builds them. Other: fix it here. Undo: spec it through /spec. 2026-10-13 |

_Never delete this section or its rows. See references/ledger.md._

## Glossary

- **Heredoc** — the `<<'EOF' … EOF` block that gives a command a long body
  from inside the command text
- **Command substitution** — `$( … )` or backticks: bash runs the command and
  puts its output there
- **Walk** — the pass in `openers_in` that reads the command one character at a
  time, and keeps the quote state from line to line
- **Lost** — the walk's flag after `${`, `$'`, a backtick, or a `$(` in double
  quotes, where bash's quotes are not the walk's
- **shlex** — Python's library that splits a command into words as a shell
  does. It does not do everything bash does
- **e2e** — end-to-end: one test that walks the whole slice as a user would
- **Replay** — a run of each recorded Bash command through the old and the new
  parser, on this machine only
