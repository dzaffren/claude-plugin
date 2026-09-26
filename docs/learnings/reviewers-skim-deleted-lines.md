# A reviewer skims deleted lines unless told to read them

**Learned:** 2026-09-26 · **From:** owasp-lens build

In the sixth seeded `/review` run, the reviewer covering `auth.py` listed A09 as
checked and wrote "login() and the session handling are unchanged". The diff had
deleted `log.warning("login failed for %s", username)` from `login()`. Nothing
was added in that function, so a reading that follows the `+` lines saw no
change. Runs 2 to 5 caught the same deletion; run 6 did not.

Adding one line to `owasp.md`'s A09 check and to the reviewer's context step,
"read the removed (`-`) lines of every changed function in auth, session,
access-control and security code", and that a deleted log call counts "even when
nothing was added", brought A09 back in runs 7 and 8.

## The rule

When a check depends on something the diff removes (a guard, a log call, a
validation), say in the check to read the removed lines, and give the deleted
line as the example. A seeded fixture for such a check deletes a line and adds
nothing near it.
