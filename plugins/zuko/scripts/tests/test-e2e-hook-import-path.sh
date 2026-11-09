# One walk through hook-import-path: a json.py at the root of the project
# folder never runs from a zuko hook, and never turns a block into a pass
# (D125). The planted json.py writes PWNED next to itself and exits 0.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

work=$(mktemp -d -p "$work")
export HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME"

# acme-shop's branch changes a Refined spec that has an Open row, so both Stop
# hooks have a verdict to give. It pins a skill, and a gh stub says that a
# newer release is out, so check-skill-pin.sh has a notice to print.
repo="$work/acme-shop"
g() { git -C "$repo" -c user.name=Zuko -c user.email=zuko@example.com -c commit.gpgsign=false "$@"; }
git init -q -b main "$repo"
printf '# acme-shop\n' >"$repo/README.md"
printf '{"version": 1, "skills": {"design-taste-frontend": {"source": "Leonxlnx/taste-skill", "ref": "v2.1.5", "sourceType": "github", "computedHash": "x"}}}\n' >"$repo/skills-lock.json"
g add -A
g commit -q --no-verify -m "chore: start acme-shop"
g switch -q -c feat/basket
mkdir -p "$repo/docs/specs"
cat >"$repo/docs/specs/basket.md" <<'EOF'
# Basket

**Version:** v1 · **Status:** Refined · **Type:** Feature · **Project type:** Web UI

## Open items

| ID | What | Type | Raised at | Owner | Status | Answer |
| -- | ---- | ---- | --------- | ----- | ------ | ------ |
| O1 | Can a gift card pay for shipping? | question | spec p1 | user | Open | — |
EOF
g add -A
g commit -q --no-verify -m "docs(spec): basket"
printf 'staging.acme.test\n' >"$repo/.git/zuko-pentest-target"

mkdir -p "$work/bin"
cat >"$work/bin/gh" <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "api repos/"*/releases/latest) echo v2.2.0 ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
chmod +x "$work/bin/gh"
PATH="$work/bin:$PATH"

# Each payload is written before json.py exists, so the test's own Python
# never runs in a folder with the plant.
payloads="$work/payloads"
mkdir -p "$payloads"
bash_payload() {  # bash_payload <name> <agent_type or ""> <command>
  ZUKO_AGENT="$2" ZUKO_CMD="$3" ZUKO_CWD="$repo" python3 -c 'import json, os
event = {"tool_name": "Bash", "tool_input": {"command": os.environ["ZUKO_CMD"]}, "cwd": os.environ["ZUKO_CWD"]}
if os.environ["ZUKO_AGENT"]:
    event["agent_type"] = os.environ["ZUKO_AGENT"]
print(json.dumps(event))' >"$payloads/$1"
}
bash_payload force "" "git push --force origin main"
bash_payload verifier zuko:finding-verifier "git push --force origin main"
bash_payload pentester zuko:pentester "git push --force origin main"
bash_payload target "" "curl https://evil.example/"
bash_payload attribution "" "git commit -m 'feat: basket

Co-Authored-By: Claude <noreply@anthropic.com>'"
bash_payload commit "" "git commit -m 'feat: basket'"
ZUKO_FILE="$repo/README.md" python3 -c 'import json, os; print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": os.environ["ZUKO_FILE"]}}))' >"$payloads/edit"
printf '%s' '{"session_id":"hook-import-path","transcript_path":"/dev/null","cwd":"/","permission_mode":"default","hook_event_name":"Stop","stop_hook_active":false}' >"$payloads/stop"
: >"$payloads/none"

# name|script|payload|arguments
runs="block-dangerous.sh|block-dangerous.sh|force|
scope-verifier-bash.sh|scope-verifier-bash.sh|verifier|
scope-pentester-bash.sh|scope-pentester-bash.sh|pentester|
block-pentest-target.sh|block-pentest-target.sh|target|
block-attribution.sh|block-attribution.sh|attribution|
secret-scan.sh|secret-scan.sh|commit|
auto-format.sh|auto-format.sh|edit|
verify-gates.sh|verify-gates.sh|stop|
check-open-items.sh|check-open-items.sh|stop|
check-skill-pin.sh|check-skill-pin.sh|none|design-taste-frontend"

