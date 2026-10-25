# A port borrowed from a reference project collides with it

**Learned:** 2026-10-26 · **From:** /build idea-board

The idea board copied OpenMontage's Backlot, and the spec took Backlot's
default port, 4750, for the local board server. The user runs Backlot on
the same machine, so 4750 was already held, and every failed publish would
have printed the file path instead of a URL. The chunk-builder found it
when its e2e test could not bind the port.

## The rule

When a design copies a tool the user runs, do not copy its port, socket,
lock file or folder name. Pick a free one, and check it with
`ss -ltn | grep :{port}` at pause 3. A check that something answers on the
port is not a check that it is your server: compare what it serves.
