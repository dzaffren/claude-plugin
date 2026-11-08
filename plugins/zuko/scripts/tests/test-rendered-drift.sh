# scripts/check-rendered-drift.sh -- the parts of the rendered drift gate that
# need no browser: its Node lookup (E1, E2), its help, and the token-file list
# it shares with check-design-drift.sh (spec rendered-drift-check, scenario 4).
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

stage_bash=bash
[ -x /bin/bash ] && stage_bash=/bin/bash
"$stage_bash" -n "$scripts/check-rendered-drift.sh" 2>/dev/null
expect_exit 0 "$?" "the entry point parses under $stage_bash"
"$stage_bash" -n "$scripts/lib/token-files.sh" 2>/dev/null
expect_exit 0 "$?" "the token-file list parses under $stage_bash"

# One list of token files for both gates: the static gate finds what the
# shared function finds, in a project that has every kind of token file.
tok="$work/rendered-tokens"
mkdir -p "$tok/docs/design" "$tok/app" "$tok/node_modules/pkg"
printf ':root { --ink: #1a1a1a; }\n' >"$tok/docs/design/tokens.css"
printf ':root { --surface: #ffffff; }\n' >"$tok/app/globals.css"
printf 'module.exports = {}\n' >"$tok/tailwind.config.js"
printf ':root { --vendor: #000; }\n' >"$tok/node_modules/pkg/tokens.css"
listed=$(. "$scripts/lib/token-files.sh" && find_token_files "$tok" | sort)
expect_match 'docs/design/tokens\.css$' "$listed" "find_token_files lists tokens*.css"
expect_match 'app/globals\.css$' "$listed" "find_token_files lists globals.css"
expect_match 'tailwind\.config\.js$' "$listed" "find_token_files lists tailwind.config.*"
expect_no_match 'node_modules' "$listed" "find_token_files skips node_modules"
grep -q 'find_token_files' "$scripts/check-design-drift.sh"
expect_exit 0 "$?" "check-design-drift.sh takes its token files from find_token_files"

# The static gate still reads tokens from the shared list: an unknown token fails.
printf '<p style="color: var(--nope)">x</p>\n' >"$tok/docs/design/p.html"
out=$(cd "$tok" && CLAUDE_PROJECT_DIR="$tok" "$stage_bash" "$scripts/check-design-drift.sh" docs/design/p.html 2>&1)
expect_exit 1 "$?" "the static gate still fails an unknown token"
expect_match 'against|--nope' "$out" "the static gate still names the unknown token"

# -h prints the usage and exits 0, with no Node needed.
out=$(PATH="/usr/bin:/bin" "$stage_bash" "$scripts/check-rendered-drift.sh" -h 2>&1)
expect_exit 0 "$?" "-h exits 0"
expect_match '^usage: check-rendered-drift\.sh ' "$out" "-h prints the usage line"
expect_match 'Exit 2: could not render\.' "$out" "-h names the exit codes"

# E1: no node on PATH, and no node at the Windows install path.
nonode="$work/rendered-nonode"
mkdir -p "$nonode/bin" "$nonode/pf"
# Wrapper scripts, not links: a copied .exe cannot start away from its DLLs.
for t in dirname cat sed grep find sort head printf; do
  p=$(type -P "$t") || continue
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$p" >"$nonode/bin/$t"
  chmod +x "$nonode/bin/$t"
done
out=$(cd "$tok" && PATH="$nonode/bin" PROGRAMFILES="$nonode/pf" CLAUDE_PROJECT_DIR="$tok" "$stage_bash" "$scripts/check-rendered-drift.sh" docs/design/p.html 2>&1)
expect_exit 2 "$?" "no Node exits 2, never 0"
expect_match '^Rendered drift check could not run: Node not found\.$' "$out" "no Node prints E1"

# E2: a node that is older than 22.
old="$work/rendered-oldnode"
mkdir -p "$old"
printf '#!/bin/sh\necho v20.11.0\n' >"$old/node"
chmod +x "$old/node"
out=$(cd "$tok" && PATH="$old:$PATH" CLAUDE_PROJECT_DIR="$tok" "$stage_bash" "$scripts/check-rendered-drift.sh" docs/design/p.html 2>&1)
expect_exit 2 "$?" "Node older than 22 exits 2"
expect_match '^Rendered drift check could not run: Node v20\.11\.0 is older than 22\.$' "$out" "an old Node prints E2 with its version"

# Review B1: with no token file there is nothing to fix with, so the stage text
# must not send E7 to the "fix and re-render" loop. It announces a skip.
craft="$scripts/../references/craft.md"
section=$(sed -n '/^## Rendered drift check$/,/^## The two checks/p' "$craft")
expect_match 'no design system token file found' "$section" "craft.md gives E7 its own rule"
expect_match 'Rendered drift check skipped: no design system token file\. check-design-drift\.sh ran on' "$section" "craft.md announces the E7 skip with its reason"
