#!/usr/bin/env python3
"""Render Markdown docs to sibling self-contained HTML files.

Usage:
  md2html.py doc.md [more.md ...]     render each doc to a sibling .html
  md2html.py --index <dir>            build <dir>/index.html listing all docs

Prints a file:// URL per file written.
"""
import re
import sys
from pathlib import Path

TEMPLATE = Path(__file__).resolve().parent.parent / "assets" / "template.html"


def title_of(md: str, fallback: str) -> str:
    m = re.search(r"^#\s+(.+)$", md, re.MULTILINE)
    return m.group(1).strip() if m else fallback


def render_text(md: str, title: str, out: Path) -> Path:
    # A literal "</script" in the markdown would end the embedding script tag.
    safe = md.replace("</script", "<\\/script")
    html = TEMPLATE.read_text(encoding="utf-8")
    html = html.replace("{{TITLE}}", title)
    html = html.replace("{{MARKDOWN}}", safe)
    out.write_text(html, encoding="utf-8")
    return out


def render(md_path: Path) -> Path:
    md = md_path.read_text(encoding="utf-8")
    return render_text(md, title_of(md, md_path.stem), md_path.with_suffix(".html"))


def field(md: str, name: str) -> str:
    m = re.search(rf"\*\*{name}:\*\*\s*([^\n·|]+)", md)
    return m.group(1).strip() if m else "—"


def build_index(root: Path) -> Path:
    rows = []
    for p in sorted(root.rglob("*.md")):
        md = p.read_text(encoding="utf-8")
        rel = p.relative_to(root).with_suffix(".html")
        rows.append(
            f"| [{title_of(md, p.stem)}]({rel}) "
            f"| {field(md, 'Version')} | {field(md, 'Status')} |"
        )
    lines = [
        f"# {root.name} index",
        "",
        f"{len(rows)} document(s). Regenerate with `md2html.py --index {root}`.",
        "",
        "| Document | Version | Status |",
        "| -------- | ------- | ------ |",
        *rows,
    ]
    return render_text("\n".join(lines), f"{root.name} index", root / "index.html")


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        return 1
    if sys.argv[1] == "--index":
        root = Path(sys.argv[2])
        if not root.is_dir():
            print(f"{root}: not a directory", file=sys.stderr)
            return 1
        out = build_index(root)
        print(f"file://{out.resolve()}")
        return 0
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
