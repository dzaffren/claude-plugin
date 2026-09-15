# Merging is not shipping, for a plugin

**Learned:** 2026-09-15 · **From:** /ship on `readable-review-findings`

A merge to `main` puts the change in the repo. The thing that runs is
`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`, a copy taken at
install time. After PR #25 merged, the cache still held 2.0.0 and 2.1.0, neither
containing `scripts/check-report.sh`, while the repo was at 2.2.0.

So "shipped" for this repo means three steps, not one:

1. Merge.
2. Reinstall the plugin, so the cache picks up the new version directory.
3. Start a new session, because skills load at session start.

A spec's "Proof it works" line cannot be checked between steps 1 and 3. Say that
plainly rather than declaring success on a signal nobody could have seen yet.
This is the install-time half of `installed-plugin-lags-the-repo.md`, which
covers the same trap for hooks.
