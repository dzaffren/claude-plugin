# scripts/lib/strix.py, through release.py strix and strix-install -- the
# readiness check, the run on its own copy, the parse of the run files, and
# the pinned install. Stub strix, docker and uv stand in on a narrow PATH, and
# a fake HOME holds the Strix config.
# Sourced by run.sh, which provides $scripts, $work and the expect_* helpers.

work=$(mktemp -d -p "$work")
release="$scripts/lib/release.py"
fixtures="$scripts/tests/fixtures/strix-code"
py=$(python3 -c 'import sys; print(sys.executable)')

# The stubs. FAKE holds what each one does and what it was called with.
# The stubs run on the narrow PATH, so each one puts the full PATH back first.
# The PATH is written into the stub: on its way through Python, Git Bash turns
# a colon list in any other variable into Windows form, and never back.
FAKE="$work/fake"
export FAKE
stub() {       # stub <name>: the stub script on stdin, at $bin/<name>, with the full PATH
  { printf '#!/usr/bin/env bash\nPATH=%q\n' "$PATH"; cat; } >"$bin/$1"
  chmod +x "$bin/$1"
}
bin="$work/bin"
mkdir -p "$bin" "$FAKE"
is_windows || ln -s "$(command -v bash)" "$bin/bash"
stub strix <<'STUB'
if [ "$1" = "--version" ]; then echo "strix $(cat "$FAKE/version" 2>/dev/null || echo 1.7.0)"; exit 0; fi
printf '%s\n' "$@" >"$FAKE/args"
pwd >"$FAKE/cwd"
if [ -d "$FAKE/run" ]; then mkdir -p strix_runs/invoice-cli_a1b2; cp "$FAKE/run/"* strix_runs/invoice-cli_a1b2/; fi
[ -f "$FAKE/output" ] && cat "$FAKE/output"
[ -f "$FAKE/sleep" ] && sleep "$(cat "$FAKE/sleep")"
exit "$(cat "$FAKE/exit" 2>/dev/null || echo 2)"
STUB
stub docker <<'STUB'
[ "$1" = "info" ] || exit 9
[ -f "$FAKE/docker-error" ] && { cat "$FAKE/docker-error" >&2; exit 1; }
echo "Server Version: 29.9.2"
STUB
stub uv <<'STUB'
printf '%s\n' "$*" >"$FAKE/uv-args"
[ -f "$FAKE/uv-error" ] && { cat "$FAKE/uv-error" >&2; exit 2; }
echo "Installed 1 executable: strix"
STUB
narrow=$(narrow_path "$bin")

reset() {      # reset: Strix 1.7.0, Docker up, a run that files the fixture's five findings
  rm -rf "$FAKE"
  mkdir -p "$FAKE/run"
  cp "$fixtures/"*.json "$FAKE/run/"
}

home="$work/home"
mkdir -p "$home/.strix"
keys() {       # keys <json env block>: the Strix config file in the fake HOME
  printf '{"env": %s}\n' "$1" >"$home/.strix/cli-config.json"
}
both='{"STRIX_LLM": "anthropic/claude-sonnet-5-5", "LLM_API_KEY": "sk-ant-test-0000"}'

# A small invoice-cli repo. One file stays uncommitted, so the copy shows HEAD only.
repo="$work/repo"
mkdir -p "$repo/invoice_cli/exporters" "$repo/invoice_cli/importers"
git -C "$repo" init -q
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name t
for f in cli.py exporters/ledger.py exporters/suppliers.py importers/bank.py; do
  printf 'print("%s")\n' "$f" >"$repo/invoice_cli/$f"
done
git -C "$repo" add -A
git -C "$repo" commit -q --no-verify -m "feat: invoice cli"
echo 'print("draft")' >"$repo/invoice_cli/draft.py"
files="invoice_cli/cli.py,invoice_cli/exporters/ledger.py,invoice_cli/exporters/suppliers.py"

