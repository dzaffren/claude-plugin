# A gate that scanned nothing must never exit 0

**Learned:** 2026-09-08 · **From:** zuko 2.0.0 review (PR #18)

Two of zuko's own gates shipped in a state where they checked nothing and
reported success. Both had been tested and reported as verified.

`check-design-drift.sh` defaulted to scanning `docs/design/`, which only
exists on the local-preview path. On the dev-server path, where components
are written into `src/`, it found no files and returned exit 0 with no
output. "I scanned zero files" was byte-identical to "I scanned everything
and it is clean".

`check-open-items.sh` had two modes and `/build` invoked the wrong one. With
no argument it ran in Stop-hook mode, which deliberately ignores `Refined`
specs — and the spec being built is always `Refined`. It looked at every
spec except the one it existed to guard.

## The rule

Any check that can end up with an empty scope must treat that as a failure,
not a pass. Concretely, every gate:

- exits non-zero when it scanned nothing, and says so loudly
- reports its scope on every outcome — file count, spec path, whatever it
  looked at — so an empty scope is visible in the passing case too
- errors on a target that does not exist, rather than falling back to a
  default that silently checks something else
- has no mode that can be selected by accident. If a script has modes, the
  caller states which one, and a missing argument is an error

## Wrong

```bash
scan=$(find "$target" -name '*.tsx')
[ -z "$scan" ] && exit 0          # nothing to check, so "pass"
...
echo "Check passed."
```

## Right

```bash
scan=$(find "$target" -name '*.tsx')
count=$(printf '%s\n' "$scan" | grep -c .)
if [ "$count" -eq 0 ]; then
  echo "Scanned NOTHING -- this is a failure, not a pass." >&2
  echo "  Path does not exist: $target" >&2
  exit 1
fi
...
echo "Check passed over $count file(s)."
```

## Why the tests missed it

The fixtures covered "does it catch a bad file" and "does it pass a good
file". Neither asked "what if it is pointed at nothing". The ledger fixtures
covered `Built` and `Shipped` specs but never `Refined` — the actual case.

So when writing tests for a check, cover three cases, not two:

| Case | Question |
| ---- | -------- |
| bad input | does it fire? |
| good input | does it stay quiet? |
| **empty or absent input** | **does it admit it looked at nothing?** |

A suite that only asks "does it detect the bad thing" never catches "was it
even looking".
