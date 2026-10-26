# scripts/lib/board.py -- the "replay" key: one step for each commit that
# changed the idea's shape or a slice spec, with each squash commit swapped
# for its PR's commits. Each case builds its own fixture repo under $work, and
# each render runs with a PATH that holds only git and, for most cases, a stub
# gh, so the machine's own gh and GitHub are never reached.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

board="$scripts/lib/board.py"
work=$(mktemp -d -p "$work")
# The real interpreter: a python3 shim on PATH may need tools the narrow PATH lacks.
py=$(python3 -c 'import sys; print(sys.executable)')
cache=docs/specs/.pages/replay-prs.json
tail_note="Squash-merged slices show as one step."

same() {  # same <expected> <actual> <description>
  if [ "$2" = "$1" ]; then record PASS "$3"
  else record FAIL "$3" "expected [$1], got [$2]"; fi
}

# bin <name> [gh script body]: a PATH dir with git, and a gh when a body is given.
bin() {
  mkdir -p "$work/bin/$1"
  ln -s "$(command -v git)" "$work/bin/$1/git"
  if [ -n "${2:-}" ]; then
    printf '#!/bin/sh\necho "$*" >>"%s"\n%s\n' "$work/bin/$1.log" "$2" >"$work/bin/$1/gh"
    chmod +x "$work/bin/$1/gh"
  fi
}

# render <bin> <repo> [data|render]: sets $out and $status.
render() {
  out=$(PATH="$work/bin/$1" "$py" "$board" "${3:-data}" "$2/docs/specs/idea/shape.md" --by test 2>"$work/err")
  status=$?
}

# pick <python expression>: R is board()["replay"] from $out, H the hashes.
pick() {
  "$py" -c 'import json, sys
R = json.loads(sys.argv[2])["replay"]
H = [s["hash"] for s in R["steps"]]
v = eval(sys.argv[1])
print(v if isinstance(v, str) else json.dumps(v, ensure_ascii=False))' "$1" "$out" 2>/dev/null
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

short() { git -C "$1" rev-parse --short "$2"; }
full() { git -C "$1" rev-parse "$2"; }

shape() {  # shape <repo> [problem]
  mkdir -p "$1/docs/specs/idea"
  cat >"$1/docs/specs/idea/shape.md" <<SHAPE
# Idea

**Project type:** CLI/Library · **Status:** Shaped

## Problem

${2:-The board shows only now.}

## Slices

| # | Slice | What ships | Why this order |
| --- | --- | --- | --- |
| 1 | s-one | One. | First. |
| 2 | s-two | Two. | Second. |
| 3 | s-three | Three. | Third. |
SHAPE
}

spec() {  # spec <repo> <name> p1|p2|p3|refined|shipped
  local status=Draft more=""
  case "$3" in
    p2) more=$'\n## Interface\n\nThe page.\n' ;;
    p3|refined|shipped) more=$'\n## Interface\n\nThe page.\n\n## Technical plan\n\nThe code.\n' ;;
  esac
  case "$3" in refined) status=Refined ;; shipped) status=Shipped ;; esac
  printf '# %s\n\n**Version:** v1 · **Status:** %s\n\n**Shape doc:** docs/specs/idea/shape.md\n\n## Acceptance criteria\n\n```gherkin\nScenario: it works\n  Then it works\n```\n%s' \
    "$2" "$status" "$more" >"$1/docs/specs/$2.md"
}

bin none 'echo null'
bin fail 'echo "HTTP 401: Bad credentials" >&2; exit 1'
bin nogh

# --- guard: a fixture that is not a repo ---
plain="$work/plain"
shape "$plain"
spec "$plain" s-one p1
render none "$plain"
expect_exit 0 "$status" "guard: a render outside any repo exits 0"
same '{"steps": [], "note": null}' "$(pick 'R')" "guard: not a repo gives no steps and no note"

# --- guard: a fixture inside another repo, with that repo's commits ---
outer="$work/outer"
git init -q -b main "$outer"
shape "$outer/inner"
spec "$outer/inner" s-one p1
commit "$outer" "docs: the outer repo holds the inner idea"
render none "$outer/inner"
same '{"steps": [], "note": null}' "$(pick 'R')" "guard: a repo above the root gives no steps and no note"

# --- no commits yet ---
fresh="$work/fresh"
git init -q -b main "$fresh"
shape "$fresh"
render none "$fresh"
expect_exit 0 "$status" "no commits: a repo with no commit renders, exit 0"
same '{"steps": [], "note": null}' "$(pick 'R')" "no commits: a repo with no commit gives no steps"
echo "readme" >"$fresh/README"
git -C "$fresh" add README
GIT_AUTHOR_DATE=2026-10-01T08:00:00+0000 GIT_COMMITTER_DATE=2026-10-01T08:00:00+0000 \
  git -C "$fresh" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit -q -m "docs: readme"
render none "$fresh"
same '{"steps": [], "note": null}' "$(pick 'R')" "no commits: commits that never touched the idea give no steps"