strix_run() {  # strix_run [env assignments...]: release.py strix; sets $out $status $scratch
  scratch=$(mktemp -d -p "$work")
  out=$(env -u STRIX_LLM -u LLM_API_KEY HOME="$home" USERPROFILE="$home" PATH="$narrow" "$@" \
        "$py" "$release" strix "$repo" --scratch "$scratch" --files "$files" 2>&1)
  status=$?
  out=${out//$'\r'/}
}
last() { printf '%s\n' "$out" | tail -n 1; }

# --- Scenario 3: no key, no model, an old strix, or no Docker skips Strix ---
reset; keys '{"STRIX_LLM": "anthropic/claude-sonnet-5-5"}'
strix_run
expect_exit 0 "$status" "strix: a skip exits 0"
expect_match '^STRIX: skipped · no LLM_API_KEY in the environment or ~/\.strix/cli-config\.json$' "$(last)" "strix: no key in either place is a skip"
[ ! -f "$FAKE/args" ]
expect_exit 0 "$?" "strix: a skip never starts a run"

keys '{"LLM_API_KEY": "sk-ant-test-0000"}'
strix_run
expect_match '^STRIX: skipped · no STRIX_LLM in the environment or ~/\.strix/cli-config\.json$' "$(last)" "strix: no model in either place is a skip"

rm -f "$home/.strix/cli-config.json"
strix_run STRIX_LLM=anthropic/claude-sonnet-5-5 LLM_API_KEY=sk-ant-test-0000
expect_match '^STRIX: done · ' "$(last)" "strix: keys in the environment alone are enough"

reset; keys "$both"
before=$(cksum <"$home/.strix/cli-config.json")
strix_run
expect_match '^STRIX: done · ' "$(last)" "strix: keys in the config file alone are enough"
expect_no_match 'sk-ant-test-0000' "$out" "strix: never prints the key"
[ "$before" = "$(cksum <"$home/.strix/cli-config.json")" ]
expect_exit 0 "$?" "strix: never writes the config file"

reset; echo 1.4.1 >"$FAKE/version"
strix_run
expect_match '^STRIX: skipped · strix 1\.4\.1 may erase keys stored in ~/\.strix/cli-config\.json; 1\.7\.0 or newer is needed$' "$(last)" "strix: an older strix is a skip"
[ ! -f "$FAKE/args" ]
expect_exit 0 "$?" "strix: an older strix never runs"

reset; echo 1.10.0 >"$FAKE/version"
strix_run
expect_match '^STRIX: done · 1\.10\.0 · ' "$(last)" "strix: 1.10.0 is newer than 1.7.0"

reset; echo "Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?" >"$FAKE/docker-error"
strix_run
expect_match '^STRIX: skipped · docker info failed: Cannot connect to the Docker daemon at unix:///var/run/docker\.sock\. Is the docker daemon running\?$' "$(last)" "strix: docker info failing is a skip"

# Windows starts a program from System32 before PATH (D107), so a docker.exe
# there cannot be hidden.
if is_windows && [ -e "$(cygpath -W)/System32/docker.exe" ]; then
  skip "strix: no docker is a skip" "docker.exe is in System32, which Windows searches before PATH"
else
  reset; mv "$bin/docker" "$work/docker.off"
  strix_run
  expect_match '^STRIX: skipped · docker info failed: docker not found$' "$(last)" "strix: no docker is a skip"
  mv "$work/docker.off" "$bin/docker"
fi

# --- Scenario 4: a missing strix, and the pinned install ---
reset; mv "$bin/strix" "$work/strix.off"
strix_run
expect_exit 0 "$status" "strix: missing exits 0"
expect_match '^STRIX: missing · strix-agent 1\.7\.0$' "$(last)" "strix: no strix on PATH is missing, with the pin"

install() {    # install: release.py strix-install; sets $out $status
  out=$(PATH="$narrow" "$py" "$release" strix-install "$repo" 2>&1)
  status=$?
  out=${out//$'\r'/}
}
install
expect_exit 0 "$status" "strix-install: exits 0 when uv installs"
expect_match '^tool install strix-agent==1\.7\.0$' "$(cat "$FAKE/uv-args")" "strix-install: runs the pinned uv tool install"
expect_match '^Strix 1\.7\.0 installed$' "$(last)" "strix-install: says what it installed"
echo "error: Failed to fetch: https://pypi.org/simple/strix-agent/" >"$FAKE/uv-error"
install
expect_exit 1 "$status" "strix-install: exits 1 when uv fails"
expect_match '^Strix install failed: error: Failed to fetch: https://pypi\.org/simple/strix-agent/$' "$(last)" "strix-install: prints uv's last line"
rm -f "$FAKE/uv-error"; mv "$bin/uv" "$work/uv.off"
install
expect_exit 1 "$status" "strix-install: exits 1 with no uv"
expect_match '^Strix install failed: uv not found$' "$(last)" "strix-install: says that uv is not found"
mv "$work/uv.off" "$bin/uv"; mv "$work/strix.off" "$bin/strix"

# --- The run: its own copy, its command line, and the parse ---
reset; keys "$both"
strix_run
expect_exit 0 "$status" "strix: a finished run exits 0"
expect_match '^STRIX: done · 1\.7\.0 · standard · anthropic/claude-sonnet-5-5 · \$3\.80 of \$10 · 5 found · 1 info dropped · 1 outside · incomplete$' "$(last)" "strix: the done line counts, costs and says incomplete"
[ "$(cd "$(cat "$FAKE/cwd")" && pwd -P)" = "$(cd "$scratch" && pwd -P)" ]
expect_exit 0 "$?" "strix: runs from the scratch folder"
expect_match '^-n$' "$(cat "$FAKE/args")" "strix: headless"
args=$(tr '\n' ' ' <"$FAKE/args")
expect_match '-t \./release --scan-mode standard --max-budget 10 --scope-mode full --instruction-file instruction\.md' "$args" "strix: the pinned command line"
[ -f "$scratch/release/invoice_cli/exporters/ledger.py" ] && [ ! -e "$scratch/release/invoice_cli/draft.py" ]
expect_exit 0 "$?" "strix: the copy is git archive HEAD, with no uncommitted file"
[ ! -e "$repo/strix_runs" ]
expect_exit 0 "$?" "strix: writes no strix_runs in the repo"
instruction=$(cat "$scratch/instruction.md")
expect_match '^- invoice_cli/exporters/ledger\.py$' "$instruction" "strix: the instruction names the files to attack first"
expect_match 'Send no request to any host' "$instruction" "strix: the instruction keeps Strix off the network"

block=$(awk '/^FINDING S1$/ { f = 1 } f && /^$/ { exit } f' <<<"$out")
expect_match '^STRIX-ID: vuln-0001$' "$block" "strix: S1 is Strix's first finding"
expect_match '^SEVERITY: high$' "$block" "strix: S1 keeps its severity"
expect_match '^CWE: CWE-89$' "$block" "strix: S1 has its CWE"
expect_match '^TITLE: Ledger export builds ORDER BY / LIMIT from the --sort option$' "$block" "strix: a | in a title is written /"
expect_match '^FILE: invoice_cli/exporters/ledger\.py:31$' "$block" "strix: FILE is the location and its start line"
expect_match '^SNIPPET: cursor\.execute\("SELECT \* FROM invoices ORDER BY " \+ sort\)$' "$block" "strix: SNIPPET is the first line of the snippet"
expect_match '^POC: [^\\]*strix_runs/invoice-cli_a1b2/vulnerabilities/vuln-0001\.md$' "$block" "strix: POC names the finding's file, with / on every OS (D116)"
expect_match '^FILE: invoice_cli/exporters/suppliers\.py:29$' "$(awk '/^FINDING S2$/ { f = 1 } f && /^$/ { exit } f' <<<"$out")" "strix: FILE skips a location outside --files"
expect_match '^FILE: none$' "$(awk '/^FINDING S3$/ { f = 1 } f && /^$/ { exit } f' <<<"$out")" "strix: a finding with no location gets FILE: none"
expect_match '^OUTSIDE: invoice_cli/importers/bank\.py:58 · low · Bank import logs the full account number$' "$out" "strix: a finding outside --files is an OUTSIDE line"
expect_no_match 'vuln-0004|Version banner' "$out" "strix: an info finding is dropped"
expect_no_match '^FINDING S4$' "$out" "strix: only three blocks"

# A committed symlink that leaves the repo is left out of the copy, and Strix still runs.
linked="$work/linked"
git clone -q "$repo" "$linked"
if make_link /etc/hostname "$linked/host" && make_link ../../outside "$linked/up"; then
  git -C "$linked" -c user.email=t@example.com -c user.name=t add -A
  git -C "$linked" -c user.email=t@example.com -c user.name=t commit -q --no-verify -m "chore: links"
  reset; keys "$both"
  scratch=$(mktemp -d -p "$work")
  out=$(env -u STRIX_LLM -u LLM_API_KEY HOME="$home" USERPROFILE="$home" PATH="$narrow" \
        "$py" "$release" strix "$linked" --scratch "$scratch" --files "$files" 2>&1)
  expect_exit 0 "$?" "strix: a repo with a link out of the tree exits 0"
  out=${out//$'\r'/}
  expect_match '^STRIX: done · ' "$(last)" "strix: a link out of the tree does not stop the run"
  [ ! -e "$scratch/release/host" ] && [ ! -L "$scratch/release/host" ] && [ ! -L "$scratch/release/up" ] && [ -f "$scratch/release/invoice_cli/cli.py" ]
  expect_exit 0 "$?" "strix: the copy leaves out each link out of the tree, and keeps the rest"
else
  skip "strix: a link out of the tree does not stop the run" "this OS made no real symlink"
fi

# --- Scenario 5: a run that fails or stops is said ---
reset; rm -rf "$FAKE/run"; echo 1 >"$FAKE/exit"
printf 'Pulling image ghcr.io/usestrix/strix-sandbox:1.3.0\nDocker daemon not reachable\n' >"$FAKE/output"
strix_run
expect_exit 0 "$status" "strix: a failed run exits 0"
expect_match '^STRIX: failed · exit 1 · Docker daemon not reachable$' "$(last)" "strix: exit 1 names its last line"

reset; rm -rf "$FAKE/run"; echo 1 >"$FAKE/exit"
printf '│  MISSING REQUIRED ENVIRONMENT VARIABLES      │\n│                                              │\n╰──────────────────────────────────────────────╯\n' >"$FAKE/output"
strix_run
expect_match '^STRIX: failed · exit 1 · MISSING REQUIRED ENVIRONMENT VARIABLES$' "$(last)" "strix: the last line skips Strix's box drawing"

reset; "$py" - "$FAKE/run/run.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1])); data["status"] = "stopped"; data["llm_usage"]["cost"] = 10.0
json.dump(data, open(sys.argv[1], "w"))
PY
strix_run
expect_match '^STRIX: stopped · 1\.7\.0 · standard · anthropic/claude-sonnet-5-5 · \$10\.00 of \$10 · 5 found · 1 info dropped · 1 outside · incomplete$' "$(last)" "strix: a budget stop is stopped"
expect_match '^FINDING S1$' "$out" "strix: a stopped run still gives its blocks"

reset; "$py" - "$FAKE/run/run.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1])); data["status"] = "failed"
json.dump(data, open(sys.argv[1], "w"))
PY
strix_run
expect_match '^STRIX: failed · run.json status failed$' "$(last)" "strix: run.json status failed is a failure"

reset; rm -f "$FAKE/run/vulnerabilities.json"
strix_run
expect_match '^STRIX: failed · vulnerabilities\.json unreadable: missing after exit 2$' "$(last)" "strix: exit 2 with no vulnerabilities.json fails closed"

reset; rm -f "$FAKE/run/vulnerabilities.json" "$FAKE/run/coverage.json"; echo 0 >"$FAKE/exit"
strix_run
expect_match '^STRIX: done · 1\.7\.0 · standard · anthropic/claude-sonnet-5-5 · \$3\.80 of \$10 · 0 found$' "$(last)" "strix: exit 0 with no findings is 0 found"

reset; sed -i.bak 's/"severity": "high"/"severity": "urgent"/' "$FAKE/run/vulnerabilities.json"; rm -f "$FAKE/run/"*.bak
strix_run
expect_match '^STRIX: failed · vulnerabilities\.json unreadable: vuln-0001 has severity "urgent"$' "$(last)" "strix: an unknown severity fails closed"
expect_no_match '^FINDING' "$out" "strix: an unreadable run gives no blocks"

reset; rm -rf "$FAKE/run"; echo 0 >"$FAKE/exit"
strix_run
expect_match '^STRIX: failed · no run\.json under strix_runs$' "$(last)" "strix: no run.json is a failure"

# The 30-minute limit, called with 1 second: a 30-minute test cannot run.
# A killed Strix runs no cleanup, so its run.json still says "running".
reset; echo 5 >"$FAKE/sleep"
"$py" - "$FAKE/run/run.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1])); data["status"] = "running"
json.dump(data, open(sys.argv[1], "w"))
PY
scratch=$(mktemp -d -p "$work")
out=$(env -u STRIX_LLM -u LLM_API_KEY HOME="$home" USERPROFILE="$home" PATH="$narrow" "$py" - "$scripts/lib" "$repo" "$scratch" "$files" <<'PY' 2>&1
import importlib.util, os, sys
sys.stdout.reconfigure(encoding="utf-8", newline="\n")
spec = importlib.util.spec_from_file_location("strix", os.path.join(sys.argv[1], "strix.py"))
strix = importlib.util.module_from_spec(spec); spec.loader.exec_module(strix)
for line in strix.scan(sys.argv[2], sys.argv[3], sys.argv[4].split(","), timeout=1):
    print(line)
PY
)
out=${out//$'\r'/}
expect_match '^STRIX: failed · timed out after 1 seconds$' "$(last)" "strix: a run past its limit is killed"
expect_match '^FINDING S1$' "$out" "strix: a timed-out run still gives the blocks it wrote"
grep -qE '^TIMEOUT = 30 \* 60$' "$scripts/lib/strix.py"
expect_exit 0 "$?" "strix: the limit is 30 minutes"

# Bad usage.
out=$("$py" "$release" strix "$repo" --files "$files" 2>&1)
expect_exit 2 "$?" "strix: needs --scratch"
out=$("$py" "$release" strix "$repo" --scratch "$work/nowhere" --files "$files" 2>&1)
expect_exit 2 "$?" "strix: --scratch must be a folder"

# --- strix-live scenario 5: strix-ready checks, and runs no scan ---
ready() {      # ready: release.py strix-ready; sets $out $status
  out=$(env -u STRIX_LLM -u LLM_API_KEY HOME="$home" USERPROFILE="$home" PATH="$narrow" \
        "$py" "$release" strix-ready "$repo" 2>&1)
  status=$?
  out=${out//$'\r'/}
}
reset; keys "$both"
ready
expect_exit 0 "$status" "strix-ready: exits 0"
expect_match '^STRIX: ready · 1\.7\.0$' "$out" "strix-ready: a ready Strix says so, with its version"
[ ! -f "$FAKE/args" ]
expect_exit 0 "$?" "strix-ready: runs no scan"
keys '{"STRIX_LLM": "anthropic/claude-sonnet-5-5"}'
ready
expect_match '^STRIX: skipped · no LLM_API_KEY in the environment or ~/\.strix/cli-config\.json$' "$out" "strix-ready: no key is the strix skip line"
reset; keys "$both"; echo 1.4.1 >"$FAKE/version"
ready
expect_match '^STRIX: skipped · strix 1\.4\.1 may erase keys stored in ~/\.strix/cli-config\.json; 1\.7\.0 or newer is needed$' "$out" "strix-ready: an older strix is the strix skip line"
reset; echo "Cannot connect to the Docker daemon" >"$FAKE/docker-error"
ready
expect_match '^STRIX: skipped · docker info failed: Cannot connect to the Docker daemon$' "$out" "strix-ready: docker info failing is the strix skip line"
reset; mv "$bin/strix" "$work/strix.off"
ready
expect_exit 0 "$status" "strix-ready: missing exits 0"
expect_match '^STRIX: missing · strix-agent 1\.7\.0$' "$out" "strix-ready: no strix on PATH is missing, with the pin"
mv "$work/strix.off" "$bin/strix"
out=$("$py" "$release" strix-ready "$repo" --files x 2>&1)
expect_exit 2 "$?" "strix-ready: takes no option"

# --- strix-live scenario 4: --live refuses this machine and a URL that is not http ---
live_files="invoice_api/routes.py"
live_run() {   # live_run <url>: release.py strix --live <url>; sets $out $status $scratch
  scratch=$(mktemp -d -p "$work")
  out=$(env -u STRIX_LLM -u LLM_API_KEY HOME="$home" USERPROFILE="$home" PATH="$narrow" \
        "$py" "$release" strix "$repo" --scratch "$scratch" --files "$live_files" --live "$1" 2>&1)
  status=$?
  out=${out//$'\r'/}
}
reset; keys "$both"
# The OS reads shorthand IPv4 and a trailing dot as these hosts too.
for url in http://127.0.0.1:5000 http://localhost:5000 'http://[::1]:5000' http://0.0.0.0:5000 http://app.localhost:5000 http://127.1.2.3/ \
           http://127.1:5000 http://0:5000 http://2130706433/ http://0x7f.1/ http://localhost.:5000; do
  live_run "$url"
  expect_exit 2 "$status" "strix --live: $url is refused"
  expect_match '^release\.py: --live takes a staging URL; .+ is this machine, which the Strix sandbox cannot reach$' "$out" "strix --live: $url names why"
done
live_run http://127.0.0.1:5000
expect_match '^release\.py: --live takes a staging URL; 127\.0\.0\.1 is this machine, which the Strix sandbox cannot reach$' "$out" "strix --live: the refusal names the host"
for url in ftp://staging.invoice-api.example.net staging.invoice-api.example.net 'https://'; do
  live_run "$url"
  expect_exit 2 "$status" "strix --live: $url is refused"
  expect_match "^release\\.py: --live takes a staging URL; .* is not an http or https URL\$" "$out" "strix --live: $url is not an http or https URL"
done
[ ! -f "$FAKE/args" ]
expect_exit 0 "$?" "strix --live: a refused URL runs no strix"

# --- strix-live scenarios 1 and 2: one run on the copy and the URL ---
live_reset() { # live_reset: Strix ready, a run that files the strix-live fixture's two live findings
  reset
  rm -f "$FAKE/run/"*
  cp "$scripts/tests/fixtures/strix-live/"*.json "$FAKE/run/"
}
live_reset; keys "$both"
live_run https://staging.invoice-api.example.net
expect_exit 0 "$status" "strix --live: a finished run exits 0"
expect_match '^STRIX: done · 1\.7\.0 · standard · live staging\.invoice-api\.example\.net · anthropic/claude-sonnet-5-5 · \$6\.20 of \$10 · 2 found$' "$(last)" "strix --live: the done line names the host"
args=$(tr '\n' ' ' <"$FAKE/args")
expect_match '-t \./release -t https://staging\.invoice-api\.example\.net --scan-mode standard --max-budget 10 --scope-mode full --instruction-file instruction\.md' "$args" "strix --live: the copy, then the URL, as targets"
instruction=$(cat "$scratch/instruction.md")
expect_match '^This pentest also attacks the running app at https://staging\.invoice-api\.example\.net\.$' "$instruction" "strix --live: the instruction names the URL"
expect_match '^Send requests to staging\.invoice-api\.example\.net only\.$' "$instruction" "strix --live: the instruction names the one host"
expect_match '^Read data\. Change or delete only data that you created in this run\.$' "$instruction" "strix --live: the instruction asks for reads"
expect_match '^Run no load or denial-of-service test\.$' "$instruction" "strix --live: the instruction asks for no load test"
expect_no_match 'Send no request to any host' "$instruction" "strix --live: the instruction drops the no-request line"
expect_match '^- invoice_api/routes\.py$' "$instruction" "strix --live: the instruction still names the files"
expect_match '^ENDPOINT: GET /invoices/1042$' "$(grep -A1 '^FILE: invoice_api/routes\.py:88$' <<<"$out" | tail -n 1)" "strix --live: ENDPOINT follows FILE"
s2=$(awk '/^FINDING S2$/ { f = 1 } f && /^$/ { exit } f' <<<"$out")
expect_match '^FILE: none$' "$s2" "strix --live: a live finding with no location has FILE: none"
expect_match '^ENDPOINT: GET /admin/export$' "$s2" "strix --live: and its endpoint"
expect_match '^POC: [^\\]*strix_runs/[^/]+/vulnerabilities/vuln-0002\.md$' "$s2" "strix --live: and its PoC path"

live_reset; "$py" - "$FAKE/run/vulnerabilities.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
del data[0]["method"]
data[0]["endpoint"] = "/invoices/1042|export"
del data[1]["method"], data[1]["endpoint"]
json.dump(data, open(sys.argv[1], "w"))
PY
live_run https://staging.invoice-api.example.net
expect_match '^ENDPOINT: /invoices/1042/export$' "$out" "strix --live: an endpoint with no method, with | as /"
expect_match '^ENDPOINT: none$' "$out" "strix --live: no endpoint is ENDPOINT: none"

live_reset; "$py" - "$FAKE/run/run.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1])); data["status"] = "stopped"
json.dump(data, open(sys.argv[1], "w"))
PY
live_run https://staging.invoice-api.example.net:8443/app
expect_match '^STRIX: stopped · 1\.7\.0 · standard · live staging\.invoice-api\.example\.net · ' "$(last)" "strix --live: the stopped line names the host"
expect_match '-t https://staging\.invoice-api\.example\.net:8443/app ' "$(tr '\n' ' ' <"$FAKE/args")" "strix --live: the URL goes to Strix as given"

# --- strix-live scenario 3: with no --live, the run is strix-code's ---
live_reset; keys "$both"
strix_run
expect_match '^STRIX: done · 1\.7\.0 · standard · anthropic/claude-sonnet-5-5 · \$6\.20 of \$10 · 2 found · 1 outside$' "$(last)" "strix: with no --live, the done line names no host"
expect_no_match '^ENDPOINT:' "$out" "strix: with no --live, no block has an ENDPOINT line"
expect_match '-t \./release --scan-mode' "$(tr '\n' ' ' <"$FAKE/args")" "strix: with no --live, the copy is the only target"
expect_match 'Send no request to any host' "$(cat "$scratch/instruction.md")" "strix: with no --live, the instruction keeps Strix off the network"
