# The glossary

Words a report may use, and the line it defines each one with. A report prints
only the words it actually used.

**When a report needs a word that is not here**, write the line into this file in
the same run, then use it. The list grows. A report never ships with a technical
word it did not explain.

Keep every line under about twelve words, in the terms of someone using the
software, not someone writing it.

## Work and process

| Word | Line |
| ---- | ---- |
| diff | the lines this branch changed, compared with main |
| branch | a separate copy of the code where work happens before it is merged |
| staged | changes marked as ready for the next commit |
| commit | one saved change, with a message saying what it was |
| e2e | one test that walks the whole feature the way a person would |
| test suite | every test in the project, run together |
| regression test | a test that proves a bug that was fixed stays fixed |
| feature flag | a switch that turns new behaviour on or off without new code |
| rollback | putting the previous version back |
| worktree | a second checkout of the same repo, so two jobs cannot collide |
| chunk | one part of a build, owning its own files |
| ledger | the open-questions table in a spec; nothing unresolved gets past it |
| slice | one thin piece of a product, complete enough to ship on its own |

## Review

| Word | Line |
| ---- | ---- |
| finding | one problem a review says it found |
| raw finding | a finding before anything checked whether it is real |
| held up | a second agent traced the problem and agreed it is real |
| thrown out | a second agent looked and could not make the problem happen |
| verifier | the agent that judges a finding, seeing the claim but not the reasoning |
| reviewer | the agent that reads the diff and raises findings |
| linter | a tool that flags code style and obvious mistakes automatically |
| static analysis | reading code for problems without running it |
| vacuous test | a test that passes without ever exercising the thing it names |

## Security

| Word | Line |
| ---- | ---- |
| injection | input that the code runs as if it were its own instructions |
| authentication | proving who you are |
| authorization | what you are allowed to reach once you are in |
| timing attack | guessing a secret by measuring how long a wrong guess takes to fail |
| token | a secret string that stands in for permission to do something |
| secret | a password, key, or token that must never be stored in the code |
| PII | information that identifies a person, like an email or a phone number |
| CVE | a publicly listed security hole in software someone else wrote |

## How things break

| Word | Line |
| ---- | ---- |
| race condition | two things happening at once and landing in the wrong order |
| off-by-one | counting one too many or one too few |
| boundary | the first or last value a thing accepts, where bugs collect |
| null | a value that is not there |
| empty | a list or text with nothing in it |
| swallowed error | a failure the code catches and never mentions again |
| catch block | the part of the code that runs when something fails |
| silent failure | something that did not work and said nothing |

## Words the checker does not chase

`empty` · `null` · `boundary` · `secret` · `branch` · `held up` · `thrown out`

Each of these is ordinary English at least as often as it is jargon, and a check
that chased them would flag honest sentences. Define them when you mean them
technically — nothing will remind you.

## Also

| Word | Line |
| ---- | ---- |
| endpoint | one address in the app that other software calls |
| query string | the part of a web address after the "?", where values are passed |
| session | the record of who is signed in |
| job | a piece of work the server runs in the background |
| worker | a background program that runs long jobs outside the app |
