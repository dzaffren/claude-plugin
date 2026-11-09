"""Strix, the optional second attacker of a release pentest (D112). release.py
loads this module; its strix command prints what scan() returns, and its
strix-install command prints what install() returns.

scan() checks that Strix can run: a strix on PATH at MINIMUM or newer (D114),
STRIX_LLM and LLM_API_KEY in the environment or in the env block of
~/.strix/cli-config.json, and docker info. Then it runs Strix on a git
archive of HEAD in its own folder, kills it after TIMEOUT, and reads the run
files. It gives one block for each finding in the release's files, one
OUTSIDE line for each other finding, and one last "STRIX: " line (D113).
Info findings are dropped. A run file it cannot read is a failure, never an
empty pass.

With a live URL, which the user confirmed in /release, Strix also attacks
that staging app with real requests (D118). No zuko hook sees them: the
instruction file asks for the one host and for reads, and that is all.
ready() runs the readiness check alone, so /release can ask before the run.
"""
import importlib.util
import io
import ipaddress
import json
import os
import re
import socket
import subprocess
import tarfile
from urllib.parse import urlsplit

# release.py loads this module by its path, so program.py is loaded the same way.
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("program", os.path.join(here, "program.py"))
program = importlib.util.module_from_spec(spec)
spec.loader.exec_module(program)

PIN = "1.7.0"
MINIMUM = (1, 7, 0)
TIMEOUT = 30 * 60
MODE = "standard"
BUDGET = 10
SEVERITIES = ("critical", "high", "medium", "low", "info")
CONFIG = "~/.strix/cli-config.json"
VERSION = re.compile(r"(\d+)\.(\d+)\.(\d+)")
MISSING = "STRIX: missing · strix-agent %s" % PIN
# Strix draws its error panels with these; a line of them alone says nothing.
BOX = "│╭╮╰╯─┃━ \t"


class Unreadable(Exception):
    """A run file scan() cannot trust; the message follows "unreadable: "."""


def call(args, **options):
    """(exit code, stdout, stderr); exit None when the program is not found."""
    try:
        done = subprocess.run(program.argv(args), capture_output=True, text=True,
                              encoding="utf-8", errors="surrogateescape", **options)
    except FileNotFoundError:
        return None, "", ""
    return done.returncode, done.stdout, done.stderr


def last_line(text):
    """The last line with words in it, Strix's box drawing stripped."""
    for line in reversed(text.splitlines()):
        words = line.strip(BOX)
        if words:
            return words
    return ""


def config_keys():
    """The env block of the Strix config file; {} when it is absent or unreadable.
    Only its key names are used: a value is never printed."""
    try:
        with open(os.path.expanduser(CONFIG), encoding="utf-8") as handle:
            block = json.load(handle).get("env")
    except (OSError, ValueError, AttributeError):
        return {}
    return block if isinstance(block, dict) else {}


def not_ready():
    """(None, version) when Strix can run, else (the STRIX: line, None)."""
    code, out, err = call(["strix", "--version"])
    if code is None:
        return MISSING, None
    found = VERSION.search(out + err)
    if code != 0 or found is None:
        return "STRIX: skipped · strix --version printed %r" % last_line(out + err), None
    version = found.group(0)
    if tuple(int(part) for part in found.groups()) < MINIMUM:
        return ("STRIX: skipped · strix %s may erase keys stored in %s; %s or newer is needed"
                % (version, CONFIG, ".".join(map(str, MINIMUM)))), None
    stored = config_keys()
    for key in ("STRIX_LLM", "LLM_API_KEY"):
        if not os.environ.get(key) and not stored.get(key):
            return "STRIX: skipped · no %s in the environment or %s" % (key, CONFIG), None
    code, out, err = call(["docker", "info"])
    if code is None:
        return "STRIX: skipped · docker info failed: docker not found", None
    if code != 0:
        first = next((line.strip() for line in (err + out).splitlines() if line.strip()), "exit %d" % code)
        return "STRIX: skipped · docker info failed: %s" % first, None
    return None, version


def ready():
    """The line release.py strix-ready prints: not_ready()'s, or "STRIX: ready"."""
    line, version = not_ready()
    return line or "STRIX: ready · %s" % version


def model():
    """STRIX_LLM as Strix reads it: the environment first, then the config file."""
    return os.environ.get("STRIX_LLM") or str(config_keys().get("STRIX_LLM", ""))


def live_host(url):
    """(the host, None) for a staging URL, else (None, why). Strix reaches this
    machine through host.docker.internal, which on Linux is the Docker bridge,
    not 127.0.0.1, so a loopback host is refused (D119)."""
    try:
        parts = urlsplit(url)
        scheme, host = parts.scheme, parts.hostname
    except ValueError:
        scheme, host = None, None
    if scheme not in ("http", "https") or not host:
        return None, "%s is not an http or https URL" % url
    name = host.rstrip(".")
    try:
        address = ipaddress.ip_address(name)
    except ValueError:
        # inet_aton reads IPv4 as the OS does: 127.1, 0, 2130706433, 0x7f.1.
        try:
            address = ipaddress.IPv4Address(socket.inet_aton(name))
        except OSError:
            address = None
    if address is not None:
        local = address.is_loopback or address.is_unspecified
    else:
        local = name == "localhost" or name.endswith(".localhost")
    if local:
        return None, "%s is this machine, which the Strix sandbox cannot reach" % host
    return host, None


