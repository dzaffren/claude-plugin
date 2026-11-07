# Decisions

Append-only. A changed decision is a new entry that supersedes the old one; only an
old entry's Status line ever changes.

## D3 · 2026-09-25 · No feat, fix or breaking commit means no proposed release

Why: a version number promises a change.
Rejected: proposing a patch anyway (a release with nothing in it).
Source: specs/release.md
Status: active

## D4 · 2026-09-27 · Security severity is a 3 × 3 exploitability × impact grid

Why: one scale for every finding — the reviewer and the pentester share it.
Rejected: CVSS (too many inputs for a code review).
Source: specs/owasp-lens.md
Status: active
