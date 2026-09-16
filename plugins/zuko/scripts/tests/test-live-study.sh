# The study slice end to end: real headless sessions in scratch repos, walked
# through the five acceptance scenarios of docs/specs/study-on-demand.md.
#
# Each turn is a `claude -p` call, chained with --resume. Sessions A, B and C
# run in parallel; the turns inside one session run in order. Only fixed lines,
# file contents and tool calls are checked -- never free text.
#
# This costs real money, so run.sh leaves it out unless it is named:
#     bash plugins/zuko/scripts/tests/run.sh live-study
#
# Sourced by run.sh, which provides $scripts and the expect_* helpers.

plugin=$(dirname "$scripts")
work=$(mktemp -d)

# A live test that could not run is a failure, never a quiet pass.
if ! command -v claude >/dev/null 2>&1; then
  record FAIL "live-study" "claude is not on PATH, so the e2e never ran"
  rm -rf "$work"
  return 0
fi

# ---------------------------------------------------------------- turn driver

# run_turn <dir> <meta-dir> <resume-id or empty> <prompt>
# The transcript is written to <meta-dir>, never into <dir> -- the scratch repo
# has to stay clean, both for the git checks and so the session never reads its
# own transcript. Sets turn_session, turn_error, turn_text, turn_first.
run_turn() {
  local dir="$1" box="$2" resume="$3" prompt="$4" meta n
  local args=(-p "$prompt"
              --output-format stream-json --verbose
              --plugin-dir "$plugin" --add-dir "$plugin"
              --allowedTools "Bash(python3 *)"
              --max-budget-usd 1
              --permission-mode acceptEdits)
  [ -n "$resume" ] && args+=(--resume "$resume")

  # One set of files per turn. Overwriting them would throw away the turn that
  # actually failed, and re-running to see it costs money.
  n=$(( $(find "$box" -maxdepth 1 -name '*.jsonl' | wc -l) + 1 ))
  printf '%s\n' "$prompt" >"$box/$n.prompt"
  ( cd "$dir" && timeout 900 claude "${args[@]}" ) >"$box/$n.jsonl" 2>"$box/$n.err"

  meta=$(python3 - "$box/$n" <<'PY'
import json, os, sys

d = sys.argv[1]
session, error = "", "no result event in the stream"
blocks, tools = [], []
try:
    lines = open(d + ".jsonl").read().splitlines()
except OSError:
    lines = []
for line in lines:
    line = line.strip()
    if not line:
        continue
    try:
        event = json.loads(line)
    except ValueError:
        continue
    if not isinstance(event, dict):
        continue
    session = event.get("session_id") or session
    message = event.get("message")
    if isinstance(message, dict) and event.get("type") == "assistant":
        for block in message.get("content") or []:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "text" and (block.get("text") or "").strip():
                blocks.append(block["text"])
            elif block.get("type") == "tool_use":
                tools.append("%s\t%s" % (block.get("name", ""),
                                         json.dumps(block.get("input", ""))))
    if event.get("type") == "result":
        error = "the result event is flagged is_error" if event.get("is_error") else ""

# Everything the user saw this turn, not just the last message. The result
# event carries only the final block, so a line printed before a long stretch
# of tool calls is invisible there.
open(d + ".text", "w").write("\n".join(blocks))
open(d + ".first", "w").write(blocks[0] if blocks else "")
open(d + ".tools", "w").write("\n".join(tools) + "\n")
print(session)
print(error)
PY
)
  turn_session=$(printf '%s\n' "$meta" | sed -n 1p)
  turn_error=$(printf '%s\n' "$meta" | sed -n 2p)
  turn_text=$(cat "$box/$n.text")
  turn_first=$(grep -m1 -v '^[[:space:]]*$' "$box/$n.first" || true)
  turn_tools="$box/$n.tools"
}

# Each session writes its findings to its own file, so parallel sessions never
# interleave into one results file. The main shell replays them after wait.
note() { printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >>"$found"; }

check_turn() {   # check_turn <label>; fails the turn if claude itself errored
  if [ -n "$turn_error" ]; then
    note FAIL "$1" "$turn_error"
    return 1
  fi
  return 0
}

