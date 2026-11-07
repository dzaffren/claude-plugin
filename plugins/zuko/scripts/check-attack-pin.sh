#!/usr/bin/env bash
# Notice: upstream changed a copied attack-class file after the pin.
# Usage: check-attack-pin.sh
# /release runs it before it dispatches the pentester (D93). It reads the pin
# from references/attack-classes/README.md and asks GitHub which upstream files
# changed since then. It only tells: it never touches the copy. When it cannot
# know -- no pin, no gh, offline, rate-limited -- it prints nothing and exits 0,
# so the pentest goes on with the pinned copy.
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
copy="$here/../references/attack-classes"
[ -f "$copy/README.md" ] || exit 0

pin=""
while IFS= read -r line || [ -n "$line" ]; do
  line=${line%$'\r'}
  case $line in
    "Pinned: "*) pin=${line#Pinned: }; break ;;
  esac
done <"$copy/README.md"
# The pin is data from a file: only a full commit sha goes to gh.
[[ $pin =~ ^[0-9a-f]{40}$ ]] || exit 0

command -v gh >/dev/null 2>&1 || exit 0
# A rename lists the new path as filename and the old one as previous_filename.
changed=$(gh api "repos/cloudflare/security-audit-skill/compare/$pin...main" --jq '.files[] | .filename, (.previous_filename // empty)' 2>/dev/null) || exit 0
changed=${changed//$'\r'/}   # gh ends each line with \r\n on Windows

# The glob sorts in C order, so the names come out sorted.
LC_ALL=C
shopt -s nullglob
hits=()
for file in "$copy"/*.md; do
  name=${file##*/}
  [ "$name" = README.md ] && continue
  if grep -qxF -e "skills/security-audit/$name" <<<"$changed"; then
    hits+=("$name")
  fi
done
[ "${#hits[@]}" -gt 0 ] || exit 0

list=${hits[0]}
for name in "${hits[@]:1}"; do list+=", $name"; done
echo "attack-classes: upstream changed $list after ${pin:0:7}. This pentest uses the pinned copy."
exit 0
