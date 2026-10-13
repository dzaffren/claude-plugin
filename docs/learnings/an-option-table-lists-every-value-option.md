# An option table must list every option that takes a value

**Learned:** 2026-10-13 · **From:** /review of pr-edit-attribution

`block-attribution.sh` finds message text by walking a command's options with
a table: `-b`, `-F` and `-t` for gh. The table knew only the options that carry
a message. An option it did not know, which takes a value, was read as flags:
`-Bnext` ends in `t`, so the walk took `-t` with an empty tail, used the next
word, `--body`, as the title, and never read the signed body. This is the third
gap of this kind in the same walk, after abbreviated git options (`1c23429`)
and `-R` before the subcommand (`170baf4`).

## The rule

A walk that reads some options must know every option that takes a value,
including the ones it ignores, or one of them eats the option it wants. Build
the table from the tool's own `--help`, name the version, and test each option
with a value that ends in one of the letters the walk reads.

## Again for create (2026-10-13, gh-create-value-options)

The same gap came back once per subcommand: `gh pr edit` and `gh pr merge` in
`86a0c9f`, then `gh pr create` and `gh release create`. `-Bnext` and
`--target -t` hid a signed text. When one table gets every value option, give
every sibling table the same pass in the same change.