tree_of() { ( cd "$1" && find . -type f -not -path './.git/*' | sort ); }

# ------------------------------------------------------------------ session A

session_a() {
  local dir="$work/a" box="$work/a.box" found="$work/a.found" sid tree_before todo_marker turn_tools
  : >"$found"
  mkdir -p "$dir" "$box"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email t@example.com
  git -C "$dir" config user.name Tester
  cat >"$dir/todo.py" <<'PY'
import json


def load_todos(path):
    with open(path) as handle:
        return json.load(handle)


def main():
    for todo in load_todos("todos.json"):
        print(todo["title"])


if __name__ == "__main__":
    main()
PY
  printf '[{"title": "write the spec", "done": true}, {"title": "build it", "done": false}]\n' >"$dir/todos.json"
  git -C "$dir" add -A
  git -C "$dir" commit -q --no-verify -m "chore(todo): the starting cli"

  # T1 -- scenario 1: the mode starts and asks before it writes.
  run_turn "$dir" "$box" "" '/zuko:study python error handling

I want a --file flag that loads todos from todos.json.'
  check_turn "A1 the first turn returned a result" || return 0
  sid="$turn_session"
  if grep_text -E 'Study mode on:' "$turn_text"; then
    note PASS "A1 prints Study mode on"
  else
    note FAIL "A1 prints Study mode on" "reply began: ${turn_first:0:120}"
  fi
  if [ -z "$(git -C "$dir" status --porcelain)" ]; then
    note PASS "A1 writes no code before the level questions are answered"
  else
    note FAIL "A1 writes no code before the level questions are answered" "$(git -C "$dir" status --porcelain | tr '\n' ' ')"
  fi

  # T2 -- scenario 1: the piece is written and the gap is left for the user.
  run_turn "$dir" "$box" "$sid" 'I know try/except exists but my scripts just crash. I want them to fail with a clear message. Go ahead and add the --file flag.'
  check_turn "A2 the second turn returned a result" || return 0
  if grep -q 'TODO(study):' "$dir/todo.py"; then
    note PASS "A2 leaves a TODO(study) gap in todo.py"
  else
    note FAIL "A2 leaves a TODO(study) gap in todo.py" "$(grep -c . "$dir/todo.py") lines, no marker"
  fi
  if grep -q -- '--file' "$dir/todo.py"; then
    note PASS "A2 wrote the --file flag itself"
  else
    note FAIL "A2 wrote the --file flag itself" "no --file in todo.py"
  fi
  for fixed in 'Your turn' 'Where:'; do
    if grep_text -F "$fixed" "$turn_text"; then
      note PASS "A2 reply carries $fixed"
    else
      note FAIL "A2 reply carries $fixed" "not in the reply"
    fi
  done
  if grep -qE '^Skill\s.*zuko:(shape|spec|build|review|ship)' "$turn_tools"; then
    note FAIL "A2 starts no stage" "$(grep -oE 'zuko:(shape|spec|build|review|ship)' "$turn_tools" | head -1)"
  else
    note PASS "A2 starts no stage"
  fi
  todo_marker=$(grep -m1 'TODO(study):' "$dir/todo.py" || true)

  # T3 -- scenario 4: one piece handed back, the next still a gap.
  run_turn "$dir" "$box" "$sid" 'just do this one for me. Then make it list unfinished todos before finished ones.'
  check_turn "A3 the third turn returned a result" || return 0
  if [ -n "$todo_marker" ] && grep -qF "$todo_marker" "$dir/todo.py"; then
    note FAIL "A3 fills the gap it was handed" "the old marker is still there"
  else
    note PASS "A3 fills the gap it was handed"
  fi
  if grep -q 'TODO(study):' "$dir/todo.py"; then
    note PASS "A3 leaves the next piece as a gap"
  else
    note FAIL "A3 leaves the next piece as a gap" "no TODO(study) marker left"
  fi
  if grep_text -F "Your turn" "$turn_text"; then
    note PASS "A3 reply carries Your turn"
  else
    note FAIL "A3 reply carries Your turn" "not in the reply"
  fi

  # T4 -- scenario 5: a typed stage is guarded, and nothing of it runs.
  tree_before=$(tree_of "$dir")
  run_turn "$dir" "$box" "$sid" '/zuko:spec add a --done flag that marks a todo complete'
  check_turn "A4 the fourth turn returned a result" || return 0
  if grep_text -E "You're in study mode\. Stop studying and run /(zuko:)?spec\?" "$turn_text"; then
    note PASS "A4 answers a typed stage with the guard sentence"
  else
    note FAIL "A4 answers a typed stage with the guard sentence" "reply began: ${turn_first:0:120}"
  fi
  if [ "$tree_before" = "$(tree_of "$dir")" ]; then
    note PASS "A4 the guard left the file tree untouched"
  else
    note FAIL "A4 the guard left the file tree untouched" "the tree changed"
  fi
  if [ -d "$dir/docs/specs" ]; then
    note FAIL "A4 no spec was written" "docs/specs exists"
  else
    note PASS "A4 no spec was written"
  fi

  # T5 -- scenario 5: leaving happens only when the user says so.
  run_turn "$dir" "$box" "$sid" 'stop studying'
  check_turn "A5 the fifth turn returned a result" || return 0
  if grep_text -F "Study mode off." "$turn_text"; then
    note PASS "A5 prints Study mode off"
  else
    note FAIL "A5 prints Study mode off" "reply began: ${turn_first:0:120}"
  fi
  if grep_text -F "Your turn" "$turn_text"; then
    note FAIL "A5 leaves no gap once the mode is off" "the reply still has a Your turn block"
  else
    note PASS "A5 leaves no gap once the mode is off"
  fi
}