def instruction(files, live=None):
    lines = ["This is a code-level pentest of one release, in the folder ./release.",
             "Attack these files first. This release changed them, or no pentest has checked them yet:", ""]
    lines += ["- %s" % path for path in files]
    if live:
        lines += ["", "This pentest also attacks the running app at %s." % live,
                  "Send requests to %s only." % live_host(live)[0],
                  "Read data. Change or delete only data that you created in this run.",
                  "Run no load or denial-of-service test."]
    else:
        lines += ["", "Send no request to any host outside your sandbox. The target is this folder only."]
    lines += ["Give each finding a code location: its file relative to the folder root, and its start line.", ""]
    return "\n".join(lines)


def copy_head(project, dest):
    """git archive HEAD, unpacked into dest."""
    done = subprocess.run(program.argv(["git", "-C", project, "archive", "--format=tar", "HEAD"]),
                          capture_output=True)
    if done.returncode != 0:
        raise Unreadable("git archive failed: %s" % last_line(done.stderr.decode("utf-8", "replace")))
    try:
        with tarfile.open(fileobj=io.BytesIO(done.stdout)) as archive:
            if hasattr(tarfile, "data_filter"):
                archive.extractall(dest, filter=inside_copy)
            else:
                archive.extractall(dest)
    except (tarfile.TarError, OSError) as error:
        raise Unreadable("git archive could not be unpacked: %s" % error)


def inside_copy(member, path):
    """The data filter, but a member it refuses, such as a link out of the
    tree, is left out of the copy instead of stopping the run."""
    try:
        return tarfile.data_filter(member, path)
    except tarfile.FilterError:
        return None


def run_dir(scratch):
    """The newest run folder under scratch/strix_runs that holds a run.json."""
    base = os.path.join(scratch, "strix_runs")
    runs = [os.path.join(base, name) for name in os.listdir(base)] if os.path.isdir(base) else []
    runs = [path for path in runs if os.path.isfile(os.path.join(path, "run.json"))]
    return max(runs, key=os.path.getmtime) if runs else None


def read_json(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError) as error:
        raise Unreadable("%s: %s" % (os.path.basename(path), error))


def cell(text):
    """One line of text that a report table cell can hold."""
    return " ".join(str(text).replace("|", "/").split())


def findings(path, code):
    """Strix's findings from vulnerabilities.json; Unreadable when one cannot be trusted."""
    if not os.path.isfile(path):
        # Strix writes the file only when it filed a finding; exit 2 says it did.
        if code == 2:
            raise Unreadable("vulnerabilities.json unreadable: missing after exit 2")
        return []
    try:
        data = read_json(path)
    except Unreadable as error:
        raise Unreadable("vulnerabilities.json unreadable: %s" % error)
    if not isinstance(data, list):
        raise Unreadable("vulnerabilities.json unreadable: not a list")
    found = []
    for item in data:
        if not isinstance(item, dict) or not isinstance(item.get("id"), str):
            raise Unreadable("vulnerabilities.json unreadable: a finding has no id")
        severity = str(item.get("severity", "")).strip().lower()
        if severity not in SEVERITIES:
            raise Unreadable('vulnerabilities.json unreadable: %s has severity "%s"'
                             % (item["id"], item.get("severity")))
        if not str(item.get("title", "")).strip():
            raise Unreadable("vulnerabilities.json unreadable: %s has no title" % item["id"])
        locations = item.get("code_locations") or []
        for spot in locations:
            if (not isinstance(spot, dict) or not isinstance(spot.get("file"), str)
                    or not isinstance(spot.get("start_line"), int)):
                raise Unreadable("vulnerabilities.json unreadable: %s has a code location "
                                 "with no file or start line" % item["id"])
        found.append(dict(item, severity=severity, code_locations=locations))
    return found


def blocks(found, files, where, live=False):
    """(the FINDING block lines, the OUTSIDE lines, the info count) for found.
    A live run's blocks also name Strix's method and endpoint."""
    wanted = set(files)
    lines, outside, info, number = [], [], 0, 0
    for item in found:
        if item["severity"] == "info":
            info += 1
            continue
        spots = item["code_locations"]
        inside = next((spot for spot in spots if spot["file"] in wanted), None)
        if spots and inside is None:
            outside.append("OUTSIDE: %s:%d · %s · %s" % (spots[0]["file"], spots[0]["start_line"],
                                                        item["severity"], cell(item["title"])))
            continue
        number += 1
        snippet = str((inside or {}).get("snippet") or "").strip().splitlines()
        lines += ["FINDING S%d" % number,
                  "STRIX-ID: %s" % item["id"],
                  "SEVERITY: %s" % item["severity"],
                  "CWE: %s" % (cell(item.get("cwe") or "") or "none"),
                  "TITLE: %s" % cell(item["title"]),
                  "FILE: %s" % ("%s:%d" % (inside["file"], inside["start_line"]) if inside else "none")]
        if live:
            lines.append("ENDPOINT: %s" % (cell(" ".join(str(item.get(key) or "") for key in ("method", "endpoint")))
                                           or "none"))
        lines += ["SNIPPET: %s" % (snippet[0].strip() if snippet else "none"),
                  "POC: %s" % os.path.join(where, "vulnerabilities", item["id"] + ".md").replace(os.sep, "/"),
                  ""]
    return lines, outside, info


