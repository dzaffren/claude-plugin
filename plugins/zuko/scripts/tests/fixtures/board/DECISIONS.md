# Decisions

Append-only. A changed decision is a new entry that supersedes the old one; only an
old entry's Status line ever changes.

## D1 · 2026-10-20 · Shipped reads one file

Why: one file is enough.
Rejected: two files (twice the reads, and one, two or three can drift), a
database (no server).
Source: specs/shipped.md
Status: active

## D2 · 2026-10-21 · Reviewed keeps its own entry

Why: it belongs to another slice.
Rejected: sharing D1 (wrong source).
Source: specs/reviewed.md
Status: active

## D3 · 2026-10-22 · Shipped also writes one file

Why: the newest entry comes first.
Rejected: no write at all.
Source: specs/shipped.md
Status: active
