#!/usr/bin/env python3
"""Find jargon a doc uses without defining it.

Usage: glossary.py missing <path>...

  missing  one "<path>\t<term>" line for each term from TERMS that the doc
           uses in prose and has no "## Glossary" entry for. Code does not
           count: fenced blocks, inline code, and a term inside a path or
           file name (test-e2e-release.sh). A plural (ADRs) counts as a use.
           The Glossary section's own lines are definitions, not uses. An
           entry is a line under "## Glossary" starting "- **<term>**", in
           any case. Prints the term as TERMS spells it.

Exit 0 printed (nothing when every term is defined). Exit 2 bad usage or a
file that cannot be read.
"""
import re
import sys

USAGE = "usage: glossary.py missing <path>..."

# The closed list. Grow it by editing it; nothing infers what counts as jargon.
TERMS = ("semver", "e2e", "fail-open", "idempotent", "lockfile", "annotated tag",
         "blind verifier", "pentest", "OWASP", "SSRF", "XSS", "CVE", "CVSS", "ADR",
         "SARIF", "walking skeleton", "backfill")

FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
INLINE_CODE = re.compile(r"(`+).*?\1", re.S)
BLANK = re.compile(r"\n[ \t]*\n")
GLOSSARY = re.compile(r"^## Glossary\s*$")


def use(term):
    """The term as a whole word, plural allowed. Word characters, "/", "-" or
    a "." joined to a word around it make it part of a path or name."""
    words = r"\s+".join(re.escape(word) for word in term.split())
    return re.compile(r"(?<![\w./-])%ss?(?![\w/-]|\.\w)" % words, re.I)


def entry(term):
    return re.compile(r"^- \*\*%s\*\*" % re.escape(term), re.I)


def split(text):
    """(prose, glossary lines): prose has code removed; the glossary is the
    lines under "## Glossary" up to the next "## " heading. An inline code
    span may wrap lines, so it is stripped per paragraph, not per line; a
    skipped line (code fence, glossary) is a blank line between paragraphs."""
    prose, glossary = [], []
    fence = ""    # the open fence's marker; it closes on the same character, at least as long
    in_glossary = False
    for line in text.splitlines():
        marker = FENCE.match(line)
        if fence:
            if marker and marker.group(1)[0] == fence[0] and len(marker.group(1)) >= len(fence) \
                    and not line[marker.end():].strip():
                fence = ""
            prose.append("")
            continue
        if marker:
            fence = marker.group(1)
            prose.append("")
            continue
        if line.startswith("## "):
            in_glossary = bool(GLOSSARY.match(line))
        if in_glossary:
            glossary.append(line)
            prose.append("")
        else:
            prose.append(line)
    paragraphs = BLANK.split("\n".join(prose))
    return "\n\n".join(INLINE_CODE.sub(" ", p) for p in paragraphs), glossary


def missing(path):
    with open(path, encoding="utf-8") as handle:
        prose, glossary = split(handle.read())
    return [term for term in TERMS
            if use(term).search(prose)
            and not any(entry(term).match(line) for line in glossary)]


def main(argv):
    if len(argv) < 2 or argv[0] != "missing":
        print(USAGE, file=sys.stderr)
        return 2
    for path in argv[1:]:
        try:
            terms = missing(path)
        except (OSError, UnicodeDecodeError) as error:
            print("glossary.py: cannot read %s: %s" % (path, error), file=sys.stderr)
            return 2
        for term in terms:
            print("%s\t%s" % (path, term))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
