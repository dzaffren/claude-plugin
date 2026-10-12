# A template's bold labels are what the gates grep for

**Learned:** 2026-10-13 · **From:** /ship unattended-build

The unattended-build spec named its proof line `**Proof in prod**`. The spec
template says `**Proof it works**`, and `verify-ship-gates.sh` greps for that
exact label. The ship gate failed on a spec that had the line, with the wrong
name.

## The rule

Copy each bold label from the spec template as it is. A gate finds a section
by its label, so a new name for the same line reads as a missing line.
