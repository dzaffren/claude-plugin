# Attack strings in a test edit can stall auto mode's check

An Edit adding guard test lines such as `awk 'system("sh")'` got no verdict
from auto mode's safety classifier, a hard failure that must not be retried.
The lines are payloads fed to a hook as text, never run.

**Rule:** when an edit that holds attack strings for a guard's test gets no
verdict, stop and ask the user. Once they approve, write it through a Bash
heredoc into the scratchpad and splice it in with a short script that asserts
its anchor appears once.
