# One walk through lf-checkout: clone zuko as Git for Windows does
# (core.autocrlf=true) and check the line ends that arrive. Sourced by run.sh,
# which provides $scripts and the expect_* helpers. core.autocrlf converts on
# every OS, so this proves the rule on Linux and macOS too.

root=$(cd "$scripts/../../.." && pwd)
work=$(mktemp -d)

# Clone the repo, then commit the work tree's .gitattributes on top, so the
# test also judges a rule that is not committed yet.
git clone -q "$root" "$work/src"
cp "$root/.gitattributes" "$work/src/.gitattributes"
git -C "$work/src" add .gitattributes
git -C "$work/src" diff --cached --quiet ||
  git -C "$work/src" -c user.name=Tester -c user.email=t@example.com \
    commit -q -m "test: the work tree's .gitattributes"

git -c core.autocrlf=true clone -q "$work/src" "$work/win"
win="$work/win"

# grep cannot judge a CR: Git Bash's grep strips it at each line end before it
# matches. A bash pattern sees every byte.
has_cr() { [[ $1 == *$'\r'* ]] && echo yes || echo no; }

# Scenario 1: a Windows clone of zuko gets LF text files.
for path in plugins/zuko/scripts/block-attribution.sh \
            plugins/zuko/skills/ship/SKILL.md \
            plugins/zuko/scripts/lib/release.py; do
  expect_exit no "$(has_cr "$(<"$win/$path")")" "scenario 1: $path has no CR byte"
done
eol=$(git -C "$win" ls-files --eol)
expect_match 'w/lf' "$eol" "scenario 1: ls-files --eol lists files"
expect_no_match 'w/crlf' "$eol" "scenario 1: no tracked file is w/crlf"

# Scenario 2: vendored files arrive byte for byte.
vendored=$(git -C "$win" ls-files .agents/skills)
expect_match '^\.agents/skills/shadcn/assets/shadcn\.png$' "$vendored" \
  "scenario 2: the vendored files include shadcn.png"
changed=""
while IFS= read -r path; do
  [ -n "$path" ] || continue
  git -C "$win" cat-file blob "HEAD:$path" | cmp -s - "$win/$path" ||
    changed="$changed $path"
done <<<"$vendored"
expect_exit "" "$changed" "scenario 2: each vendored file equals its committed blob"

# Scenario 3: a CRLF file goes into the index as LF. Staged with
# core.autocrlf=false, git's default on Linux and macOS: with autocrlf=true,
# git strips the CR on add even without the rule.
printf '# Refunds\r\n\r\nA refund stops at the order total.\r\n' >"$win/docs/specs/refunds.md"
git -C "$win" -c core.autocrlf=false add docs/specs/refunds.md
staged=$(git -C "$win" cat-file blob :docs/specs/refunds.md)
expect_match 'A refund stops at the order total\.' "$staged" "scenario 3: refunds.md is staged"
expect_exit no "$(has_cr "$staged")" "scenario 3: the staged blob has no CR byte"

rm -rf "$work"
