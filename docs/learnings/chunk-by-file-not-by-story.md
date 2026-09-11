# When parallel chunks would share a file, re-cut them by file

**Learned:** 2026-06-04 · **From:** /build, forge thinking-skills-quality (ported 2026-09-11)

Chunks build in isolated worktrees and merge independently, so disjoint file
ownership is the property that keeps the merges clean — not how neatly the work
splits by story. An epic whose two stories both edited the same three
`SKILL.md` files was re-cut by file and merged with zero conflicts.

Wrong: one chunk per story, following the plan's story split literally when the
stories overlap. Right: before dispatching, check whether the chunks share any
target file; if they do, re-partition so each owns a disjoint set, folding every
story's concern for a file into that file's chunk. See
[[worktree-agents-cannot-commit]].
