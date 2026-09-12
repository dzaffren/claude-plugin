# Write a guard's pattern from the artifact, not from the prose about it

**Learned:** 2026-09-12 · **From:** ship-naming review

`references/git-naming.md` banned `Generated with Claude Code`, and
`block-attribution.sh` grepped for exactly that. The string Claude Code
actually writes is:

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

Brackets in the middle, a domain the pattern never mentioned. The guard
exited 0 on the single most likely real input, and the fixtures did not catch
it because they were written from the same prose — the ban list said
`Generated with Claude Code`, so the test typed `Generated with Claude Code`.

A spec's ban list is a description of a thing. The thing itself has
punctuation, a URL, an emoji, capitalisation, and a second variant for a
different context. Only the artifact has those.

## The rule

Before writing the pattern, go and get the literal text the guard is meant to
catch — from the tool that emits it, from a commit that already carries it,
from the instruction that asks for it. Paste it into the fixture verbatim.
Then write the pattern against the paste.

If the emitting side has more than one form, the fixture needs one case per
form. Here that was three: bare prose, markdown link to `claude.ai/code`, and
markdown link to `claude.com/claude-code`.

## The tell

A fixture and the pattern it exercises that read like the same sentence. If
the test input was typed from the spec rather than copied from reality, the
test can only prove the pattern matches itself.

Same shape as [tightening a matcher trades blocks for allows](tightening-a-matcher-trades-blocks-for-allows.md):
both are about a guard that is precise against the wrong reference text.