# --- the step list: main, then the branch in flight ---
local_repo="$work/local"
tick=0
git init -q -b main "$local_repo"
shape "$local_repo"
spec "$local_repo" s-one p1
commit "$local_repo" "docs(spec): add idea shape"
shape "$local_repo" "The board shows only now, and the past is lost."
spec "$local_repo" s-one p3
commit "$local_repo" "docs(spec): s-one pause 3"
spec "$local_repo" s-one refined
commit "$local_repo" 'docs: <script>alert(1)</script> & </b>'
git -C "$local_repo" checkout -q -b feat/s-two
spec "$local_repo" s-two p1
commit "$local_repo" "docs(spec): s-two pause 1"
git -C "$local_repo" rm -q "docs/specs/s-two.md"
commit "$local_repo" "docs(spec): drop s-two"
c=(); for rev in HEAD~4 HEAD~3 HEAD~2 HEAD~1 HEAD; do c+=("$(short "$local_repo" "$rev")"); done

render none "$local_repo"
expect_exit 0 "$status" "steps: render exits 0"
same "[\"${c[0]}\", \"${c[1]}\", \"${c[2]}\", \"${c[3]}\", \"${c[4]}\"]" "$(pick 'H')" \
  "steps: each commit that changed the idea, oldest first, the branch in flight last"
same "null" "$(pick 'R["note"]')" "steps: no note when gh answered"
same '{"at": "2026-10-01 09:01", "subject": "docs(spec): add idea shape", "pr": null}' \
  "$(pick '{k: R["steps"][0][k] for k in ("at", "subject", "pr")}')" "steps: a step has its date and time, subject and no PR"
same '[{"s-one": 1, "s-two": 0, "s-three": 0}, {"s-one": 3, "s-two": 0, "s-three": 0}, {"s-one": 4, "s-two": 0, "s-three": 0}, {"s-one": 4, "s-two": 1, "s-three": 0}, {"s-one": 4, "s-two": 0, "s-three": 0}]' \
  "$(pick '[s["stages"] for s in R["steps"]]')" "steps: the stage of each slice at each commit"
same '[[{"slice": "s-one", "from": 0, "to": 1}], [{"slice": "s-one", "from": 1, "to": 3}], [{"slice": "s-one", "from": 3, "to": 4}], [{"slice": "s-two", "from": 0, "to": 1}], [{"slice": "s-two", "from": 1, "to": 0}]]' \
  "$(pick '[s["moved"] for s in R["steps"]]')" "steps: moved names each slice that changed stage"
same '[{"file": "docs/specs/idea/shape.md", "items": [{"kind": "added", "what": "the shape"}]}, {"file": "docs/specs/s-one.md", "items": [{"kind": "added", "what": "the spec"}]}]' \
  "$(pick 'R["steps"][0]["changed"]')" "changed: the first step adds the shape, first, then the spec"
same '[{"file": "docs/specs/idea/shape.md", "items": [{"kind": "changed", "what": "Problem"}]}, {"file": "docs/specs/s-one.md", "items": [{"kind": "added", "what": "Interface"}, {"kind": "added", "what": "Technical plan"}]}]' \
  "$(pick 'R["steps"][1]["changed"]')" "changed: the shape comes first, and each item is compared as the gate card compares"
same '[{"file": "docs/specs/s-one.md", "items": []}]' \
  "$(pick 'R["steps"][2]["changed"]')" "changed: a Status-line change gives the file with no items"
same '[{"file": "docs/specs/s-two.md", "items": [{"kind": "removed", "what": "the spec"}]}]' \
  "$(pick 'R["steps"][4]["changed"]')" "changed: a spec that is gone is removed"
same "True" "$("$py" -c 'import json, sys; print(json.load(open(sys.argv[1])) == dict.fromkeys(sys.argv[2:]))' \
  "$local_repo/$cache" "$(full "$local_repo" HEAD~4)" "$(full "$local_repo" HEAD~3)" "$(full "$local_repo" HEAD~2)" 2>&1)" \
  "cache: each commit on main with no merged PR is cached as null"
expect_match "^api repos/\{owner\}/\{repo\}/commits/$(full "$local_repo" HEAD~2)/pulls --jq \[\.\[\] \| select\(\.merged_at\)\]\[0\]\.number$" \
  "$(cat "$work/bin/none.log")" "gh: asks for the merged PR of the full sha"
same "3" "$(wc -l <"$work/bin/none.log" | tr -d ' ')" "gh: one call for each commit on main, none for the branch in flight"
render none "$local_repo"
same "3" "$(wc -l <"$work/bin/none.log" | tr -d ' ')" "cache: a second render asks gh nothing"

