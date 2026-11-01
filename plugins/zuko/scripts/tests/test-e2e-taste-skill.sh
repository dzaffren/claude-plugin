# The vendored taste skill (spec taste-skill-upgrade): the lock pins tag
# v2.1.5, its hash matches the files on disk, git keeps those bytes as they
# are, and the three design stages say which part of v2 each one uses.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

root=$(cd "$scripts/../../.." && pwd)
lock="$root/skills-lock.json"
skill="$root/.agents/skills/design-taste-frontend"

# --- Scenario 1: the vendored skill is v2.1.5 and the lock agrees ---------

ref=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["skills"]["design-taste-frontend"].get("ref", ""))' "$lock" 2>&1)
expect_match '^v2\.1\.5$' "$ref" "the lock pins design-taste-frontend at tag v2.1.5"

# The skills CLI hashes a skill folder in src/local-lock.ts
# (computeSkillFolderHash): every file under it except .git and node_modules,
# sorted by its /-separated relative path, then sha256 over path + raw bytes.
# The CLI sorts with JS localeCompare, which ignores case first and puts
# lowercase before uppercase on a tie: README.md sorts after library/, not
# before assets/. casefold, then swapcase, gives that order for these names.
cat >"$work/skill_hash.py" <<'PY'
import hashlib, os, sys

def folder_hash(base):
    files = []
    for here, dirs, names in os.walk(base):
        dirs[:] = [d for d in dirs if d not in (".git", "node_modules")]
        for name in names:
            full = os.path.join(here, name)
            files.append((os.path.relpath(full, base).replace(os.sep, "/"), full))
    files.sort(key=lambda f: (f[0].casefold(), f[0].swapcase()))
    h = hashlib.sha256()
    for rel, full in files:
        h.update(rel.encode("utf-8"))
        with open(full, "rb") as fh:
            h.update(fh.read())
    return h.hexdigest(), len(files)

digest, count = folder_hash(sys.argv[1])
print(digest, count)
PY
read -r disk_hash file_count < <(python3 "$work/skill_hash.py" "$skill")
lock_hash=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["skills"]["design-taste-frontend"]["computedHash"])' "$lock")
expect_exit 0 "$([ "$disk_hash" = "$lock_hash" ]; echo $?)" "the lock hash matches the vendored files (disk $disk_hash)"
expect_match '^39$' "$file_count" "the vendored folder holds the v2 file set, not the one-file v1 (found $file_count)"
expect_match '^name: design-taste-frontend$' "$(head -3 "$skill/SKILL.md")" "the vendored SKILL.md keeps the name the craft chain loads"
expect_match 'tasteskill v2' "$(head -8 "$skill/SKILL.md")" "the vendored SKILL.md is v2"

# The hash is over raw bytes, so a CRLF checkout on Windows must not rewrite them.
attr=$(git -C "$root" check-attr text -- .agents/skills/design-taste-frontend/SKILL.md)
expect_match ': text: unset$' "$attr" "git stores and checks out the vendored bytes as they are"

# --- Scenarios 3 and 4: which stage uses which part of v2 -----------------

craft="$scripts/../references/craft.md"
ds="$scripts/../skills/design-system/SKILL.md"
sp="$scripts/../skills/spec/SKILL.md"
de="$scripts/../skills/design/SKILL.md"

expect_match '^## taste-skill v2$' "$(cat "$craft")" "craft.md has the taste-skill v2 section"
expect_match 'Do not run `draw\.mjs`' "$(cat "$craft")" "craft.md tells /spec and /design not to deal directions"
expect_match 'v2 inspector skipped: Node not found' "$(cat "$craft")" "craft.md carries the skip message"

for f in "$ds" "$sp" "$de"; do
  stage=$(basename "$(dirname "$f")")
  expect_match 'check-skill-pin\.sh" design-taste-frontend' "$(cat "$f")" "/$stage runs the pin check"
done
expect_match 'scripts/draw\.mjs' "$(cat "$ds")" "/design-system pause B deals directions with draw.mjs"
for f in "$sp" "$de"; do
  stage=$(basename "$(dirname "$f")")
  expect_match '"taste-skill v2" section of' "$(cat "$f")" "/$stage reads the taste-skill v2 section of craft.md"
  expect_no_match 'node [^ ]*draw\.mjs' "$(cat "$f")" "/$stage never runs draw.mjs"
done

# --- Review fixes ----------------------------------------------------------

# F1: draw.mjs exits 2 without --sector, and deals one direction, not
# candidates, without --options.
expect_match 'draw\.mjs --sector <sector> --brief "<one line>" --options 3' "$(cat "$craft")" "craft.md gives draw.mjs its sector, brief and --options 3"
expect_match 'craft\.md' "$(cat "$ds")" "/design-system pause B points at the craft.md section for the draw command"

# F4: a sheet at .taste-skill/direction.json is read by every later
# inspect.mjs run and warns on fonts the design system replaced.
expect_match 'draw.mjs .*--direction <id> --out \.taste-skill/pause-b/<id>' "$(cat "$craft")" "pause B writes each sheet out of the inspector's default path"

# F2: the Node check covered only the inspector, so pause B's draw.mjs
# failed with a bare "command not found".
expect_match '^\*\*Before any v2 script runs\*\*' "$(cat "$craft")" "the Node check covers every v2 script"
expect_match 'draw\.mjs` needs Node 18 or newer' "$(cat "$craft")" "craft.md names draw.mjs's own Node floor"

# F7: "Install Chrome" was offered, but every installer row installs Node.
expect_match 'install Chrome, Edge or Chromium, or set CHROME_PATH' "$(cat "$craft")" "a missing browser gets guidance, not a Node installer"
expect_no_match 'same text with "Chrome"' "$(cat "$craft")" "craft.md no longer offers an install for the browser"
