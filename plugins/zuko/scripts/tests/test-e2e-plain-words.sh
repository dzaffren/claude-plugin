# e2e for plain-words: the after-save hook, as hooks.json wires it, tells
# Claude which line of a new spec uses a zuko label alone, and goes quiet once
# the line is fixed. It reads the real references/voice.md.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

export HOME="$work/e2e-words-home" XDG_CONFIG_HOME="$work/e2e-words-home/.config" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME"

repo=$(mktemp -d -p "$work")
g() { git -C "$repo" -c user.name=Zuko -c user.email=zuko@example.com -c commit.gpgsign=false "$@"; }
git init -q -b main "$repo"
mkdir -p "$repo/docs/specs"
echo "# Raslaw" >"$repo/README.md"
g add -A
g commit -q -m "chore: start"
g checkout -q -b feat/refund-export

doc="$repo/docs/specs/refund-export.md"
{
  printf '# refund-export\n\n**Version:** v1 · **Status:** Draft · **Type:** Feature · **Project type:** CLI/Library\n\n## Problem\n\n'
  for n in $(seq 7 39); do echo "Finance exports 40 refunds a week by hand, row $n."; done
  echo "The ledger has no Open rows."
  printf '\n## Open items\n\n| ID | What | Type | Raised at | Owner | Status | Answer |\n| -- | ---- | ---- | --------- | ----- | ------ | ------ |\n'
} >"$doc"

# The command exactly as hooks.json runs it, with the plugin root set.
hook_cmd=$(python3 -c '
import json, sys
hooks = json.load(open(sys.argv[1]))["hooks"]["PostToolUse"]
print(next(h["command"] for group in hooks if group["matcher"] == "Write|Edit|MultiEdit"
           for h in group["hooks"] if "check-words.sh" in h["command"]))' "$scripts/../hooks/hooks.json")
expect_match 'check-words\.sh' "$hook_cmd" "hooks.json: the after-save hook runs check-words.sh"

save() {       # save: the PostToolUse call for an Edit of $doc; sets $hook_out $hook_status
  local payload
  payload=$(python3 -c 'import json, sys; print(json.dumps({"hook_event_name": "PostToolUse", "tool_name": "Edit",
    "tool_input": {"file_path": sys.argv[1], "old_string": "x", "new_string": "y"}}))' "$(native "$doc")")
  hook_out=$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" CLAUDE_PLUGIN_ROOT="$(dirname "$scripts")" bash -c "$hook_cmd" <<<"$payload" 2>&1)
  hook_status=$?
}

save
expect_exit 2 "$hook_status" "hard word: the hook exits 2, so Claude reads the message"
expect_match '^Word check: docs/specs/refund-export\.md$' "$hook_out" "hard word: names the doc"
expect_match '^- line 40: "ledger" is a zuko label used alone\. Write "the open-items table \(ledger\)"\.$' \
  "$hook_out" "hard word: names line 40 and the plain words"
expect_match '^Fix these lines now\. The check reads only the lines that this work added\.$' "$hook_out" \
  "hard word: tells Claude what to do"

sed -i.bak 's/^The ledger has no Open rows\.$/The open-items table (ledger) has no Open rows./' "$doc"
rm -f "$doc.bak"
save
expect_exit 0 "$hook_status" "fixed: the hook exits 0"
expect_match '^$' "$hook_out" "fixed: the hook prints nothing"

# A save of a file that is not a doc prints nothing, whatever it says.
doc="$repo/README.md"
echo "The ledger has no Open rows." >"$doc"
save
expect_exit 0 "$hook_status" "not a doc: README.md exits 0"
expect_match '^$' "$hook_out" "not a doc: README.md prints nothing"
