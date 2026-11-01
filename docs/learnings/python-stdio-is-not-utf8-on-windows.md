# Python stdio is not UTF-8 on Windows

**Learned:** 2026-11-01 · **From:** /debug decisions.py cp1252 crash

zuko's Python libraries open every file with `encoding="utf-8"`, but they
leave stdin and stdout at the platform default. On macOS and Linux that is
UTF-8. On Windows it is the ANSI code page, cp1252. `decisions.py active`
crashed on `→` (no cp1252 byte), and `decisions.py titles` wrote `×` as the
cp1252 byte 0xD7, which bash read as UTF-8 and showed as `�`. All tests
passed on macOS, so nothing showed the bug until a Windows run.

The same happens to a line end: on Windows `print()` writes `\r\n`, and
`read -r` in bash keeps the `\r`. `check-skill-pin.sh` compared `v2.1.5\r`
with `v2.1.5` and announced an update to the version it already had.

## The rule

Text that crosses a pipe between Python and bash, or between Python and
Claude, has an encoding and a line end. Set both. Do not trust the platform
default. `PYTHONUTF8=1` makes stdio, `open()` and `subprocess` text all
UTF-8. A bash reader strips a trailing `\r` from each value it reads.

Test with a non-ASCII character in the fixture. An ASCII-only fixture passes
on every platform and proves nothing about the encoding.
