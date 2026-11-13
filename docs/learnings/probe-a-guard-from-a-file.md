# Probe a guard with its inputs in a file, not in the Bash command

A Bash call that fed `rm -rf /` forms to `block-dangerous.sh` in a heredoc was
blocked by the installed copy of the same guard. That guard reads the raw
command text, so the probe inputs looked like a real delete.

**Rule:** write a guard's probe inputs to a scratchpad file with Write, and
let a scratchpad script read them, so the Bash command holds no attack text.
