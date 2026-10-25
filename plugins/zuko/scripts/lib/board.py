#!/usr/bin/env python3
"""Build an idea's board from its shape, the specs it names and DECISIONS.md.

Usage: board.py render <shape.md> --by <text>
       board.py data   <shape.md> --by <text>
       board.py serve  <dir>

The shape is docs/specs/{idea}/shape.md, so the project root is three folders
above the shape's folder. Each row of the first table under "## Slices" that
has a Slice column is a slice, and the cell names its spec,
docs/specs/{name}.md. Sections and ledger rows are read with pr_body.py's
parser and entries with decisions.py's, so the board reads them as the gates
do. The rule for each part is in docs/specs/idea-board.md, "How the script
reads each part".

  render  board.html with its JSON slot filled: the page to publish
  data    only the JSON, for the tests
  serve   serves <dir> on 127.0.0.1:4751 until stopped. Any Host header but
          127.0.0.1:4751 or localhost:4751 gets 400, so a page on another
          site cannot read the board through DNS rebinding

Exit 0 printed, or the server stopped. Exit 1 the port cannot be bound, most
often because it is in use. Exit 2 bad usage, a shape or spec that cannot be
read, a shape with no Slices table, or a <dir> that is not a directory.
"""
import datetime
import http.server
import json
import os
import re
import sys

import decisions
import pr_body

USAGE = ("Usage: board.py render <shape.md> --by <text>\n"
         "       board.py data   <shape.md> --by <text>\n"
         "       board.py serve  <dir>")

TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "board.html")
SLOT = "/*DATA*/null"
PORT = 4751

STATUS = re.compile(r"\*\*Status:\*\*\s*([^·\n]+)")
TYPE = re.compile(r"\*\*Project type:\*\*\s*([^·\n]+)")
DEPENDS = re.compile(r"^\*\*Depends on:\*\*(.*)$", re.M)
DIVIDER = re.compile(r"^:?-+:?$")
SHOWN = ("Resolved", "Accepted risk", "Decided alone")
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
    """(name, what ships) for each row of the first table with a Slice column."""
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
            rows.append((name, at.get("What ships", "")))
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


def board(shape, by):
    text = read(shape)
    found = pr_body.sections(text)
    rows = slice_rows(found.get("Slices", []))
    if not rows:
        raise Refused("no table with a Slice column under '## Slices' in %s" % shape)
    folder = os.path.dirname(os.path.abspath(shape))
    root = os.path.dirname(os.path.dirname(os.path.dirname(folder)))
    entries = decisions.parse(decisions.read(root))[0]
    names = [name for name, _ in rows]
    title = next((line[2:].strip() for line in text.splitlines() if line.startswith("# ")), "")
    status, kind = STATUS.search(text), TYPE.search(text)
    return {
        "idea": os.path.basename(folder),
        "title": title or os.path.basename(folder),
        "status": status.group(1).strip() if status else "",
        "type": kind.group(1).strip() if kind else "",
        "problem": squeezed(found.get("Problem", [])),
        "updated": {"by": by, "date": datetime.date.today().isoformat()},
        "slices": [one_slice(n, name, ships, root, names, entries)
                   for n, (name, ships) in enumerate(rows, 1)],
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
    if len(argv) != 4 or argv[0] not in ("render", "data") or argv[2] != "--by":
        print(USAGE, file=sys.stderr)
        return 2
    try:
        data = board(argv[1], argv[3])
        page = read(TEMPLATE) if argv[0] == "render" else None
    except Refused as refusal:
        print("board.py: %s" % refusal, file=sys.stderr)
        return 2
    print(blob(data) if page is None else page.replace(SLOT, blob(data), 1))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
