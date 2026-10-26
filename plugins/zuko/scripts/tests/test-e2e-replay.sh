# One walk through the replay slice in one fixture repo with a bare origin.
# s-one and the shape merge into main with a merge commit. s-two's three
# pause commits go to origin as refs/pull/1/head and reach main as one squash
# commit. s-three is in flight on a branch with two commits. The board is
# rendered with a stub gh that names PR 1 for the squash commit, then again
# with no gh, and each check reads the replay from the rendered page's data
# block.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

board="$scripts/lib/board.py"
work=$(mktemp -d -p "$work")
# The real interpreter: a python3 shim on PATH may need tools the narrow PATH lacks.
py=$(python3 -c 'import sys; print(sys.executable)')
author="$work/author"
origin="$work/origin.git"
repo="$work/repo"
page="$work/board.html"

same() {  # same <expected> <actual> <description>
  if [ "$2" = "$1" ]; then record PASS "$3"
  else record FAIL "$3" "expected [$1], got [$2]"; fi
}

tick=0
commit() {  # commit <repo> <subject>: everything, one minute after the last
  tick=$((tick + 1))
  local when
  when=$(printf '2026-10-01T09:%02d:00+0000' "$tick")
  git -C "$1" add -A
  GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" git -C "$1" -c user.name=Test \
    -c user.email=test@example.com -c commit.gpgsign=false commit -q -m "$2"
}

spec() {  # spec <repo> <name> p1|p2|p3|shipped
  local status=Draft more=""
  case "$3" in
    p2) more=$'\n## Interface\n\nThe page.\n' ;;
    p3|shipped) more=$'\n## Interface\n\nThe page.\n\n## Technical plan\n\nThe code.\n' ;;
  esac
  [ "$3" = shipped ] && status=Shipped
  printf '# %s\n\n**Version:** v1 · **Status:** %s\n\n**Shape doc:** docs/specs/idea/shape.md\n\n## Acceptance criteria\n\n```gherkin\nScenario: it works\n  Then it works\n```\n%s' \
    "$2" "$status" "$more" >"$1/docs/specs/$2.md"
}

# render <bin dir>: the board page, with PATH holding only that dir. Sets $status.
render() {
  PATH="$1" "$py" "$board" render "$repo/docs/specs/idea/shape.md" --by "/spec s-three pause 2" >"$page" 2>"$work/err"
  status=$?
}

# get <python expression>: R is the replay in the page's data block, H its hashes.
get() {
  "$py" -c 'import json, sys
page = open(sys.argv[2], encoding="utf-8").read()
start = page.index(">", page.index("<script id=\"data\"")) + 1
R = json.loads(page[start:page.index("</script>", start)])["replay"]
H = [s["hash"] for s in R["steps"]]
v = eval(sys.argv[1])
print(v if isinstance(v, str) else json.dumps(v, ensure_ascii=False))' "$1" "$page" 2>/dev/null
}

# --- the history, written in an author repo and pushed to origin ---
git init -q -b main "$author"
echo "readme" >"$author/README"
commit "$author" "docs: readme"
git -C "$author" checkout -q -b feat/s-one
mkdir -p "$author/docs/specs/idea"
cat >"$author/docs/specs/idea/shape.md" <<'SHAPE'
# Idea

**Project type:** CLI/Library · **Status:** Shaped

## Problem

The board shows only now.

## Slices

| # | Slice | What ships | Why this order |
| --- | --- | --- | --- |
| 1 | s-one | One. | First. |
| 2 | s-two | Two. | Second. |
| 3 | s-three | Three. | Third. |
SHAPE
spec "$author" s-one p1
commit "$author" "docs(spec): add idea shape and s-one"
spec "$author" s-one shipped
commit "$author" "docs(spec): ship s-one"
git -C "$author" checkout -q main
GIT_AUTHOR_DATE=2026-10-01T09:30:00+0000 GIT_COMMITTER_DATE=2026-10-01T09:30:00+0000 \
  git -C "$author" -c user.name=Test -c user.email=test@example.com merge -q --no-ff -m "Merge feat/s-one" feat/s-one
tick=30
git -C "$author" checkout -q -b feat/s-two
for p in p1 p2 p3; do
  spec "$author" s-two "$p"
  commit "$author" "docs(spec): s-two $p"
