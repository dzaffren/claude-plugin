#!/usr/bin/env python3
"""Build an idea's board from its shape, the specs it names and DECISIONS.md.

Usage: board.py render <shape.md> --by <text> [--gate <file>]
       board.py data   <shape.md> --by <text> [--gate <file>]
       board.py serve  <dir>
       board.py library <root>

The shape is docs/specs/{idea}/shape.md, so the project root is three folders
above the shape's folder. Each row of the first table under "## Slices" that
has a Slice column is a slice, and the cell names its spec,
docs/specs/{name}.md. Sections and ledger rows are read with pr_body.py's
parser and entries with decisions.py's, so the board reads them as the gates
do. The rule for each part is in docs/specs/idea-board.md, "How the script
reads each part".

--gate names the file at a stop: the shape itself, or the spec of one of its
slices at pause 1, 2 or 3. The JSON then has a "gate" for the card, built by
comparing the file with its copy from the last stop,
docs/specs/.pages/{name}-last.md, or {idea}-shape-last.md for the shape. Any
other file, and no --gate, gives a null gate. The rules are in
docs/specs/gate-card.md, "How the script builds the gate".

  render  board.html with its JSON slot filled: the page to publish
  data    only the JSON, for the tests
  serve   serves <dir> on 127.0.0.1:4751 until stopped. Any Host header but
          127.0.0.1:4751 or localhost:4751 gets 400, so a page on another
          site cannot read the board through DNS rebinding
  library the hub's Ideas section, one row for each docs/specs/*/shape.md
          under <root>, as an HTML fragment to paste into the hub. No shape
          gives no output. The rules are in docs/specs/library.md, "Interface"

Exit 0 printed, or the server stopped. Exit 1 the port cannot be bound, most
often because it is in use. Exit 2 bad usage, a shape, spec or --gate file
that cannot be read, a shape with no Slices table, or a <dir> or <root> that
is not a directory. library never exits 2 for a shape: a shape it cannot read
is an error row.
"""
import datetime
import html
import http.server
import json
import os
import re
import sys

import decisions
import pr_body

USAGE = ("Usage: board.py render <shape.md> --by <text> [--gate <file>]\n"
         "       board.py data   <shape.md> --by <text> [--gate <file>]\n"
         "       board.py serve  <dir>\n"
         "       board.py library <root>")

TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "board.html")
SLOT = "/*DATA*/null"
PORT = 4751

STATUS = re.compile(r"\*\*Status:\*\*\s*([^·\n]+)")
TYPE = re.compile(r"\*\*Project type:\*\*\s*([^·\n]+)")
BOARD = re.compile(r"^\*\*Board:\*\*\s*(\S+)", re.M)
DEPENDS = re.compile(r"^\*\*Depends on:\*\*(.*)$", re.M)
DIVIDER = re.compile(r"^:?-+:?$")
SHOWN = ("Resolved", "Accepted risk", "Decided alone")
SCENARIO = re.compile(r"^\s*Scenario:\s*(.+?)\s*$")
LEAD_IN = re.compile(r"^\*\*([^*]+)\*\*$")
IN_LINE = re.compile(r"^\*\*In:\*\*\s*(.*)$")
LIGHT = re.compile(r"^\*\*Path:\*\*\s*light\b", re.M)
LIST = r"(\d+(?:\s*(?:,|\band\b|\bto\b|[–-])\s*\d+)*)"
LISTED = re.compile(r"^\s*" + LIST)
NAMED = re.compile(r"\bscenarios?\s+" + LIST, re.I)
CODE = re.compile(r"`([^`]+)`")
CODE_PATH = re.compile(r"docs/specs/\S+?\.md")
STAGES = ("Not started", "Pause 1", "Pause 2", "Pause 3", "Refined", "Built", "Reviewed", "Shipped")
NOT_PROSE = ("#", "|", "```", "~~~", "- ", "* ", "+ ", ">", "<", "**")


class Refused(Exception):
    pass


