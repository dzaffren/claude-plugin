#!/usr/bin/env python3
"""Find a code block that swallows the text after it.

Usage: fence.py check <path>...

  check  one "<path>\t<problem>" line for the first problem in each doc, in
         the order given. Nothing for a doc that passes. A fence is up to 3
         spaces, then 3 or more backticks or tildes (pr_body.FENCE), and it
         closes as board.closes() says: the same character, at least as
         long, nothing after it. Two problems:

           - a fence with a language name opens inside an open block, with
             the same character and at least the open fence's length:
             "line <N> opens a <fence><lang> block inside the block that
             line <M> opened. ..."
           - the file ends with a block open: "the <fence><lang> block that
             line <M> opened never closes. ..."

         Only the first problem is printed: after one, each later fence
         pairs with the wrong partner. The rules are in
         docs/specs/unclosed-fence.md, "How fence.py reads a doc".

Exit 0 printed. Exit 2 bad usage or a doc that cannot be read.
"""
import sys

import board
import pr_body

USAGE = "usage: fence.py check <path>..."


def first_problem(text):
    """The first problem in text, or None."""
    fence, opened, start = "", "", 0
    for n, line in enumerate(text.splitlines(), 1):
        marker = pr_body.FENCE.match(line)
        if fence:
            if board.closes(line, fence):
                fence = ""
            elif marker and line[marker.end():].strip() and marker.group(1)[0] == fence[0] \
                    and len(marker.group(1)) >= len(fence):
                return ("line %d opens a %s block inside the block that line %d opened. Close the block "
                        "from line %d first, or open it with a longer fence." % (n, line.strip(), start, start))
        elif marker:
            fence, opened, start = marker.group(1), line.strip(), n
    if fence:
        return "the %s block that line %d opened never closes. Close it." % (opened, start)
    return None


def main(argv):
    if len(argv) < 2 or argv[0] != "check":
        print(USAGE, file=sys.stderr)
        return 2
    found = []
    for path in argv[1:]:
        try:
            with open(path, encoding="utf-8") as handle:
                text = handle.read()
        except (OSError, UnicodeDecodeError) as error:
            print("fence.py: cannot read %s: %s" % (path, getattr(error, "strerror", None) or error), file=sys.stderr)
            return 2
        problem = first_problem(text)
        if problem:
            found.append("%s\t%s" % (path, problem))
    if found:
        print("\n".join(found))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
