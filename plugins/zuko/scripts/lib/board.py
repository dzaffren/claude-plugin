#!/usr/bin/env python3
"""Build an idea's board from its shape, the specs it names and DECISIONS.md.

Usage: board.py render <shape.md> --by <text> [--gate <file>]
       board.py data   <shape.md> --by <text> [--gate <file>]
       board.py serve  <dir>

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

Exit 0 printed, or the server stopped. Exit 1 the port cannot be bound, most
often because it is in use. Exit 2 bad usage, a shape, spec or --gate file
that cannot be read, a shape with no Slices table, or a <dir> that is not a
directory.
"""
import datetime
import http.server
import json
import os
import re
import sys

import decisions
import pr_body

USAGE = ("Usage: board.py render <shape.md> --by <text> [--gate <file>]\n"
         "       board.py data   <shape.md> --by <text> [--gate <file>]\n"
         "       board.py serve  <dir>")

TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "board.html")
SLOT = "/*DATA*/null"
PORT = 4751

STATUS = re.compile(r"\*\*Status:\*\*\s*([^·\n]+)")
TYPE = re.compile(r"\*\*Project type:\*\*\s*([^·\n]+)")
DEPENDS = re.compile(r"^\*\*Depends on:\*\*(.*)$", re.M)
DIVIDER = re.compile(r"^:?-+:?$")
SHOWN = ("Resolved", "Accepted risk", "Decided alone")
SCENARIO = re.compile(r"^\s*Scenario:\s*(.+?)\s*$")
LEAD_IN = re.compile(r"^\*\*([^*]+)\*\*$")
IN_LINE = re.compile(r"^\*\*In:\*\*\s*(.*)$")
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
        pause = stage(text, found) if name else 0
        if not 1 <= pause <= 3:
            return None
        kind, copy, recommended = "pause", os.path.join(pages, name + "-last.md"), None
        done, answered = settled(text, found, pause), len(answers(found.get("Open items", [])))
    if not os.path.isfile(copy):
        change = {"state": "first" if pause in (None, 1) else "missing", "since": None, "items": []}
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


def one_slice(n, name, ships, root, names, entries):
    rel = "docs/specs/%s.md" % name
    path = os.path.join(root, "docs", "specs", name + ".md")
    if not os.path.isfile(path):
        return {"n": n, "name": name, "stage": 0, "text": ships, "spec": None, "missing": rel,
                "needs": [], "diagrams": [], "decisions": [], "rows": []}
    text = read(path)
    found = pr_body.sections(text)
    return {"n": n, "name": name, "stage": stage(text, found), "text": opening(text) or ships,
            "spec": rel, "missing": None, "needs": needs(text, name, names),
            "diagrams": diagrams(text), "decisions": choices(entries, name),
            "rows": answers(found.get("Open items", []))}


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
