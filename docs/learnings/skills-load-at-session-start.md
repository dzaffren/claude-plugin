# A skill edited this session does not take effect this session

**Learned:** 2026-05-04 · **From:** /ship, forge PR #6 (ported 2026-09-11)

Claude Code loads `SKILL.md` and its references when the session starts.
Editing them mid-session does not hot-reload. Invoking the skill afterwards
runs the *old* text, however clean the `git diff` looks on disk.

Watched live on forge PR #6: `/ship` ran its pre-code-review flow even though
the new gate had merged into `SKILL.md`. Wrong: edit a skill, then invoke it to
test the change. Right: start a new session, or execute the new instructions by
hand by reading the file. This is also why a plugin rebuilt on disk this session
is not invocable until the next one.

Hooks are worse, because merging does not help either. `~/.claude/plugins/cache/
<marketplace>/<plugin>/<version>/` is a **copy**, not a symlink to the repo, so
a hook fixed and merged to `main` keeps running its old text until the plugin is
reinstalled — the version directory is what ships, and it did not change.
Checked on `hook-command-match`: after merge, the cached `block-dangerous.sh`
still differed from the repo's and the cache had no `scripts/lib/` at all.
So when a slice changes a hook, verify against the repo copy by invoking the
script directly, and say plainly that the running session is still on the old
one. Never report a hook fix as live because the PR merged.