def read(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except (OSError, UnicodeDecodeError) as error:
        raise Refused("cannot read %s: %s" % (path, getattr(error, "strerror", None) or error))


def squeezed(lines):
    return " ".join(" ".join(lines).split())


def cells(line):
    return [cell.strip() for cell in pr_body.CELL.split(line.strip())[1:-1]]


def spec_name(cell):
    """`/release` -> release, OWASP lens -> owasp-lens."""
    return "-".join(cell.replace("`", "").strip().lstrip("/").lower().split())


def slice_rows(lines):
    """(name, what ships, why this order) for each row of the first table with
    a Slice column."""
    header, rows = None, []
    for line in lines:
        if not line.lstrip().startswith("|"):
            if header is not None:
                break
            continue
        found = cells(line)
        if header is None:
            if "Slice" in found:
                header = found
            continue
        if all(DIVIDER.match(cell) for cell in found):
            continue
        at = dict(zip(header, found))
        name = spec_name(at.get("Slice", ""))
        if name:
            rows.append((name, at.get("What ships", ""), at.get("Why this order", "")))
    return rows


def closes(line, fence):
    """A fence closes on its own character, at least as long, nothing after."""
    marker = pr_body.FENCE.match(line)
    return bool(marker) and marker.group(1)[0] == fence[0] \
        and len(marker.group(1)) >= len(fence) and not line[marker.end():].strip()


def stage(text, found):
    """0 Not started .. 7 Shipped, from the Status line and the sections."""
    match = STATUS.search(text)
    status = match.group(1).strip() if match else ""
    if status == "Shipped":
        return 7
    if status == "Built":
        return 6 if "Review" in found else 5
    if status == "Refined":
        return 4
    if "Technical plan" in found:
        return 3
    if "Interface" in found:
        return 2
    return 1


def paragraphs(lines):
    out, para = [], []
    for line in lines:
        if line.strip():
            para.append(line.strip())
        elif para:
            out.append(para)
            para = []
    if para:
        out.append(para)
    return out


def opening(text):
    """The first prose paragraph above the first "## " heading or fence."""
    head = []
    for line in text.splitlines():
        if line.startswith("## ") or pr_body.FENCE.match(line):
            break
        head.append(line)
    for para in paragraphs(head):
        if not para[0].startswith(NOT_PROSE):
            return squeezed(para)
    return ""


def say(lines):
    """The paragraph right under a fence, when it is prose."""
    para = []
    for line in lines:
        if line.strip():
            para.append(line.strip())
        elif para:
            break
    if not para or para[0].startswith(NOT_PROSE):
        return ""
    return squeezed(para)


def diagrams(text):
    """{caption, src, say} for each mermaid fence outside "## Open items"."""
    lines = text.splitlines()
    found, caption, section, fence, info, body = [], "", None, "", "", []
    for i, line in enumerate(lines):
        if fence:
            if closes(line, fence):
                if info == "mermaid" and section != "Open items":
                    found.append({"caption": caption, "src": "\n".join(body), "say": say(lines[i + 1:])})
                fence = ""
            else:
                body.append(line)
            continue
        marker = pr_body.FENCE.match(line)
        if marker:
            words = line[marker.end():].split()
            fence, info, body = marker.group(1), words[0] if words else "", []
        elif line.startswith("## "):
            section = caption = line[3:].strip()
        elif line.startswith("### "):
            caption = line[4:].strip()
    return found


def needs(text, name, names):
    """The slices this spec's Depends on line names, before any dash or full stop."""
    match = DEPENDS.search(text)
    if not match:
        return []
    said = match.group(1).split(" — ")[0].split(". ")[0].lower()
    return [other for other in names if other != name and
            re.search(r"(?<![a-z0-9-])%s(?![a-z0-9-])" % re.escape(other), said)]


def rejected(text):
    """Rejected options, split on commas outside parentheses."""
    out, depth, current = [], 0, ""
    for char in text:
        depth += (char == "(") - (char == ")")
        if char == "," and depth == 0:
            out.append(current.strip())
            current = ""
        else:
            current += char
    out.append(current.strip().rstrip("."))
    return [option for option in out if option]


def choices(entries, name):
    """The D-entries whose Source is this slice's spec, newest first."""
    mine = [entry for entry in entries if entry.value("Source") == "specs/%s.md" % name]
    return [{"id": "D%d" % entry.n, "title": decisions.HEADING.match(entry.heading).group(3),
             "why": entry.value("Why"), "rejected": rejected(entry.value("Rejected"))}
            for entry in sorted(mine, key=lambda entry: -entry.n)]


def answers(ledger):
    """The Resolved, Accepted risk and Decided alone rows of the ledger."""
    rows = []
    for line in ledger:
        if not pr_body.ROW.match(line):
            continue
        found = cells(line)
        if len(found) >= 7 and found[5] in SHOWN:
            rows.append({"id": found[0], "status": found[5], "answer": found[6].replace("\\|", "|")})
    return rows


def raw_sections(text):
    """pr_body.sections, but each section keeps its fence lines, markers
    included, so a changed scenario or diagram shows as a change."""
    found, current, fence = {}, None, ""
    for line in text.splitlines():
        if fence:
            if closes(line, fence):
                fence = ""
        else:
            marker = pr_body.FENCE.match(line)
            if marker:
                fence = marker.group(1)
            elif line.startswith("## "):
                current = line[3:].strip()
                found.setdefault(current, [])
                continue
        if current is not None:
            found[current].append(line)
    return found


def scenarios(lines):
    """{name: [body lines]} for each "Scenario:" inside a fence."""
    found, current, fence = {}, None, ""
    for line in lines:
        if fence:
            if closes(line, fence):
                fence, current = "", None
                continue
            match = SCENARIO.match(line)
            if match:
                current = match.group(1)
                found[current] = []
            elif current is not None:
                found[current].append(line)
        else:
            marker = pr_body.FENCE.match(line)
            if marker:
                fence = marker.group(1)
    return found


def ledger(lines):
    """{id: {status, type, what}} for each row of the ledger, in order."""
    rows = {}
    for line in lines:
        if not pr_body.ROW.match(line):
            continue
        found = cells(line)
        if len(found) >= 6:
            rows[found[0]] = {"status": found[5], "type": found[2], "what": found[1].replace("\\|", "|")}
    return rows


def drafted(text):
    """{id, title} for each D-entry heading inside a fence under
    "### Decisions to record"."""
    out, heading, fence = [], "", ""
    for line in text.splitlines():
        if fence:
            if closes(line, fence):
                fence = ""
            elif heading == "Decisions to record" and decisions.HEADING.match(line):
                match = decisions.HEADING.match(line)
                out.append({"id": "D" + match.group(1), "title": match.group(3)})
            continue
        marker = pr_body.FENCE.match(line)
        if marker:
            fence = marker.group(1)
        elif line.startswith("## "):
            heading = ""
        elif line.startswith("### "):
            heading = line[4:].strip()
    return out


def settled(text, found, pause):
    """{pause, parts} for each pause below this one that the spec has reached.
    found is pr_body.sections(text)."""
    out = []
    if pause > 1:
        names = list(scenarios(raw_sections(text).get("Acceptance criteria", [])))
        scope = [IN_LINE.match(line.strip()) for line in found.get("Scope", [])]
        out.append({"pause": 1, "parts": names + ["In: " + m.group(1) for m in scope if m]})
    if pause > 2 and "Interface" in found:
        parts = []
        for line in found["Interface"]:
            lead = LEAD_IN.match(line.strip())
            if line.startswith("### "):
                parts.append(line[4:].strip())
            elif lead:
                parts.append(lead.group(1).strip())
        out.append({"pause": 2, "parts": parts})
    return out


def squeeze_lines(lines):
    return [" ".join(line.split()) for line in lines if line.strip()]


def grouped(items, kind, ids):
    if ids:
        items.append({"kind": kind, "what": ", ".join(ids)})


def changed(now, last):
    """{kind, what} for each section, scenario and group of rows that differ.
    now and last are raw_sections."""
    items = []
    for name, lines in now.items():
        if name not in last:
            items.append({"kind": "added", "what": name})
        elif name == "Acceptance criteria":
            was, new = scenarios(last[name]), scenarios(lines)
            for title, body in new.items():
                if title not in was:
                    items.append({"kind": "added", "what": "Scenario: " + title})
                elif squeeze_lines(body) != squeeze_lines(was[title]):
                    items.append({"kind": "changed", "what": "Scenario: " + title})
            for title in was:
                if title not in new:
                    items.append({"kind": "removed", "what": "Scenario: " + title})
        elif name == "Open items":
            was, new = ledger(last[name]), ledger(lines)
            grouped(items, "new row", [i for i in new if i not in was])
            left = {}
            for i, row in new.items():
                if i in was and was[i]["status"] == "Open" and row["status"] != "Open":
                    left.setdefault(row["status"].lower(), []).append(i)
            for kind, ids in left.items():
                grouped(items, kind, ids)
        elif squeeze_lines(lines) != squeeze_lines(last[name]):
            items.append({"kind": "changed", "what": name})
    items += [{"kind": "removed", "what": name} for name in last if name not in now]
    return items


def gate(path, shape, root, rows, slices):
    """The card for the file at a stop, or None when that file gets no card."""
    text = read(path)
    found = pr_body.sections(text)
    pages = os.path.join(root, "docs", "specs", ".pages")
    now = ledger(found.get("Open items", []))
    real = os.path.realpath(path)
    if real == os.path.realpath(shape):
        stages = {s["name"]: s["stage"] for s in slices}
        first = next(((name, why) for name, _, why in rows if stages[name] != 7), None)
        name, pause, kind = None, None, "shape"
        copy = os.path.join(pages, os.path.basename(os.path.dirname(os.path.abspath(shape))) + "-shape-last.md")
        recommended = {"name": first[0], "why": first[1]} if first else None
        done, answered = [], sum(1 for row in now.values() if row["status"] != "Open")
    else:
        name = next((name for name, _, _ in rows
                     if real == os.path.realpath(os.path.join(root, "docs", "specs", name + ".md"))), None)
        # A Refined spec at a stop is pause 3 again: /build has not run yet.
        pause = stage(text, found) if name else 0
        pause = 3 if pause == 4 else pause
        if not 1 <= pause <= 3:
            return None
        kind, copy, recommended = "pause", os.path.join(pages, name + "-last.md"), None
        # The light path has one pause, so nothing before it was approved.
        light = bool(LIGHT.search(text))
        done, answered = [] if light else settled(text, found, pause), len(answers(found.get("Open items", [])))
    if not os.path.isfile(copy):
        first = pause in (None, 1) or (kind == "pause" and light)
        change = {"state": "first" if first else "missing", "since": None, "items": []}
    else:
        last = read(copy)
        at = datetime.datetime.fromtimestamp(os.path.getmtime(copy)).strftime("%Y-%m-%d %H:%M")
        where = "the last stop" if kind == "shape" else "pause %d" % stage(last, pr_body.sections(last))
        items = changed(raw_sections(text), raw_sections(last))
        change = {"state": "diff" if items else "none", "since": "%s, %s" % (where, at), "items": items}
    return {"kind": kind, "slice": name, "pause": pause,
            "open": [{"id": i, "type": row["type"], "what": row["what"]}
                     for i, row in now.items() if row["status"] == "Open"],
            "drafted": drafted(text) if pause == 3 else [], "recommended": recommended,
            "settled": done, "answered": answered, "changed": change}


def code_cells(line):
    """cells(), but a | inside a code span does not split the cell."""
    out, cell, i, tick = [], "", 0, 0
    text = line.strip()
    while i < len(text):
        if text[i] == "`":
            run = len(text[i:]) - len(text[i:].lstrip("`"))
            tick = 0 if tick == run else (tick or run)
            cell += text[i:i + run]
            i += run
            continue
        if text[i] == "|" and not tick and (i == 0 or text[i - 1] != "\\"):
            out.append(cell)
            cell = ""
        else:
            cell += text[i]
        i += 1
    out.append(cell)
    return [c.strip().replace("\\|", "|") for c in out[1:-1]]


def numbers(listed):
    """{1, 2, 5} from "1, 2 and 5", {1, 2, 3} from "1 to 3" or "1–3"."""
    out = set()
    for part in re.split(r"\s*(?:,|\band\b)\s*", listed):
        span = re.match(r"(\d+)(?:\s*(?:\bto\b|[–-])\s*(\d+))?$", part.strip())
        if span:
            out |= set(range(int(span.group(1)), int(span.group(2) or span.group(1)) + 1))
    return out


def table(lines, heading):
    """[{column: cell}] for the first table under "### <heading>"."""
    rows, header, inside = [], None, False
    for line in lines:
        if line.startswith("### "):
            if header is not None:
                break
            inside = line[4:].strip() == heading
            continue
        if not inside:
            continue
        if not line.lstrip().startswith("|"):
            if header is not None:
                break
            continue
        found = code_cells(line)
        if header is None:
            header = found
        elif not all(DIVIDER.match(cell) for cell in found):
            rows.append(dict(zip(header, found)))
    return rows


def proof(text, found, at):
    """Each scenario with the tests and files the spec names for it, and the
    Decided alone rows, for a slice at Built or later; else None."""
    if at < 5:
        return None
    plan = found.get("Technical plan", [])
    tests, changes = table(plan, "Test plan"), table(plan, "Changes")
    rows = []
    for n, name in enumerate(scenarios(raw_sections(text).get("Acceptance criteria", [])), 1):
        lead = [LISTED.match(row.get("Scenario", "")) for row in tests]
        rows.append({
            "n": n, "name": name,
            "tests": [{"test": row.get("Test", "").replace("`", ""), "command": row.get("Command", "").replace("`", "")}
                      for row, m in zip(tests, lead) if m and n in numbers(m.group(1))],
            "files": list(dict.fromkeys(
                re.sub(r":\d+(?:-\d+)?$", "", span.group(1)) for row in changes
                for span in [CODE.search(row.get("File", ""))]
                if span and any(n in numbers(m) for m in NAMED.findall(row.get("Why", ""))))),
        })
    alone = [{"id": row_id, "what": what.replace("\\|", "|"), "chose": parts.get("Chose:", ""), "undo": parts.get("Undo:", "")}
             for row_id, what, parts in pr_body.decided(found.get("Open items", []))]
    return {"rows": rows, "alone": alone}


def one_slice(n, name, ships, root, names, entries):
    rel = "docs/specs/%s.md" % name
    path = os.path.join(root, "docs", "specs", name + ".md")
    if not os.path.isfile(path):
        return {"n": n, "name": name, "stage": 0, "text": ships, "spec": None, "missing": rel,
                "needs": [], "diagrams": [], "decisions": [], "rows": [], "proof": None}
    text = read(path)
    found = pr_body.sections(text)
    return {"n": n, "name": name, "stage": stage(text, found), "text": opening(text) or ships,
            "spec": rel, "missing": None, "needs": needs(text, name, names),
            "diagrams": diagrams(text), "decisions": choices(entries, name),
            "rows": answers(found.get("Open items", [])), "proof": proof(text, found, stage(text, found))}


def board(shape, by, card=None):
    text = read(shape)
    found = pr_body.sections(text)
    rows = slice_rows(found.get("Slices", []))
    if not rows:
        raise Refused("no table with a Slice column under '## Slices' in %s" % shape)
    folder = os.path.dirname(os.path.abspath(shape))
    root = os.path.dirname(os.path.dirname(os.path.dirname(folder)))
    entries = decisions.parse(decisions.read(root))[0]
    names = [name for name, _, _ in rows]
    title = next((line[2:].strip() for line in text.splitlines() if line.startswith("# ")), "")
    status, kind = STATUS.search(text), TYPE.search(text)
    slices = [one_slice(n, name, ships, root, names, entries) for n, (name, ships, _) in enumerate(rows, 1)]
    return {
        "idea": os.path.basename(folder),
        "title": title or os.path.basename(folder),
        "status": status.group(1).strip() if status else "",
        "type": kind.group(1).strip() if kind else "",
        "problem": squeezed(found.get("Problem", [])),
        "updated": {"by": by, "date": datetime.date.today().isoformat()},
        "slices": slices,
        "gate": gate(card, shape, root, rows, slices) if card is not None else None,
    }


def one_idea(specs, idea):
    rel = "docs/specs/%s/shape.md" % idea
    try:
        text = read(os.path.join(specs, idea, "shape.md"))
        rows = slice_rows(pr_body.sections(text).get("Slices", []))
        if not rows:
            return {"idea": idea, "error": "no Slices table in %s" % rel}
        marks = []
        for name, _, _ in rows:
            path = os.path.join(specs, name + ".md")
            spec = read(path) if os.path.isfile(path) else None
            marks.append((name, stage(spec, pr_body.sections(spec)) if spec is not None else 0))
    except Refused as refusal:
        return {"idea": idea, "error": str(refusal).replace(os.path.join(specs, ""), "docs/specs/", 1)}
    title = next((line[2:].strip() for line in text.splitlines() if line.startswith("# ")), "")
    link = BOARD.search(text)
    return {"idea": idea, "title": title or idea, "shape": rel, "marks": marks, "error": None,
            "board": link.group(1) if link and link.group(1).startswith("https://") else None}


def library(root):
    """Error rows, then ideas with a slice not Shipped, then the rest; each
    group in folder-name order."""
    specs = os.path.join(root, "docs", "specs")
    found = sorted(name for name in os.listdir(specs)
                   if os.path.isfile(os.path.join(specs, name, "shape.md"))) if os.path.isdir(specs) else []
    ideas = [one_idea(specs, idea) for idea in found]
    return sorted(ideas, key=lambda i: 0 if i["error"] else 1 if any(st < 7 for _, st in i["marks"]) else 2)


IDEAS_STYLE = """<style>
.zuko-ideas{--zi-ink:#1A2130;--zi-slate:#5A6477;--zi-rule:#DDE1E8;--zi-surface:#FFFFFF;--zi-head:#EEF1F5;--zi-ship:#2E7A57;--zi-work:#2C5B88;--zi-warn:#A8701C;--zi-warn-soft:#F7EEDD;display:flex;flex-direction:column;gap:14px;color:var(--zi-ink)}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]) .zuko-ideas{--zi-ink:#E3E7EE;--zi-slate:#98A2B3;--zi-rule:#2A313D;--zi-surface:#181D26;--zi-head:#1E242E;--zi-ship:#6CC49A;--zi-work:#86AEDA;--zi-warn:#E0AE5E;--zi-warn-soft:#2C2416}}
:root[data-theme="dark"] .zuko-ideas{--zi-ink:#E3E7EE;--zi-slate:#98A2B3;--zi-rule:#2A313D;--zi-surface:#181D26;--zi-head:#1E242E;--zi-ship:#6CC49A;--zi-work:#86AEDA;--zi-warn:#E0AE5E;--zi-warn-soft:#2C2416}
.zuko-ideas p{margin:0;font-size:.9rem;color:var(--zi-slate)}
.zuko-ideas .zi-legend{display:flex;flex-wrap:wrap;gap:6px 16px;font-size:.82rem;color:var(--zi-slate)}
.zuko-ideas .zi-legend span{display:inline-flex;gap:6px;align-items:center}
.zuko-ideas .zi-tbl{overflow-x:auto;border:1px solid var(--zi-rule);border-radius:6px;background:var(--zi-surface)}
.zuko-ideas table{border-collapse:collapse;width:100%;font-size:.9rem}
.zuko-ideas th,.zuko-ideas td{text-align:left;vertical-align:top;padding:9px 12px;border-bottom:1px solid var(--zi-rule)}
.zuko-ideas th{font-size:.74rem;text-transform:uppercase;letter-spacing:.06em;color:var(--zi-slate);font-weight:500;background:var(--zi-head)}
.zuko-ideas tr:last-child td{border-bottom:0}
.zuko-ideas b{display:block;font-weight:600}
.zuko-ideas .zi-folder,.zuko-ideas code{font-family:ui-monospace,Menlo,monospace;font-size:.8em;color:var(--zi-slate);overflow-wrap:anywhere}
.zuko-ideas .zi-count{white-space:nowrap;font-variant-numeric:tabular-nums}
.zuko-ideas ul{display:flex;flex-wrap:wrap;gap:4px;margin:6px 0 0;padding:0;list-style:none}
.zuko-ideas .zi-legend ul{margin:0}
.zuko-ideas li{width:11px;height:11px;border-radius:50%;border:2px solid var(--zi-slate);box-sizing:border-box}
.zuko-ideas li.ship{background:var(--zi-ship);border-color:var(--zi-ship)}
.zuko-ideas li.work{background:var(--zi-work);border-color:var(--zi-work)}
.zuko-ideas .zi-none{color:var(--zi-slate)}
.zuko-ideas .zi-pill{display:inline-block;padding:1px 9px;border-radius:999px;font-size:.8rem;font-weight:600;background:var(--zi-warn-soft);color:var(--zi-warn)}
</style>"""


def mark_kind(st):
    return "ship" if st == 7 else "none" if st == 0 else "work"


def idea_row(i):
    e = html.escape
    head = '<tr class="idea" data-idea="%s"><td><b>%s</b><span class="zi-folder">%s</span></td>' % (
        e(i["idea"]), e(i.get("title") or i["idea"]), e(i["idea"]))
    if i["error"]:
        return head + '<td colspan="2"><span class="zi-pill">not read</span> %s</td></tr>' % \
            CODE_PATH.sub(lambda m: "<code>%s</code>" % m.group(0), e(i["error"]))
    marks = i["marks"]
    shipped = sum(1 for _, st in marks if st == 7)
    label = ", ".join("%s %s" % (name, STAGES[st]) for name, st in marks)
    dots = "".join('<li class="%s" title="%s · %s"></li>' % (mark_kind(st), e(name), STAGES[st]) for name, st in marks)
    board = '<a href="%s">open board</a>' % e(i["board"]) if i["board"] else \
        'no board yet · <code>%s</code>' % e(i["shape"])
    return head + '<td><span class="zi-count">%d of %d shipped</span><ul aria-label="%s">%s</ul></td><td%s>%s</td></tr>' % (
        shipped, len(marks), e(label), dots, "" if i["board"] else ' class="zi-none"', board)


def library_html(ideas):
    if not ideas:
        return ""
    return "\n".join([
        '<section class="zuko-ideas" aria-labelledby="zuko-ideas">',
        IDEAS_STYLE,
        '<h2 id="zuko-ideas">Ideas</h2>',
        '<p>One row for each <code>docs/specs/*/shape.md</code>. Specs with no shape are only in Slices, below.</p>',
        '<div class="zi-legend" aria-hidden="true"><span><ul><li class="ship"></li></ul>Shipped</span>'
        '<span><ul><li class="work"></li></ul>Pause 1 to Reviewed</span><span><ul><li class="none"></li></ul>Not started</span></div>',
        '<div class="zi-tbl"><table><thead><tr><th>Idea</th><th>Progress</th><th>Board</th></tr></thead><tbody>',
        "\n".join(idea_row(i) for i in ideas),
        '</tbody></table></div>',
        '</section>',
    ])


def blob(data):
    """The JSON, with nothing in it that can end or confuse a script block."""
    return json.dumps(data, ensure_ascii=False).replace("</", "<\\/").replace("<!--", "<\\u0021--")


def serve(folder, port=PORT):
    """The port is a parameter only so the test can run this server when
    another program holds 4751."""
    if not os.path.isdir(folder):
        print("board.py: %s is not a directory" % folder, file=sys.stderr)
        return 2
    root = os.path.realpath(folder)
    hosts = ("127.0.0.1:%d" % port, "localhost:%d" % port)

    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=root, **kwargs)

        def send_head(self):
            if self.headers.get("Host") not in hosts:
                self.send_error(400, "Host not allowed")
                return None
            path = os.path.realpath(self.translate_path(self.path))
            if path != root and not path.startswith(root + os.sep):
                self.send_error(404)
                return None
            return super().send_head()

    try:
        server = http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler)
    except OSError as error:
        print("board.py: cannot serve on 127.0.0.1:%d: %s" % (port, error.strerror or error), file=sys.stderr)
        return 1
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


def main(argv):
    if len(argv) == 2 and argv[0] == "serve":
        return serve(argv[1])
    if len(argv) == 2 and argv[0] == "library":
        if not os.path.isdir(argv[1]):
            print("board.py: %s is not a directory" % argv[1], file=sys.stderr)
            return 2
        page = library_html(library(argv[1]))
        if page:
            print(page)
        return 0
    if len(argv) not in (4, 6) or argv[0] not in ("render", "data") or argv[2] != "--by" \
            or (len(argv) == 6 and argv[4] != "--gate"):
        print(USAGE, file=sys.stderr)
        return 2
    try:
        data = board(argv[1], argv[3], argv[5] if len(argv) == 6 else None)
        page = read(TEMPLATE) if argv[0] == "render" else None
    except Refused as refusal:
        print("board.py: %s" % refusal, file=sys.stderr)
        return 2
    print(blob(data) if page is None else page.replace(SLOT, blob(data), 1))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