done
git -C "$author" checkout -q main
git -C "$author" merge -q --squash feat/s-two >/dev/null
commit "$author" "feat(spec): s-two"
git init -q --bare -b main "$origin"
git -C "$author" push -q "$origin" main feat/s-two:refs/pull/1/head
squash=$(git -C "$author" rev-parse main)
head=$(git -C "$author" rev-parse feat/s-two)
s1=(); for rev in feat/s-one~1 feat/s-one; do s1+=("$(git -C "$author" rev-parse --short "$rev")"); done
s2=(); for rev in feat/s-two~2 feat/s-two~1 feat/s-two; do s2+=("$(git -C "$author" rev-parse --short "$rev")"); done

# --- the user's clone, with s-three in flight ---
git clone -q --no-local "$origin" "$repo"
git -C "$repo" checkout -q -b feat/s-three
spec "$repo" s-three p1
commit "$repo" "docs(spec): s-three p1"
spec "$repo" s-three p2
commit "$repo" "docs(spec): s-three p2"
s3=(); for rev in HEAD~1 HEAD; do s3+=("$(git -C "$repo" rev-parse --short "$rev")"); done
git -C "$repo" cat-file -e "$head" 2>/dev/null
expect_exit 1 "$?" "fixture: the clone does not hold the PR's commits before the render"

mkdir -p "$work/stub" "$work/nogh"
ln -s "$(command -v git)" "$work/stub/git"
ln -s "$(command -v git)" "$work/nogh/git"
printf '#!/bin/sh\necho "$*" >>"%s"\ncase "$*" in *%s*) echo 1 ;; *) echo null ;; esac\n' "$work/gh.log" "$squash" >"$work/stub/gh"
chmod +x "$work/stub/gh"

# --- render with gh: main, the PR's commits in place of the squash, then the branch ---
render "$work/stub"
expect_exit 0 "$status" "gh: render exits 0"
all="[\"${s1[0]}\", \"${s1[1]}\", \"${s2[0]}\", \"${s2[1]}\", \"${s2[2]}\", \"${s3[0]}\", \"${s3[1]}\"]"
same "$all" "$(get 'H')" "gh: s-one's merged commits, s-two's 3 PR commits in place of the squash, then s-three's branch"
same "null" "$(get 'R["note"]')" "gh: no note"
same "[null, null, 1, 1, 1, null, null]" "$(get '[s["pr"] for s in R["steps"]]')" "gh: the PR steps say PR 1"
same "[[1, 0, 0], [7, 0, 0], [7, 1, 0], [7, 2, 0], [7, 3, 0], [7, 3, 1], [7, 3, 2]]" \
  "$(get '[[s["stages"][n] for n in ("s-one", "s-two", "s-three")] for s in R["steps"]]')" \
  "gh: each step has the stage of each slice at that commit"
same "s-two: 0 -> 1 | docs/specs/s-two.md: added the spec" \
  "$(get '"; ".join("%s: %d -> %d" % (m["slice"], m["from"], m["to"]) for m in R["steps"][2]["moved"]) + " | " + "; ".join("%s: %s" % (c["file"], ", ".join(i["kind"] + " " + i["what"] for i in c["items"])) for c in R["steps"][2]["changed"])')" \
  "gh: the first PR step moves s-two and adds its spec"
same "2026-10-01 09:31 · docs(spec): s-two p1" "$(get 'R["steps"][2]["at"] + " · " + R["steps"][2]["subject"]')" \
  "gh: a PR step has its own date and subject"
same "{\"$squash\": {\"head\": \"$head\", \"pr\": 1}}" \
  "$("$py" -c 'import json, sys; print(json.dumps(json.load(open(sys.argv[1])), sort_keys=True))' "$repo/docs/specs/.pages/replay-prs.json" 2>&1)" \
  "cache: the squash commit maps to PR 1 and its head"
same "1" "$(wc -l <"$work/gh.log" | tr -d ' ')" "gh: asked once, for the one squash commit on main's first-parent line"

# --- render again with no gh: the cache still gives the PR steps ---
render "$work/nogh"
expect_exit 0 "$status" "no gh: render exits 0"
same "$all" "$(get 'H')" "no gh: the cache still gives the PR's commits"
same "null" "$(get 'R["note"]')" "no gh: no note"