# ------------------------------------------------------------------ session B

session_b() {
  local dir="$work/b" box="$work/b.box" found="$work/b.found" sid before turn_tools
  : >"$found"
  mkdir -p "$dir" "$box"
  cat >"$dir/todo.py" <<'PY'
import json
import sys


def load_todos(path):
    # TODO(study): open the file at `path` and parse it as JSON. If the file is
    # missing or the JSON is broken, print which one went wrong and exit 1.
    try:
        with open(path) as handle:
            return json.load(handle)
    except FileNotFound:
        print("todo: cannot read " + path)
        sys.exit(1)


def main():
    path = "todos.json"
    if "--file" in sys.argv:
        path = sys.argv[sys.argv.index("--file") + 1]
    for todo in load_todos(path):
        print(todo["title"])


if __name__ == "__main__":
    main()
PY
  before=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$dir/todo.py")

  # T1 -- the mode starts on its own turn. Scenario 1 requires the first reply
  # to be the start line and the level questions, so the attempt cannot be
  # judged in the same turn that switches the mode on.
  run_turn "$dir" "$box" "" '/zuko:study python error handling'
  check_turn "B1 the first turn returned a result" || return 0
  sid="$turn_session"
  if grep_text -F "Study mode on:" "$turn_text"; then
    note PASS "B1 prints Study mode on"
  else
    note FAIL "B1 prints Study mode on" "reply began: ${turn_first:0:120}"
  fi

  # T2 -- scenario 3: a broken attempt gets a hint, never the fix.
  run_turn "$dir" "$box" "$sid" 'I know try/except exists but my scripts just crash, and I want a clear message
instead. I filled in the TODO(study) gap in load_todos in todo.py. done'
  check_turn "B2 the attempt turn returned a result" || return 0
  if grep_text -F "Not yet." "$turn_first"; then
    note PASS "B2 opens a failed attempt with Not yet"
  else
    note FAIL "B2 opens a failed attempt with Not yet" "first line was: ${turn_first:0:120}"
  fi
  if grep_text -E '^[[:space:]]*Hint:' "$turn_text"; then
    note PASS "B2 gives a Hint line"
  else
    note FAIL "B2 gives a Hint line" "no Hint: line in the reply"
  fi
  # Scenario 3 asks for a hint "without writing the fix" -- not for the word to
  # be absent. Python chains the original exception under the NameError, so the
  # quoted traceback names it whatever the hint does, and reading that traceback
  # is the lesson. What must not appear is the corrected line.
  if grep_text -E 'except[[:space:]]+FileNotFoundError' "$turn_text"; then
    note FAIL "B2 withholds the fix" "the reply writes the corrected except line"
  else
    note PASS "B2 withholds the fix"
  fi
  if [ "$before" = "$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$dir/todo.py")" ]; then
    note PASS "B2 does not edit the user's attempt"
  else
    note FAIL "B2 does not edit the user's attempt" "todo.py changed"
  fi

  # T3 -- scenario 3: the answer, once it is asked for.
  run_turn "$dir" "$box" "$sid" 'show me'
  check_turn "B3 the show me turn returned a result" || return 0
  if grep_text -E 'except[[:space:]]+FileNotFoundError' "$turn_text"; then
    note PASS "B3 shows the fix when asked"
  else
    note FAIL "B3 shows the fix when asked" "the corrected except line is not in the reply"
  fi
}

