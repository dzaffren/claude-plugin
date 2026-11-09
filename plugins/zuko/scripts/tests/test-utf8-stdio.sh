# Every Python process that zuko starts sets its stdio to UTF-8 with LF as its
# first statement (D98): each __main__ block in lib/*.py, and each inline
# python3 -c, python3 - and python3 <<'PY' in the hook scripts. Windows Python
# starts with cp1252 and CRLF, so a script that skips the loop breaks there
# only, and only a Windows run would show it.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

loop='reconfigure(encoding="utf-8", errors="surrogateescape", newline="\n")'

mains=0
for file in "$scripts"/lib/*.py; do
  grep -q '^if __name__ == "__main__":' "$file" || continue
  mains=$((mains + 1))
  name=lib/$(basename "$file")
  block=$(sed -n '/^if __name__ == "__main__":/,$p' "$file")
  if grep -qF -e "$loop" <<<"$block"; then record PASS "$name: __main__ sets stdio to UTF-8 with LF"
  else record FAIL "$name: __main__ sets stdio to UTF-8 with LF" "no $loop after __main__"; fi
done

snippets=0
for file in "$scripts"/*.sh; do
  name=$(basename "$file")
  launches=$(grep -vE '^[[:space:]]*#' "$file" | grep -cE 'python3 (-I )?(-c |- |<<)')
  [ "$launches" -gt 0 ] || continue
  snippets=$((snippets + launches))
  loops=$(grep -cF -e "$loop" "$file")
  if [ "$loops" -eq "$launches" ]; then record PASS "$name: each of $launches inline snippets sets stdio"
  else record FAIL "$name: each of $launches inline snippets sets stdio" "$loops of $launches hold $loop"; fi
done

# A check that found nothing to check is not a pass.
echo "  utf8-stdio: $mains __main__ blocks, $snippets inline snippets" >&2
if [ "$mains" -gt 0 ]; then record PASS "found the lib scripts ($mains)"
else record FAIL "found the lib scripts" "no __main__ block under $scripts/lib"; fi
if [ "$snippets" -gt 0 ]; then record PASS "found the inline snippets ($snippets)"
else record FAIL "found the inline snippets" "no python3 -c, - or << under $scripts"; fi
