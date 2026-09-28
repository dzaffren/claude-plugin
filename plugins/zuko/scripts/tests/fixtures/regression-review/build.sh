#!/usr/bin/env bash
# Builds the seeded invoice-api repo for the regression-review run, with real
# history: base, then the fix(security) commit that adds @login_required to
# /export, then branch feat/public-export on top. Each layer is a folder here,
# copied over the tree and committed.
# Usage: build.sh <dir>   -- dir must not exist yet
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
dest=${1:?usage: build.sh <dir>}
if [ -e "$dest" ]; then
  echo "build.sh: $dest already exists" >&2
  exit 1
fi
mkdir -p "$dest"

# No global or system config, so an excludes file, a template or an alias on
# the machine cannot change what gets committed. The identity, signing and
# hooks are pinned too, and init takes no template.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
g() {
  git -C "$dest" -c user.name=Tester -c user.email=t@example.com \
    -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"
}
layer() {    # layer <folder> <commit subject>
  cp -R "$here/$1/." "$dest/"
  g add -A
  g commit -q -m "$2"
}

g init -q -b main --template=
layer base "feat: invoice api with reports and refunds"
layer fix "fix(security): require login on /export"
g switch -q -c feat/public-export
layer branch "feat: public export, refunds and raw report queries"