# --- a subject with HTML in it ---
render none "$local_repo" render
page=$out
printf '%s' "$page" >"$work/page.html"
out=$("$py" -c 'import sys
page = open(sys.argv[1], encoding="utf-8").read()
start = page.index(">", page.index("<script id=\"data\"")) + 1
print(page[start:page.index("</script>", start)])' "$work/page.html")
same 'docs: <script>alert(1)</script> & </b>' "$(pick 'R["steps"][2]["subject"]')" \
  "html: the subject reads back whole from the page's data block"
expect_no_match 'alert\(1\)</script>' "$page" "html: the subject cannot end the data block"

# --- main is HEAD when there is no origin, main or master ---
trunk="$work/trunk"
git init -q -b trunk "$trunk"
shape "$trunk"
spec "$trunk" s-one p1
commit "$trunk" "docs(spec): add idea shape"
render none "$trunk"
same "[\"$(short "$trunk" HEAD)\"]" "$(pick 'H')" "main: with no main or master, HEAD gives the steps"

# --- a squash-merged PR: built in an author repo, then cloned ---
# origin's main has the shape commit and the squash of PR 1 (two pause
# commits of s-two). The clone has no PR objects until it fetches them.
author="$work/author"
origin="$work/origin.git"
git init -q -b main "$author"
shape "$author"
spec "$author" s-one p1
commit "$author" "docs(spec): add idea shape"
git -C "$author" checkout -q -b s-two
spec "$author" s-two p1
commit "$author" "docs(spec): s-two pause 1"
spec "$author" s-two p2
commit "$author" "docs(spec): s-two pause 2"
git -C "$author" checkout -q main
git -C "$author" merge -q --squash s-two >/dev/null
commit "$author" "feat(spec): s-two"
git init -q --bare -b main "$origin"
git -C "$author" push -q "$origin" main s-two:refs/pull/1/head
first=$(short "$author" main~1)
squash=$(full "$author" main)
pr=(); for rev in s-two~1 s-two; do pr+=("$(short "$author" "$rev")"); done
bin pr "case \"\$*\" in *$squash*) echo 1 ;; *) echo null ;; esac"

clone() { git clone -q --no-local "$origin" "$work/$1"; }

clone swap
render pr "$work/swap"
expect_exit 0 "$status" "swap: render exits 0"
same "[\"$first\", \"${pr[0]}\", \"${pr[1]}\"]" "$(pick 'H')" "swap: the squash commit is replaced by its PR's commits"
same "[null, 1, 1]" "$(pick '[s["pr"] for s in R["steps"]]')" "swap: the PR steps carry the PR number"
same "null" "$(pick 'R["note"]')" "swap: no note"
same "{\"head\": \"$(full "$author" s-two)\", \"pr\": 1}" \
  "$("$py" -c 'import json, sys; print(json.dumps(json.load(open(sys.argv[1]))[sys.argv[2]], sort_keys=True))' "$work/swap/$cache" "$squash" 2>&1)" \
  "swap: the cache keeps the PR number and its head"

git -C "$work/swap" remote set-url origin "$work/gone.git"
render nogh "$work/swap"
same "[\"$first\", \"${pr[0]}\", \"${pr[1]}\"]" "$(pick 'H')" "cache: with no gh and no origin, the cache still gives the PR steps"
same "null" "$(pick 'R["note"]')" "cache: no note, and no fetch when the head is in the repo"

clone denied
render fail "$work/denied"
expect_exit 0 "$status" "gh fails: render exits 0"
same "[\"$first\", \"$(short "$author" main)\"]" "$(pick 'H')" "gh fails: the squash commit stays one step"
same "PR commits not read: HTTP 401: Bad credentials. $tail_note" "$(pick 'R["note"]')" "gh fails: the note gives gh's first stderr line"
[ ! -e "$work/denied/$cache" ]
expect_exit 0 "$?" "gh fails: nothing is cached"

clone nogh
render nogh "$work/nogh"
same "[\"$first\", \"$(short "$author" main)\"]" "$(pick 'H')" "no gh: the squash commit stays one step"
same "PR commits not read: gh is not installed. $tail_note" "$(pick 'R["note"]')" "no gh: the note says gh is not installed"

clone offline
git -C "$work/offline" remote set-url origin "$work/gone.git"
render pr "$work/offline"
same "[\"$first\", \"$(short "$author" main)\"]" "$(pick 'H')" "fetch fails: the squash commit stays one step"
expect_match "^PR commits not read: fatal: '.*gone\.git' does not appear to be a git repository\. $tail_note\$" \
  "$(pick 'R["note"]')" "fetch fails: the note gives the fetch's first stderr line"
same "False" "$("$py" -c 'import json, os, sys; print(os.path.exists(sys.argv[1]) and sys.argv[2] in json.load(open(sys.argv[1])))' "$work/offline/$cache" "$squash" 2>&1)" \
  "fetch fails: the squash commit is not cached"

clone broken
mkdir -p "$work/broken/docs/specs/.pages"
orphan=$(git -C "$work/broken" -c user.name=Test -c user.email=test@example.com commit-tree -m orphan "$(git -C "$work/broken" rev-parse 'HEAD^{tree}')")
printf '{"%s": {"pr": 1, "head": "%s"}}' "$squash" "$orphan" >"$work/broken/$cache"
render nogh "$work/broken"
expect_exit 0 "$status" "other error: render still exits 0"
same "[]" "$(pick 'R["steps"]')" "other error: no steps"
expect_match '^Replay not read: .+' "$(pick 'R["note"]')" "other error: the note says replay was not read"
