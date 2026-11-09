# Back up an outside tool's config before a spike runs it

**Learned:** 2026-11-09 · **From:** /poc strix-code

The strix-code spike ran Strix 1.4.1 on the user's machine, with the user's
real `~/.strix/cli-config.json`. The run failed after 193 seconds, and on its
way it erased both keys in that file. Its `persist_current()`
(`strix/config/loader.py:56`) rewrites the file from the shell environment
only, and the keys were only in the file. Nobody could restore the key: zuko
never reads a secret's value. The user had to type it again, and the spike
waited for that.

## The rule

Before a spike runs an outside tool for real, copy each config file of that
tool to a private file in the scratchpad (`chmod 600`). Delete the copy when
the spike ends. Read the tool's startup path first when that is cheap: a
"save current settings" call at startup is the usual cause.