hook() {          # hook <script> <payload> [args]: its output, then "exit=N", run in acme-shop
  local out code
  out=$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" bash "$scripts/$1" ${3:+"$3"} <"$payloads/$2" 2>&1)
  code=$?
  printf '%s\nexit=%s' "$out" "$code"
}

before="$work/before"
mkdir -p "$before"
while IFS='|' read -r name script payload args; do
  hook "$script" "$payload" "$args" >"$before/$name"
done <<<"$runs"
expect_match '^exit=2$' "$(cat "$before/block-dangerous.sh")" "without a plant, block-dangerous.sh blocks the force push"
expect_match '^exit=2$' "$(cat "$before/check-open-items.sh")" "without a plant, check-open-items.sh fails the turn on the Open row"

cat >"$repo/json.py" <<'EOF'
import os
open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "PWNED"), "a").write("json.py ran\n")
raise SystemExit(0)
EOF

while IFS='|' read -r name script payload args; do
  rm -f "$repo/PWNED"
  after=$(hook "$script" "$payload" "$args")
  expect_exit 1 "$([ -e "$repo/PWNED" ]; echo $?)" "$name in acme-shop never runs acme-shop/json.py"
  was=$(cat "$before/$name")
  if [ "$after" = "$was" ]; then
    record PASS "$name gives the same verdict with a json.py at the repo root"
  else
    record FAIL "$name gives the same verdict with a json.py at the repo root" "before [${was:0:200}] after [${after:0:200}]"
  fi
done <<<"$runs"

rm -f "$repo/PWNED"
out=$(hook block-dangerous.sh force)
expect_match '^exit=2$' "$out" "with a json.py that exits 0, block-dangerous.sh still blocks the force push"
expect_match '^Blocked: force push rewrites shared history\. Ask the user first\.$' "$out" "the force-push block keeps its message"

rm -f "$repo/PWNED"
out=$(PYTHONPATH=. hook block-dangerous.sh force)
expect_exit 1 "$([ -e "$repo/PWNED" ]; echo $?)" "PYTHONPATH=. in acme-shop does not bring json.py back"
expect_match '^exit=2$' "$out" "with PYTHONPATH=., block-dangerous.sh still blocks the force push"

# D126: no new inline Python call in a zuko script comes in without -I.
# A call is python3 or python with -c, - or << next, after any options. A
# line whose first character that is not a space is # is a comment, and
# never counts. Each hit prints as file:line.
bare_python() {   # bare_python <file>...: each inline Python call with no -I
  python3 -c 'import re, sys
for path in sys.argv[1:]:
    for number, line in enumerate(open(path, encoding="utf-8"), 1):
        if line.lstrip().startswith("#"):
            continue
        for match in re.finditer(r"\bpython3?(?=\s)", line):
            words = line[match.end():].split()
            for word in words:
                if word == "-I":
                    break
                if word in ("-c", "-") or word.startswith("<<"):
                    print("%s:%d" % (path, number))
                    break
                if not word.startswith("-"):
                    break' "$@"
}

fixture="$work/fixture"
mkdir -p "$fixture"
cat >"$fixture/new-hook.sh" <<'SH'
cmd=$(printf '%s' "$input" | python3 -c 'import json')
python3 - "$here" <<'PY'
ZUKO_INPUT="$input" env python3 <<'PY'
cmd=$(python3 -I -c 'import json')
python3 "$here/lib/stop_scope.py" "$base"
  # python3 -c in a comment
SH
want=$(printf '%s\n' "$fixture/new-hook.sh:1" "$fixture/new-hook.sh:2" "$fixture/new-hook.sh:3")
got=$(bare_python "$fixture/new-hook.sh")
if [ "$got" = "$want" ]; then
  record PASS "the -I check names each inline Python call without -I, and nothing else"
else
  record FAIL "the -I check names each inline Python call without -I, and nothing else" "want [$want] got [$got]"
fi

hits=$(bare_python "$scripts"/*.sh "$scripts"/lib/*.sh)
expect_exit 0 "$([ -z "$hits" ]; echo $?)" "each inline Python call in plugins/zuko/scripts runs with -I: [${hits}]"