# ------------------------------------------------------------------ session C

session_c() {
  local dir="$work/c" box="$work/c.box" found="$work/c.found" sid turn_tools
  : >"$found"
  mkdir -p "$dir" "$box"

  # T1 -- the mode starts on its own turn, same as session B.
  run_turn "$dir" "$box" "" '/zuko:study system design'
  check_turn "C1 the first turn returned a result" || return 0
  sid="$turn_session"
  if grep_text -F "Study mode on:" "$turn_text"; then
    note PASS "C1 prints Study mode on"
  else
    note FAIL "C1 prints Study mode on" "reply began: ${turn_first:0:120}"
  fi

  # T2 -- scenario 2: no code to write, so the gap is the decision.
  run_turn "$dir" "$box" "$sid" 'I have never designed a URL shortener. I want to be able to reason about one
in an interview. How would a URL shortener handle 10,000 new links a day?'
  check_turn "C2 the question turn returned a result" || return 0
  for fixed in 'Your turn' 'Decide:'; do
    if grep_text -F "$fixed" "$turn_text"; then
      note PASS "C2 reply carries $fixed"
    else
      note FAIL "C2 reply carries $fixed" "not in the reply"
    fi
  done
  if [ -z "$(tree_of "$dir")" ]; then
    note PASS "C2 wrote no files for a topic with no code"
  else
    note FAIL "C2 wrote no files for a topic with no code" "$(tree_of "$dir" | tr '\n' ' ')"
  fi

  # T3 -- scenario 2: a real choice gets explained, not marked wrong.
  run_turn "$dir" "$box" "$sid" 'I would use a base62 counter, because it never collides and I do not have to check whether a code is already taken.'
  check_turn "C3 the choice turn returned a result" || return 0
  if grep_text -F "Not yet." "$turn_first"; then
    note FAIL "C3 treats a reasoned choice as valid" "it opened with Not yet."
  else
    note PASS "C3 treats a reasoned choice as valid"
  fi
  if grep_text -E '^[[:space:]]*Glossary' "$turn_text"; then
    note PASS "C3 explanation carries a Glossary heading"
  else
    note FAIL "C3 explanation carries a Glossary heading" "no Glossary heading in the reply"
  fi
}

# ------------------------------------------------------------------- run them

session_a &
pid_a=$!
session_b &
pid_b=$!
session_c &
pid_c=$!
wait "$pid_a" "$pid_b" "$pid_c"

clean=yes
for letter in a b c; do
  if [ ! -s "$work/$letter.found" ]; then
    record FAIL "session $letter" "the session recorded nothing"
    clean=no
    continue
  fi
  grep -q '^FAIL' "$work/$letter.found" && clean=no
  while IFS=$'\t' read -r status description detail; do
    record "$status" "$description" "$detail"
  done <"$work/$letter.found"
done

# A failed run costs money to reproduce, so keep the transcripts. They are the
# only way to see what the session actually printed.
if [ "$clean" = yes ]; then
  rm -rf "$work"
else
  echo "live-study: transcripts kept at $work" >&2
fi
