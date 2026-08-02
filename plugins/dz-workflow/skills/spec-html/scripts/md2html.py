#!/usr/bin/env python3
"""Render Markdown docs to sibling self-contained HTML files.

Usage: md2html.py doc.md [more.md ...]
Writes doc.html next to each input and prints its file:// URL.
"""
import re
import sys
from pathlib import Path

TEMPLATE = Path(__file__).resolve().parent.parent / "assets" / "template.html"


def title_of(md: str, fallback: str) -> str:
    m = re.search(r"^#\s+(.+)$", md, re.MULTILINE)
    return m.group(1).strip() if m else fallback


def render(md_path: Path) -> Path:
    md = md_path.read_text(encoding="utf-8")
    # A literal "</script" in the markdown would end the embedding script tag.
    safe = md.replace("</script", "<\\/script")
    html = TEMPLATE.read_text(encoding="utf-8")
    html = html.replace("{{TITLE}}", title_of(md, md_path.stem))
    html = html.replace("{{MARKDOWN}}", safe)
    out = md_path.with_suffix(".html")
    out.write_text(html, encoding="utf-8")
    return out


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        return 1
    for arg in sys.argv[1:]:
        p = Path(arg)
        if not p.is_file() or p.suffix != ".md":
            print(f"skipping {arg}: not a .md file", file=sys.stderr)
            continue
        out = render(p)
        print(f"file://{out.resolve()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