def report(scratch, files, code, version, live=None):
    """The block and OUTSIDE lines and the last line for the run in scratch."""
    where = run_dir(scratch)
    if where is None:
        return ["STRIX: failed · no run.json under strix_runs"]
    try:
        run = read_json(os.path.join(where, "run.json"))
    except Unreadable as error:
        return ["STRIX: failed · run.json unreadable: %s" % error]
    status = run.get("status") if isinstance(run, dict) else None
    if status not in ("completed", "stopped"):
        return ["STRIX: failed · run.json status %s" % status]
    try:
        found = findings(os.path.join(where, "vulnerabilities.json"), code)
    except Unreadable as error:
        return ["STRIX: failed · %s" % error]
    cost = (run.get("llm_usage") or {}).get("cost")
    if not isinstance(cost, (int, float)):
        return ["STRIX: failed · run.json unreadable: no llm_usage cost"]
    lines, outside, info = blocks(found, files, where, bool(live))
    end = ["STRIX: %s" % ("done" if status == "completed" else "stopped"), version, MODE]
    if live:
        end.append("live %s" % live_host(live)[0])
    end += [model(), "$%.2f of $%d" % (cost, BUDGET), "%d found" % len(found)]
    if info:
        end.append("%d info dropped" % info)
    if outside:
        end.append("%d outside" % len(outside))
    coverage = os.path.join(where, "coverage.json")
    if os.path.isfile(coverage):
        try:
            complete = (read_json(coverage).get("completeness") or {}).get("complete")
        except (Unreadable, AttributeError):
            complete = None
        if complete is False:
            end.append("incomplete")
    return lines + outside + [" · ".join(end)]


def killed(scratch, files, live=None):
    """The block and OUTSIDE lines a killed run left. A kill runs no cleanup, so
    its run.json still says "running"; Strix wrote vulnerabilities.json with
    each finding, so the blocks come from that file alone."""
    where = run_dir(scratch)
    if where is None:
        return []
    try:
        found = findings(os.path.join(where, "vulnerabilities.json"), 0)
    except Unreadable:
        return []
    lines, outside, _ = blocks(found, files, where, bool(live))
    return lines + outside


def seconds(limit):
    return "%d minutes" % (limit // 60) if limit % 60 == 0 else "%d seconds" % limit


def scan(project, scratch, files, timeout=TIMEOUT, live=None):
    """The lines release.py strix prints. live is a staging URL that
    live_host() takes, and Strix attacks it next to the copy."""
    line, version = not_ready()
    if line:
        return [line]
    try:
        copy_head(project, os.path.join(scratch, "release"))
    except Unreadable as error:
        return ["STRIX: failed · %s" % error]
    with open(os.path.join(scratch, "instruction.md"), "w", encoding="utf-8", newline="\n") as handle:
        handle.write(instruction(files, live))
    args = ["strix", "-n", "-t", "./release"] + (["-t", live] if live else []) + ["--scan-mode", MODE, "--max-budget", str(BUDGET),
            "--scope-mode", "full", "--instruction-file", "instruction.md"]
    log = os.path.join(scratch, "strix.log")
    with open(log, "w", encoding="utf-8", errors="surrogateescape") as out:
        try:
            code = subprocess.run(program.argv(args), cwd=scratch, stdin=subprocess.DEVNULL,
                                  stdout=out, stderr=subprocess.STDOUT, timeout=timeout).returncode
        except subprocess.TimeoutExpired:
            code = None
        except FileNotFoundError:
            return [MISSING]
    if code is None:
        return killed(scratch, files, live) + ["STRIX: failed · timed out after %s" % seconds(timeout)]
    if code not in (0, 2):
        with open(log, encoding="utf-8", errors="replace") as handle:
            return ["STRIX: failed · exit %d · %s" % (code, last_line(handle.read()))]
    return report(scratch, files, code, version, live)


def install():
    """(exit code, the line strix-install prints)."""
    code, out, err = call(["uv", "tool", "install", "strix-agent==%s" % PIN])
    if code is None:
        return 1, "Strix install failed: uv not found"
    if code != 0:
        return 1, "Strix install failed: %s" % (last_line(err + out) or "exit %d" % code)
    return 0, "Strix %s installed" % PIN
