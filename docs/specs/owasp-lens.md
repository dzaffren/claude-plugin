# OWASP lens

**Version:** v1 · **Status:** Refined · **Type:** Enhancement · **Project type:** CLI/Library

**Shape doc:** docs/specs/v3-release-and-hosts/shape.md — slice 7a
**Depends on:** None
**Page:** https://claude.ai/artifact/WGiEEvRnTmpzLGLUxtBTh2

`/review`'s security lens checks the diff against OWASP Top 10:2025, from one shared
`references/owasp.md` that says what to check and what is not a finding in each
category. Now, because the lens is seven bullets with no standard behind it, and
slice 5's pentest needs the same reference.

## Problem

The security lens in `/review` is a list of seven bullets
(`plugins/zuko/skills/review/SKILL.md:45`, copied in `agents/reviewer.md:26`). It
names no standard, so nobody can say which risks a review covered and which it
skipped. It has no list of what is not a finding, so the reviewer reports trusted
env vars and framework-escaped output, and the blind verifier spends a run
rejecting each one. Findings carry no category or severity, so the report cannot be
ordered by what matters, and slice 5 has nothing to block a release on. The skill
also points at Trail of Bits plugins (`SKILL.md:75`) that are not installed.

## Slice test

| Check                         | Result                                                                                                                                                     |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cuts every layer it needs     | yes — the reference, the reviewer's lens and report format, the verifier's severity rule, and the skill's report                                           |
| One e2e test walks it         | yes — one `/review` run on a seeded vulnerable diff in a scratch copy of invoice-api walks all five scenarios; a contract test in `run.sh` guards the text |
| Worth shipping alone          | yes — every review names the categories it checked, and reports fewer false positives                                                                      |
| Fits (≤5 scenarios, ≤2 areas) | yes — 5 scenarios; two areas: the review stage (`skills/review`, `agents/reviewer.md`, `agents/finding-verifier.md`) and `references/`                     |

**Path:** full — a new reference and a changed finding format that slice 5 builds on.

## User story

As someone who runs `/review` before shipping, I want the security pass to follow a
named standard and tell me what it checked, so a clean review means something and a
finding tells me how bad it is.

## Flow

```mermaid
flowchart LR
    D["branch diff"] --> C["context step: find the repo's own<br/>auth, validation, query and escaping helpers"]
    C -- "categories the diff can touch" --> K["per category in owasp.md:<br/>what to check, then not-a-finding list"]
    K -- "CLAIM, CATEGORY, SEVERITY,<br/>SNIPPET, SYMBOL" --> V["blind finding-verifier:<br/>confirm or reject; may lower severity"]
    V -- confirmed --> R["report: by severity,<br/>categories checked and skipped,<br/>raw vs survived"]
    V -- rejected --> X["dropped, counted"]
```

The reviewer first finds the repo's own defences and picks the categories this diff
can touch. It checks each one against `owasp.md` and reports findings with a
category and severity. The blind verifier keeps or drops each finding and may lower
its severity. The report lists what survived by severity and names the categories
it did not check.

## Acceptance criteria

```gherkin
Scenario: an injection is reported with its category and severity
  Given invoice-api's branch feat/ledger-export adds invoice_api/exporters/ledger.py with
    cursor.execute("SELECT * FROM invoices WHERE customer = '" + customer + "' ORDER BY " + order)
  And customer and order come from the query parameters of GET /export/ledger, which
    needs a logged-in user
  When the user runs /review
  Then the report has one finding with CATEGORY "A05:2025 Injection",
    SEVERITY high, SYMBOL "export_ledger", and a SNIPPET of that execute line
  And it gives invoice_api/exporters/ledger.py:11 and the fix: pass customer as a parameter,
    and check order against the list of column names

Scenario: context first, and only the categories the diff can touch
  Given invoice-api has invoice_api/db.py with run(sql, params), used by every
    other query
  When the diff above is reviewed
  Then the finding's claim says the new query bypasses db.run
  And the report lists the categories checked — A01, A05, A10 for this diff —
    and names the other seven as not checked, each with a one-line reason
  And a diff that only changes README.md checks no category and says so

Scenario: exclusions keep noise out of the report
  Given the diff reads INVOICE_DB_URL from the environment, renders a customer name
    through a Jinja template with autoescape on, and adds tests/test_export.py
    holding the fake token "sk_test_invoice_123"
  And the /export route has no rate limit
  When the user runs /review
  Then none of those four is a finding

Scenario: where an exclusion and OWASP disagree, OWASP wins, narrowed to the diff
  Given the diff changes uv.lock to add requests-toolbelt 0.10.1, which no code
    imports yet
  And removes log.warning("login failed for %s", username) from auth.py
  And is_admin() now returns True when the roles lookup raises
  And the new GET /export/all route lets only users is_admin() approves export
    every customer's invoices
  When the user runs /review
  Then it reports three findings: A03:2025 Software Supply Chain Failures for the
    new dependency, A09:2025 Security Logging and Alerting Failures for the removed
    log, and A10:2025 Mishandling of Exceptional Conditions for the fail-open check
  And a dependency already in uv.lock before the branch is not reported

Scenario: severity is lowered, never raised, and orders the report
  Given the reviewer reports the injection as high
  And the verifier finds that customer is checked against ^[A-Z0-9-]{1,12}$ before
    the query runs, so only order is injectable, and confirms that narrower case
  When the verifier returns medium
  Then the report shows it as medium
  And a verifier that returns critical for a finding reported as medium leaves it
    medium
  And the report lists security findings critical, then high, medium, low, and
    its header reads "Findings   7 raw, 3 survived"
  And every confirmed finding is fixed as today, whatever its severity
```

## Scope

**In:**

- `references/owasp.md`: the ten 2025 categories, A01 Broken Access Control to A10
  Mishandling of Exceptional Conditions. For each, what to check in a diff and what
  is **not a finding**.
- The not-a-finding lists start from Anthropic's `security-review` exclusions: env
  vars and CLI flags are trusted; SSRF only when the attacker controls host or
  protocol; framework XSS only through a raw-HTML escape hatch; no memory-safety
  findings in memory-safe languages; tests and plain docs are skipped; DoS and
  rate limiting are excluded.
- Where an exclusion contradicts OWASP, OWASP wins, narrowed to the diff: A03
  reports dependencies added or changed in the lockfile; A09 reports logging
  removed or never written on an auth or security event; A10 fail-open cases stay
  in; A02 reports a permission widened in Markdown that is configuration (agent
  or skill frontmatter granting tools or permissions, or a plugin manifest).
- The context step: before judging, find the repo's own auth, validation,
  parameterised queries and escaping, and flag new code that bypasses them. The
  same step picks which categories the diff can touch. Only those are checked, and
  the report names the rest with a reason.
- The finding format gains `CATEGORY`, `SEVERITY`, `SNIPPET` and `SYMBOL`.
  Severity is exploitability × impact, on four tiers: critical, high, medium, low.
  Between two tiers, pick the lower. The verifier may lower it, never raise it.
- The report sorts by severity. Severity changes the order and the label only:
  every confirmed finding is still fixed, as `review/SKILL.md:137` says today.
- The reviewer, the skill and the verifier read `owasp.md`. The security bullets in
  `review/SKILL.md:45` and `agents/reviewer.md:26` are replaced by a pointer to it.
- Remove the Trail of Bits line, `review/SKILL.md:75`.
- A contract test in `run.sh` for the reference and the new format.

**Out:**

- Deleted guards and removed security code judged by history (`git log -S`,
  `git blame`); the verifier needing a located defence; silent failures as A10
  checks beyond fail-open; coverage findings — slice 7b.
- The pentest, and a release blocked on critical or high — slice 5, which reuses
  `owasp.md`.
- Severity changing what gets fixed — rejected at pause 1 (O1).
- An eval suite that re-runs the seeded diff on every change — rejected at pause 1
  (O2).
- SARIF output and numeric 0–100 scores — shape's Not doing list.

## Interface

Everything here is text: a reference file, two agent formats, and the report. No
design system applies.

### `references/owasp.md`

Four fixed sections, then one section per category, A01 to A10, in order.

```text
# OWASP Top 10:2025 for a diff

## Context first            the step that runs before any category
## Severity                 the grid below, and the pick-the-lower rule
## Never a finding          exclusions that hold in every category
## Where OWASP wins         A03, A09 and A10, narrowed to the diff

## A05:2025 Injection

**The diff can touch it when:** it builds a query, shell command, file path,
template or prompt from input.

**Check:**

- A query built by string formatting instead of the repo's parameterised helper.
- ...

**Not a finding:**

- A value from an env var or a CLI flag. Both are trusted.
- ...
```

The context step reads each "can touch it when" line to pick the categories. Slice
5 reads the same file, so the category headings are a contract: `## A01:2025
Broken Access Control` through `## A10:2025 Mishandling of Exceptional Conditions`,
exactly as top10.owasp.org/2025 names them.

### Severity

Exploitability × impact. Between two tiers, pick the lower.

| Exploitability ↓ · Impact →                                     | **Severe** — code runs, auth bypassed, every user's data | **Serious** — one other user's data, a secret, a privilege step | **Limited** — no secret, a missing log, own data only |
| --------------------------------------------------------------- | -------------------------------------------------------- | --------------------------------------------------------------- | ----------------------------------------------------- |
| **Direct** — anyone, one request, no login                      | critical                                                 | high                                                            | medium                                                |
| **Conditional** — a logged-in user, a setting, or a second step | high                                                     | medium                                                          | low                                                   |
| **Privileged** — an admin, or local access                      | medium                                                   | low                                                             | low                                                   |

A new or changed dependency (A03) with no known advisory is low. With one, it takes
the advisory's severity.

Only security findings carry a severity. Correctness, quality and decisions
findings stay as today.

### Reviewer output

A scope block first, once per review, then one block per finding:

```
SCOPE
DEFENCES: invoice_api/db.py run(sql, params) — parameterised queries
          invoice_api/auth.py login_required — session check on every route
CHECKED: A01, A05, A10
NOT CHECKED: A02 no config or deployment file changed
             A03 no lockfile changed
             A04 no hashing, signing or encryption touched
             A06 no new flow or trust boundary
             A07 no login, session or password code changed
             A08 no deserialisation, update or CI path changed
             A09 no auth or security event added or removed

CLAIM: The new query builds SQL by concatenating customer and order instead of calling db.run.
CATEGORY: A05:2025 Injection
SEVERITY: high
FILE: invoice_api/exporters/ledger.py:11
SYMBOL: export_ledger
SNIPPET: cursor.execute("SELECT * FROM invoices WHERE customer = '" + customer + "' ORDER BY " + order)
FAILING CASE: a logged-in user sends GET /export/ledger?customer=ACME-01&order=CASE
  WHEN (SELECT ...) THEN total ELSE issued_at END and reads another table one bit
  per request.
```

A correctness, quality or decisions finding has `CATEGORY: correctness` (or
`quality`, `decisions`), no `SEVERITY`, and `SNIPPET` and `SYMBOL` as above. With
several reviewers on a large diff, `CHECKED` is the union of theirs.

### Verifier input and output

The verifier sees the claim, `CATEGORY`, `SEVERITY`, `FILE`, `SYMBOL`, `SNIPPET`,
`BASE` (the branch point the skill measured, a ref or a sha; the verifier runs
`git diff <BASE>...HEAD -- <file>` and `git show <BASE>:<file>` with it), the
code, and that category's section of `owasp.md`. It still never sees the
failing case or the reviewer's scope block.

```
VERDICT: CONFIRMED
SEVERITY: medium
PATH: customer is checked against ^[A-Z0-9-]{1,12}$ at invoice_api/routes/export.py:27, but
  order reaches ORDER BY unchecked; a CASE expression there leaks another table's
  values one bit per request.
```

`SEVERITY` appears only on a confirmed security finding. A tier above the one
reported is ignored and the reported one kept.

### Report

```
Security   checked A01 Broken Access Control, A05 Injection,
           A10 Mishandling of Exceptional Conditions
           not checked: 7 categories, listed at the end
Findings   7 raw, 3 survived

medium · A05:2025 Injection · invoice_api/exporters/ledger.py:11 in export_ledger
  The new query builds SQL from order instead of calling db.run.
  Failing case: GET /export/ledger?customer=ACME-01&order=CASE WHEN (SELECT ...)
    THEN total ELSE issued_at END sorts by a secret, one bit per request.
  Fix: db.run with customer as a parameter, and order checked against
    ("issued_at", "total", "customer").

low · A09:2025 Security Logging and Alerting Failures · invoice_api/auth.py:25 in login
  ...

correctness · invoice_api/exporters/ledger.py:9 in export_ledger
  ...

Not checked
  A02 no config or deployment file changed
  ...
```

Security findings come first, critical to low. Then correctness, decisions and
quality, in that order. A diff that touches no category prints
`Security   no category checked — the diff changes README.md only`. Nothing
survived prints `Findings   7 raw, 0 survived — clean`.

**Preview:** this section. There is no UI to render.

## Technical plan

### Approach

All four parts are prompt text read by Claude, so nothing new runs as code. The
changes are one new reference, `references/owasp.md`, and edits to the review skill
and its two agents so they read it. The reviewer and the verifier cite
`${CLAUDE_PLUGIN_ROOT}/references/owasp.md` in their bodies. Claude Code
substitutes that path when it loads agent content (code.claude.com/docs/en/plugins-reference,
"Environment variables": "In skill, command, and agent content, write the `${...}`
reference in the Markdown body instead"). A contract test guards the text, and one
seeded `/review` run proves the behaviour.

Relies on: D4, D5, D6, D7, D8

```mermaid
flowchart TB
    subgraph skill["skills/review/SKILL.md"]
        SZ["size the effort"] --> DISP["dispatch reviewers"]
        COL["collect findings,<br/>union the SCOPE blocks"] --> VD["dispatch one or three<br/>verifiers per finding"]
        VD --> REP["report: security by severity,<br/>then correctness, decisions, quality"]
    end
    RV["agents/reviewer.md"] -- "reads whole file" --> OW[("references/owasp.md")]
    FV["agents/finding-verifier.md"] -- "reads its CATEGORY section" --> OW
    DISP -- "diff + discipline text" --> RV
    RV -- "SCOPE + findings" --> COL
    VD -- "claim, CATEGORY, SEVERITY,<br/>FILE, SYMBOL, SNIPPET" --> FV
    FV -- "VERDICT, SEVERITY, PATH" --> REP
```

The skill hands the diff to the reviewer. The reviewer reads all of `owasp.md`,
runs the context step, and returns a scope block and findings. Each finding goes to
a verifier that reads only its category's section. The skill writes the report from
what the verifiers confirmed.

```mermaid
sequenceDiagram
    participant S as review skill
    participant R as reviewer
    participant O as owasp.md
    participant V as finding-verifier
    S->>R: diff, discipline text
    R->>O: read Context first, Severity, exclusions, A01–A10
    R->>R: find db.run, login_required; pick A01, A05, A10
    R-->>S: SCOPE + A05 finding, SEVERITY high
    S->>V: claim, CATEGORY A05, SEVERITY high, FILE, SYMBOL, SNIPPET
    V->>O: read "## A05:2025 Injection"
    V->>V: trace invoice_api/routes/export.py:27 regex, order unchecked
    V-->>S: CONFIRMED, SEVERITY medium, PATH
    S->>S: keep min(high, medium) = medium
    S-->>S: report "medium · A05:2025 Injection · invoice_api/exporters/ledger.py:11"
```

For a large diff, three verifiers judge each finding and two must confirm it. The
kept severity is the lowest tier any confirming verifier returned, and never above
the reported one.

### Changes

| File                                                           | What changes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Why               |
| -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| `plugins/zuko/references/owasp.md` (new)                       | The layout from the Interface section. **Never a finding** takes Anthropic's `security-review` hard exclusions 1–8, 10–13, 15, 16 and precedents 1–8, 10–12, from `anthropics/claude-code-security-review` commit c19afa7. Exclusion 14 is narrowed (D6). **Where OWASP wins** covers exclusion 9 (becomes A03, for lockfile changes on this branch only), exclusion 17 (becomes A09, for logging removed or never written on an auth or security event), exclusion 1 (DoS stays out, A10 fail-open stays in), exclusion 14 (becomes A05, when untrusted prompt text can steer a tool call or file write), and the documentation exclusion (becomes A02, for Markdown whose frontmatter grants tools or permissions, and plugin manifests). Precedent 9 and the confidence scoring are left out: the blind verifier does that job | scenarios 1–5     |
| `plugins/zuko/agents/reviewer.md:26`                           | The seven Security bullets become: read `${CLAUDE_PLUGIN_ROOT}/references/owasp.md`, run its Context first step, check only the categories it picks                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | scenarios 1, 2    |
| `plugins/zuko/agents/reviewer.md:60`                           | The report format gains the `SCOPE` block, `CATEGORY`, `SEVERITY`, `SYMBOL` and `SNIPPET`, with the invoice-api example from the Interface section. The Decisions example gains `CATEGORY: decisions`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | scenarios 1, 2, 5 |
| `plugins/zuko/agents/finding-verifier.md:10`                   | Input names the new fields. Before judging, read the finding's category section in `owasp.md`; a match on its **Not a finding** list or **Never a finding** → REJECT. Output gains `SEVERITY`, on a confirmed security finding only: the reported tier or lower, from the grid                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | scenarios 3, 5    |
| `plugins/zuko/skills/review/SKILL.md:45`                       | Security bullets become a pointer to `owasp.md`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | scenario 2        |
| `plugins/zuko/skills/review/SKILL.md:75`                       | Delete the Trail of Bits line                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | Problem           |
| `plugins/zuko/skills/review/SKILL.md:105`                      | What the verifier sees: the claim plus `CATEGORY`, `SEVERITY`, `FILE`, `SYMBOL`, `SNIPPET`, never the failing case or the scope block. On a large diff, the kept severity is the lowest a confirming verifier returned, capped at the reported one                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | scenario 5        |
| `plugins/zuko/skills/review/SKILL.md:124`                      | The report layout from the Interface section: the `Security` and `Findings` header lines, security first by tier, then correctness, decisions, quality; the no-category and clean lines; the Not checked list. Line 137's "fix what survived" stays as is                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | scenarios 2, 5    |
| `plugins/zuko/scripts/tests/test-owasp-lens.sh` (new)          | The contract test, below                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | all               |
| `plugins/zuko/scripts/tests/fixtures/owasp-lens/` (new)        | `base/` (invoice-api on main: `invoice_api/db.py` with `run(sql, params)`, `invoice_api/auth.py` with `login_required` and the login-failure `log.warning`, `routes/export.py`, `uv.lock`), `branch.patch` (every scenario 1, 3, 4 and 5 seed) and `readme.patch` (README only)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | the seeded run    |
| `plugins/zuko/agents/finding-verifier.md:6`                    | `tools` gains `Bash`. One line: Bash is for `git diff` and `git show` only, to see the diff and the base version of the lines it judges                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | O10               |
| `plugins/zuko/scripts/scope-verifier-bash.sh` (new)            | PreToolUse Bash hook. Acts only when the hook input's `agent_type` is `zuko:finding-verifier`; any other caller exits 0 untouched. Allow-list: every invocation on the line, parsed with `lib/git-command.py`'s tokeniser, must be `git diff` or `git show`, with no global option but `--no-pager`/`-P` (so `-C`, `-c`, `--config-env`, `--git-dir`, `--exec-path` block; `-C` blocks because the verifier reads the repo it runs in and nothing else). Refused on the subcommand: `--ext-diff`, `--textconv`, `--output`, `--show-signature`, `--help`, any abbreviation of those, and a `%G` format placeholder (runs gpg). Also blocked: pipes, redirections, `$`, backticks, subshells, a leading word before `git`, and unparseable input. The block message names what it saw                                              | O10               |
| `plugins/zuko/hooks/hooks.json`                                | Wire `scope-verifier-bash.sh` under PreToolUse `Bash`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | O10               |
| `plugins/zuko/skills/review/SKILL.md` (Verification)           | A verifier that hits its turn limit is recorded as not confirmed, and is never resumed with added context                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | O10               |
| `plugins/zuko/scripts/tests/test-scope-verifier-bash.sh` (new) | The hook's tests, with payloads with and without `agent_type`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | O10               |

Reusing: `run.sh`'s `expect_*` helpers and its `$work` temp dir (the
`test-temp-dirs-live-under-run-sh` lesson); the existing blind-verifier flow and
2-of-3 vote (`SKILL.md:101`); the reviewer's existing `Bash`, used for the context
step's greps.

### Earn-it

| Added                               | Triggered by                                                                                                                                                                                                                                                                             |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `references/owasp.md`               | scenarios 1–5 need one list of checks and exclusions. Slice 5 reads the same file, so it cannot live inside `reviewer.md`                                                                                                                                                                |
| `SCOPE` block                       | scenario 2: the report names what was not checked. Also the `gate-scanned-nothing-is-not-a-pass` lesson                                                                                                                                                                                  |
| `SEVERITY` on the verifier's output | scenario 5: lower, never raise                                                                                                                                                                                                                                                           |
| `fixtures/owasp-lens/`              | O2: the seeded run needs a fixed diff. It is checked in so the run can be repeated by hand after a later prompt change                                                                                                                                                                   |
| `test-owasp-lens.sh`                | O2: the contract test                                                                                                                                                                                                                                                                    |
| `scope-verifier-bash.sh`            | O10: run 2's verifiers burned their turns hunting base versions without `git diff`, and the resumes that rescued them leaked the finder's context. A `tools:` pattern like `Bash(git diff *)` is not enforced (D8), so a hook is the only thing that holds the verifier to read-only git |

Cut: a per-category severity table (the grid plus the A03 rule covers every case),
a verifier model upgrade (no evidence yet that haiku misapplies the grid; the seeded
run is where that would show), and a second verifier pass for severity.

### Non-functionals

|                      |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Load**             | One `/review` per branch. Each reviewer reads `owasp.md` once (about 250 lines). Each verifier reads one category section (about 20 lines)                                                                                                                                                                                                                                                                                                                                                                                                                             |
| **Breaks first**     | At 10× findings on a large diff, that is 30 verifier runs. Tokens grow with them, which is why each verifier reads one section, not the whole file. Nothing else scales                                                                                                                                                                                                                                                                                                                                                                                                |
| **Security surface** | The verifier gains `Bash`, held by `scope-verifier-bash.sh` to read-only `git diff` and `git show` in the repo it runs in. The hook trusts the hook input's `agent_type` (set by Claude Code, proven in pentest-live O3) and treats the command as untrusted: allow-list per invocation, unparseable blocks. It trusts the user's own git config (a `diff.external` or textconv driver there still runs; the reviewed repo cannot set `.git/config`). The reviewer's `Bash` is unchanged. `owasp.md` is plugin text the agents obey, trusted the same as `reviewer.md` |
| **Proof it works**   | The next real `/review` in this repo (slice 7b's branch) prints a `Security   checked A0…` header line and a `Findings   N raw, M survived` line                                                                                                                                                                                                                                                                                                                                                                                                                       |
| **Rollout**          | No flag: zuko ships prompt changes by version, and a prompt has no runtime switch (as in every earlier zuko slice). Rollback is `git revert` of the slice's commits, then `/release` a patch                                                                                                                                                                                                                                                                                                                                                                           |

### Test plan

| Scenario            | Test                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Command                                                             |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| all (text is there) | `test-owasp-lens.sh`: `owasp.md` has the four fixed sections and exactly ten headings, `## A01:2025 Broken Access Control` to `## A10:2025 Mishandling of Exceptional Conditions`, in order, each with its three labelled parts. `reviewer.md` cites `${CLAUDE_PLUGIN_ROOT}/references/owasp.md` and carries `SCOPE`, `CATEGORY:`, `SEVERITY:`, `SYMBOL:`, `SNIPPET:`. `finding-verifier.md` cites `owasp.md` and carries `SEVERITY:`. `SKILL.md` has no `Trail of Bits`. The old bullet `Injection: SQL, command, template, path traversal` is gone from both files. `base/` plus `branch.patch`, and `base/` plus `readme.patch`, each apply with `git apply --check` in a repo under `$work` | `bash plugins/zuko/scripts/tests/run.sh owasp-lens`                 |
| O10 (the hook)      | `test-scope-verifier-bash.sh`: with `agent_type: zuko:finding-verifier`, `git diff main...HEAD`, `git show main:invoice_api/auth.py`, `git --no-pager diff`, and two git calls joined by `&&` exit 0; `ls`, `cat`, `git log`, `git -C /tmp diff`, `git -c x=y diff`, each refused option and its abbreviation, `%G?`, a pipe, a redirect, `$(...)`, a backtick, `sudo git diff`, and an unclosed quote exit 2 naming what they saw. The same `ls` with no `agent_type`, and with `agent_type: zuko:reviewer`, exits 0                                                                                                                                                                           | `bash plugins/zuko/scripts/tests/run.sh scope-verifier-bash`        |
| 1–5 (behaviour)     | The seeded run, below                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | `bash plugins/zuko/scripts/tests/run.sh` first, then the seeded run |

**E2E:** the seeded run. `/build` makes a scratch repo under the scratchpad from
`fixtures/owasp-lens/base/`, commits it on `main`, applies `branch.patch` on
`feat/ledger-export`, and runs, in it:

```
claude -p "/zuko:review" --plugin-dir <repo>/plugins/zuko --add-dir <repo>/plugins/zuko \
  --settings '{"env":{"ANTHROPIC_API_KEY":""}}' --output-format stream-json --verbose
```

This loads the repo's prompts, not the installed plugin cache (the
`installed-plugin-lags-the-repo` lesson). The O7 spike proved each flag.
`--add-dir` lets the agents read `owasp.md` from outside the scratch repo; without
it, `-p` mode denies the read. The `--settings` override blanks the API key that
`~/.claude/settings.json`'s `env` block sets, which otherwise fails the run with
"Invalid API key". `stream-json` records the reviewer's raw output as the Agent
tool's result, which the final report does not repeat. Writes are denied in `-p`
mode, so `/review` reports without fixing and the fixture stays clean. It passes
when:

- the raw reviewer output has an A05 finding at high, with `SYMBOL: export_ledger`
  (scenario 1), and a `SCOPE` block naming `db.run` and listing seven categories as
  not checked (scenario 2);
- none of the four decoys is reported (scenario 3);
- A03, A09 and A10 findings survive (scenario 4);
- the report shows A05 at medium, after the header lines (scenario 5).

The same run on `readme.patch` must print `Security   no category checked`. The
outputs go into this spec under `### Seeded run`, as O2 requires.

### Seeded run

Run 2026-09-25 at `f8f1aa2`, from scratch repos built from
`fixtures/owasp-lens/`, with the E2E command above (the key override passed as a
settings file). Both runs exited 0. The branch diff has 6 files, so the skill
took the large-diff path: two reviewers, three verifiers per finding. Writes are
denied in `-p`, so no fix was applied.

**Verdict: 4 of 5 scenarios pass, and the readme case passes. Scenario 4 fails.**

| Scenario | Result   | Evidence                                                                                                                                                                                                                                                                                                                                                                  |
| -------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1        | pass     | Reviewer: `CATEGORY: A05:2025 Injection`, `SEVERITY: high`, `SYMBOL: export_ledger`, `SNIPPET: cursor.execute("SELECT * FROM invoices WHERE customer = '" + customer + "' ORDER BY " + order)`                                                                                                                                                                            |
| 2        | pass     | Reviewer's scope block: `DEFENCES: invoice_api/db.py run(sql, params) — parameterised queries; every existing query goes through it`; `CHECKED: A01, A05, A10`; seven categories under `NOT CHECKED`, each with a reason. The claim says the query goes around `db.run`. The report's union lists 6 checked and 4 not checked, as the union rule says for two reviewers   |
| 3        | pass     | No security finding on the env var, the template or the test token. The reviewer listed them under "Not findings, after checking" (`ledger.html` is autoescaped; customer is regex-checked). One _quality_ finding cites `os.environ["INVOICE_DB_URL"]`, but for skipping the settings default and leaking the connection, not as a security issue. No rate-limit finding |
| 4        | **fail** | A09 survived (`low · A09:2025 … auth.py:25 in login`). A10 (`is_admin` returns True on error) and A03 (`requests-toolbelt 0.10.1`) were each reported, then dropped 1 of 3: the verifiers rejected them because nothing calls `is_admin` and nothing imports the package (O8)                                                                                             |
| 5        | pass     | Verifiers on the A05 finding returned high, high and medium; the report kept medium (`medium · A05:2025 Injection · invoice_api/exporters/ledger.py:11 in export_ledger`). Header: `Findings   6 raw, 4 survived`. Security came first, then correctness, then quality                                                                                                    |
| readme   | pass     | `Security   no category checked — the diff changes README.md only` and `Findings   0 raw, 0 survived — clean`; the reviewer's scope block has `CHECKED: none` and all ten under `NOT CHECKED`                                                                                                                                                                             |

Also seen: 13 of the 18 verifier runs stopped at their 12-turn limit
(`maxTurns: 12`) with partial output. The skill counted those as not confirming
(O9).

#### Run 2

Run 2026-09-25 at `4b153bf`, after the O8 and O9 fixes (A03 needs no caller,
`GET /export/all` calls `is_admin()`, `maxTurns: 20`). Same command, fresh
scratch repos, both exit 0. There were two reviewers, and 21 verifier runs
across 7 findings.

**Verdict: all five scenarios and the readme case pass on the output. The
verification behind them was not blind (O10), so the slice is not marked Built.**

| Scenario | Result | Evidence                                                                                                                                                                                                                                               |
| -------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1        | pass   | Reviewer: `CATEGORY: A05:2025 Injection`, `SEVERITY: high`, `FILE: invoice_api/exporters/ledger.py:11`, `SYMBOL: export_ledger`, and the execute line as `SNIPPET`                                                                                     |
| 2        | pass   | Both scope blocks name `invoice_api/db.py run(sql, params)`; the claim says the query goes around `db.run`. One reviewer lists seven categories under `NOT CHECKED`, each with a reason. The union report checks 7 and lists 3 as not checked          |
| 3        | pass   | No security finding on the env var, the template (`ledger.html` "is not a finding": autoescape on) or the test token. A correctness finding cites `os.environ["INVOICE_DB_URL"]` for skipping the settings default, as in run 1. No rate-limit finding |
| 4        | pass   | All three survived: `low · A03:2025 … uv.lock:19` (3 of 3), `low · A09:2025 … auth.py:25 in login` (2 of 3), `medium · A10:2025 … auth.py:35 in is_admin` (3 of 3)                                                                                     |
| 5        | pass   | A05 verifiers returned high five times and medium once; the report kept medium. Header: `Findings   7 raw, 7 survived`. Security came first (medium, medium, low, low), then correctness                                                               |
| readme   | pass   | `Security   no category checked — the diff changes README.md only`, `Findings   1 raw, 0 survived — clean`, and `CHECKED: none`                                                                                                                        |

**Not clean.** 17 events in the stream mention a verifier hitting its turn limit,
even at 20. The orchestrating session resumed 13 verifier runs with
`SendMessage`, and those messages carried context the verifier should not see:
"its caller is invoice_api/routes/export.py export_all", and, for A09, a
description of the change ("main had `log.warning(...)` … and this branch deletes
that line"). The session's own diagnosis: "they have no shell and can't see the
diff". The verifier has only `Read, Grep, Glob`, so it cannot run `git diff` to
establish its rule 3 ("a line this diff actually changed"), and it spends its
turns looking for the base version (O10).

#### Run 3

Run 2026-09-26 at `971f243`, after O10: the verifier has `Bash`, held by
`scope-verifier-bash.sh`, and the skill never resumes a verifier. Same command,
fresh scratch repos, all exit 0. There were two reviewers and 21 verifier runs
across 7 findings.

**Verdict: scenario 4 fails again. Scenarios 1, 2, 3 and 5, the readme case, zero
resumes and the hook criteria pass.**

| Criterion  | Result   | Evidence                                                                                                                                                                                                                                                       |
| ---------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1          | pass     | Reviewer: `CATEGORY: A05:2025 Injection`, `SEVERITY: high`, `SYMBOL: export_ledger`                                                                                                                                                                            |
| 2          | pass     | `DEFENCES:` names `invoice_api/db.py run(sql, params)`; the second reviewer's `CHECKED: A01, A03, A05` leaves seven under `NOT CHECKED`                                                                                                                        |
| 3          | pass     | No security finding on the four decoys. The unused Bearer header was raised as quality, not as a secret                                                                                                                                                        |
| 4          | **fail** | A10 survived (`high · A10:2025 … auth.py:35 in is_admin`, 3 of 3). A09 was dropped: 1 confirmed, 2 ran out of turns. A03 was dropped: 1 confirmed, 1 ran out of turns, and 1 rejected because it could not rule out a transitive dependency                    |
| 5          | pass     | A05 verifiers returned high, medium, high; the report kept medium. Header: `Findings   8 raw (7 after merging a duplicate), 2 survived`                                                                                                                        |
| readme     | pass     | `Security   no category checked — the diff changes README.md only`, `Findings   0 raw, 0 survived — clean`                                                                                                                                                     |
| resumes    | pass     | 0 `SendMessage` calls. The report lists the out-of-turn drops as "not confirmed", as the rule says                                                                                                                                                             |
| hook       | pass     | Verifier Bash that ran: 63 `git diff` and 70 `git show`, nothing else. The hook blocked 47 calls (`grep -r`, `find`, `git grep`, `git ls-files`, a pipe to `head`)                                                                                             |
| `ls` probe | pass     | A headless verifier on the real plugin ran `git diff main...HEAD --stat` (diffstat printed) and was blocked on `ls /`: "PreToolUse:Bash hook error: … scope-verifier-bash.sh]: Blocked: the finding-verifier may run only read-only `git diff` and `git show`" |

Still seen: 18 top-level events name a turn limit. The turns went to blocked calls:
the 47 the hook stopped, and 53 `git show` calls that `-p` denied ("Permission to
use Bash has been denied"). The review skill's `allowed-tools` grants
`Bash(git diff *)` but not `Bash(git show *)` (`skills/review/SKILL.md:9`) (O11).

#### Run 4

Run 2026-09-26 at `4bfd636`, after O11: `Bash(git show *)` added to the review
skill's `allowed-tools`, and the verifier told to search with Grep and Glob. Same
command, fresh scratch repos, both exit 0. There were two reviewers and 21 verifier
runs.

**Verdict: scenario 4 fails again. Everything else passes.**

| Criterion | Result   | Evidence                                                                                                                  |
| --------- | -------- | ------------------------------------------------------------------------------------------------------------------------- |
| 1         | pass     | Reviewer: `CATEGORY: A05:2025 Injection`, `SEVERITY: high`, `SYMBOL: export_ledger`                                       |
| 2         | pass     | Scope blocks name `db.run`; the second reviewer's `CHECKED: A01, A03, A05` leaves seven under `NOT CHECKED`               |
| 3         | pass     | No security finding on the four decoys                                                                                    |
| 4         | **fail** | A10 (3 of 3) and A03 (2 of 2 that answered) survived. A09 was dropped: 1 confirmed, 2 ran out of turns                    |
| 5         | pass     | A05 kept at high (3 of 3 high). Header: `Findings   8 raw (7 after merging a duplicate), 5 survived`; security came first |
| readme    | pass     | `Security   no category checked — the diff changes README.md only`, `Findings   0 raw, 0 survived — clean`                |
| resumes   | pass     | 0 `SendMessage` calls                                                                                                     |
| hook      | pass     | Verifier Bash that ran: 50 `git diff` and 66 `git show`, nothing else                                                     |

Counts: 16 top-level turn-limit events. 44 verifier calls were blocked by the hook,
all `grep -r`, `find` or pipes such as `git show main:app.py 2>/dev/null | head`.
38 verifier calls errored, all git's own exit 128 on paths that do not exist
(`git show main:tests/conftest.py`); `-p` denied no `git show` this time (O12).

#### Run 5

Run 2026-09-26 at `10d4fd3`, after O12: every hook block now says "To search or
list files, use the Grep or Glob tool; to read a file, use Read.", and
`maxTurns: 30`. Same command, fresh scratch repos, both exit 0. There were two
reviewers and 24 verifier runs.

**Verdict: every criterion passes.**

| Criterion | Result | Evidence                                                                                                                                                                                                                                                                 |
| --------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1         | pass   | Reviewer: `CATEGORY: A05:2025 Injection`, `SEVERITY: high`, `SYMBOL: export_ledger`, and the execute line as `SNIPPET`                                                                                                                                                   |
| 2         | pass   | First reviewer's scope block: `DEFENCES: invoice_api/db.py run(sql, params) — parameterised queries; every other query in the repo goes through it`, `CHECKED: A01, A05, A10`, and seven under `NOT CHECKED`, each with a reason. Its claim: "instead of calling db.run" |
| 3         | pass   | No security finding on the four decoys. `ledger.html` is listed as autoescaped                                                                                                                                                                                           |
| 4         | pass   | All three survived: `high · A10:2025 … auth.py:35 in is_admin`, `low · A03:2025 … uv.lock:19`, `low · A09:2025 … auth.py:25 in login`                                                                                                                                    |
| 5         | pass   | The A05 finding was reported high, and a confirming verifier's medium was kept: `medium · A05:2025 Injection`. Header: `Findings   9 raw (8 after merging a duplicate), 6 survived`; security first, then correctness                                                    |
| readme    | pass   | `Security   no category checked — the diff changes README.md only`, `Findings   0 raw, 0 survived — clean`                                                                                                                                                               |
| resumes   | pass   | 0 `SendMessage` calls                                                                                                                                                                                                                                                    |
| hook      | pass   | Verifier Bash that ran: 77 `git diff` and 100 `git show`, nothing else                                                                                                                                                                                                   |

| Count                              | Run 4 | Run 5                                                                                                   |
| ---------------------------------- | ----- | ------------------------------------------------------------------------------------------------------- |
| Top-level turn-limit events        | 16    | 4                                                                                                       |
| Verifier calls blocked by the hook | 44    | 64 (39 other git subcommands such as `git ls-files` and `git log`, 16 `find`, 7 `grep`, 1 `ls`, 1 `cd`) |
| Verifier calls that errored        | 38    | 63, all git's own exit 128 on paths that do not exist (`git show HEAD:pyproject.toml`)                  |

Blocks went up, but each one now tells the verifier where to go, and the turn-limit
events fell from 16 to 4. Both reviewers also noted that `-p` denied some of their
own Bash calls; they read the files instead, and nothing in the criteria depended
on it.

#### Run 6

Run 2026-09-26 at `dc4f0b2`, after the review fixes H1 to H5 to
`scope-verifier-bash.sh`: a character allow-list before the parse, the payload
read from a file with every unexpected exit ending as a block, and `--no-index`
no longer refused. Same command, fresh scratch repos, both exit 0. There were two
reviewers and 18 verifier runs.

**Verdict: scenario 4 fails, at the reviewer this time. Everything else passes.**

| Criterion | Result   | Evidence                                                                                                                                                                                                                                                                                                       |
| --------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1         | pass     | Reviewer: `CATEGORY: A05:2025 Injection`, `SEVERITY: high`, `SYMBOL: export_ledger`                                                                                                                                                                                                                            |
| 2         | pass     | Scope blocks name `db.run`; the second reviewer's `CHECKED: A01, A03, A05` leaves seven under `NOT CHECKED`                                                                                                                                                                                                    |
| 3         | pass     | No security finding on the four decoys                                                                                                                                                                                                                                                                         |
| 4         | **fail** | A10 (3 of 3) and A03 (3 of 3) survived. A09 was never raised: the reviewer covering `auth.py` listed A09 under `CHECKED` and wrote "A07 login() and the session handling are unchanged", though the diff deletes `log.warning("login failed for %s", username)` from `login()`. No verifier was involved (O13) |
| 5         | pass     | Header: `Findings   7 raw, 6 survived`; security came first, then correctness and quality. A05 was kept at high (3 of 3)                                                                                                                                                                                       |
| readme    | pass     | `Security   no category checked — the diff changes README.md only`, `Findings   0 raw, 0 survived — clean`                                                                                                                                                                                                     |
| resumes   | pass     | 0 `SendMessage` calls                                                                                                                                                                                                                                                                                          |
| hook      | pass     | Verifier Bash that ran: 47 `git diff` and 49 `git show`, nothing else                                                                                                                                                                                                                                          |

| Count                              | Run 5 | Run 6                                                 |
| ---------------------------------- | ----- | ----------------------------------------------------- |
| Top-level turn-limit events        | 4     | 0                                                     |
| Verifier calls blocked by the hook | 64    | 50                                                    |
| Verifier calls that errored        | 63    | 38, all git's own exit 128 on paths that do not exist |

The hook fixes did not break the verifiers' own git calls, and no verifier ran out
of turns. Scenario 4 now depends on the reviewer spotting a deleted line: it did
in runs 2 to 5, and missed it in run 6.

#### Run 7

Run 2026-09-26 at `4268122`, after O13 (the A09 check reads removed lines) and the
/review fixes F1 to F3 (permission frontmatter is configuration, `BASE` passed to
the verifier, examples matching the fixture). Same command, fresh scratch repos,
both exit 0. There were two reviewers and 21 verifier runs.

**Verdict: scenario 4 fails again, at the verifiers. Everything else passes.**

| Criterion | Result | Evidence |
| --- | --- | --- |
| 1 | pass | Reviewer: `CATEGORY: A05:2025 Injection`, `SEVERITY: high`, `SYMBOL: export_ledger` |
| 2 | pass | Both scope blocks name `invoice_api/db.py run(sql, params)`; the second reviewer's `CHECKED: A01, A03, A05` leaves seven under `NOT CHECKED` |
| 3 | pass | No security finding on the four decoys |
| 4 | **fail** | A09 was raised and survived (`medium · A09:2025 … invoice_api/auth.py:25 in login`), so the O13 fix held. A10 survived 3 of 3. A03 was raised (`low`) and dropped 1 of 3: "The other two verifiers hit their turn limit, which the rules count as 'not confirmed'" (O17) |
| 5 | pass | A05 kept at high (3 of 3). Header: `Findings   8 raw, 4 survived`; security came first |
| readme | pass | `Security   no category checked — the diff changes README.md only`, `Findings   0 raw, 0 survived — clean` |
| resumes | pass | 0 `SendMessage` calls |
| hook | pass | Verifier Bash that ran: 53 `git diff` and 109 `git show`, nothing else |

| Count | Run 6 | Run 7 |
| --- | --- | --- |
| Top-level turn-limit events | 0 | 18 |
| Verifier calls blocked by the hook | 50 | 71 (45 other git subcommands, 15 `find`, 6 `grep`, 3 `uv`, 2 `ls`) |
| Verifier calls that errored | 38 | 65 |

### Chunks

| Chunk | Scenarios  | Files owned                                                                                       |
| ----- | ---------- | ------------------------------------------------------------------------------------------------- |
| A     | all        | `scripts/tests/test-owasp-lens.sh`, `scripts/tests/fixtures/owasp-lens/`                          |
| B     | 1–5        | `references/owasp.md`                                                                             |
| C     | 1, 2, 3, 5 | `agents/reviewer.md`, `agents/finding-verifier.md`, `skills/review/SKILL.md`                      |
| D     | O10        | `scripts/scope-verifier-bash.sh`, `scripts/tests/test-scope-verifier-bash.sh`, `hooks/hooks.json` |

A goes first and lands red (the `harness-before-the-chunks-it-proves` lesson). B and
C run in parallel from A's commit: the only thing C needs from B is the ten heading
strings, and this spec fixes those. The seeded run goes after all three merge. No
shared files.

### Risks

| Risk                                                                                                                 | Mitigation                                                                                                                                                    |
| -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The seeded run is one sample of non-deterministic output. A later prompt edit can regress without anything going red | Accepted at O2. The fixture is checked in, so a rerun is one command. The contract test still catches a deleted category or field                             |
| The context step wrongly skips a category (says A07 is untouched when the diff changes login)                        | Every skipped category is printed with its reason, so the user sees the claim. The seeded diff removes a login log to test exactly this, and A09 must survive |
| The haiku verifier misplaces a finding on the grid                                                                   | It can only lower, so the worst case is an under-rated finding, and it still gets fixed (D7). Scenario 5 in the seeded run checks one lowering                |
| The seeded run depends on this machine's settings (the blanked key)                                                  | Settled by O7. On another machine, drop the `--settings` override; the rest of the command holds                                                              |
| Anthropic's list changes upstream                                                                                    | `owasp.md` names the commit it copied (c19afa7). Updating it is a deliberate edit, not a sync                                                                 |

### Decisions to record

Recorded as D4, D5, D6, D7, D8.

## Open items

| ID                                                                 | What                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Type     | Raised at     | Owner  | Status   | Answer                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------------- | ------ | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| O1                                                                 | What severity changes in `/review`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | question | spec p1       | user   | Resolved | Order and label only; every confirmed finding is still fixed. Slice 5 uses severity to block a release                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| O2                                                                 | How to prove the reviewer follows `owasp.md`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | question | spec p1       | user   | Resolved | A contract test in `run.sh`, plus one `/review` run on a seeded diff during `/build`, recorded in this spec. No eval suite. The run is not repeated on later changes                                                                                                                                                                                                                                                                                                                                                                                                           |
| O3                                                                 | The 2025 category names and IDs                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | question | spec p1       | claude | Resolved | A01–A10 as in the shape, read from top10.owasp.org/2025 on 2026-09-25. The page calls it "the 2025 version" and does not say release candidate                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| O4                                                                 | The exact exclusion list in Anthropic's `security-review`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | unproven | spec p1       | claude | Resolved | 17 hard exclusions and 12 precedents, read from anthropics/claude-code-security-review `.claude/commands/security-review.md` at c19afa7 on 2026-09-25. Mapped in the Changes row for `owasp.md`                                                                                                                                                                                                                                                                                                                                                                                |
| O5                                                                 | Keep Anthropic's exclusion 14 (user content in AI prompts is not a vulnerability)?                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | question | spec p3       | user   | Resolved | Narrowed: a finding under A05 only when untrusted prompt text can steer a tool call or file write (D6)                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| O6                                                                 | Does `${CLAUDE_PLUGIN_ROOT}` resolve inside an agent's body?                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | unproven | spec p3       | claude | Resolved | Yes: substituted inline in skill, command and agent content (code.claude.com/docs/en/plugins-reference, Environment variables), read 2026-09-25                                                                                                                                                                                                                                                                                                                                                                                                                                |
| O7                                                                 | `claude -p "/zuko:review" --plugin-dir plugins/zuko` runs the repo's zuko (not the installed cache) and its `disable-model-invocation` skill headless                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | unproven | spec p3       | poc    | Resolved | Yes, spiked 2026-09-25. A marked copy's reviewer printed its marker (`SPIKE-7A-AGENT`), and the skill followed the copy's added instruction. Needs `--add-dir` on the plugin folder, or `-p` denies reading its references. Needs the `--settings` override that blanks the API key here, or the key in `~/.claude/settings.json` fails the run with "Invalid API key". Writes are denied in `-p`, so the run reports without fixing. The E2E command is updated                                                                                                               |
| O8                                                                 | "Where OWASP wins" makes an added dependency (A03) and a new fail-open check (A10) findings by rule, but the verifier's reachability bar rejects them when nothing yet calls or imports the code. In the seeded run both were dropped 1 of 3 ("nothing calls `is_admin`", "nothing imports it"). Options: exempt A03 and A10 fail-open from the reachability test in `finding-verifier.md`; or accept that they surface only once reachable, and rewrite scenario 4 and the fixture (give `is_admin` a caller)                                                                                                                                                                                                                                                              | question | build         | user   | Resolved | A03 is exempt from the reachability test: a dependency added or changed in the lockfile is a finding from the diff alone, since install-time risk needs no caller. A10 stays reachability-bound; the fixture now calls is_admin() from a route (user, 2026-09-25). Commits f651882, 4b153bf                                                                                                                                                                                                                                                                                    |
| O9                                                                 | 13 of 18 verifier runs in the seeded run hit `maxTurns: 12` (`agents/finding-verifier.md:7`) before giving a verdict. Reading the `owasp.md` sections now costs turns, and a partial output counts as not confirming. Raise the cap (e.g. 20), or have the skill paste the category section into the verifier prompt                                                                                                                                                                                                                                                                                                                                                                                                                                                        | flag     | build         | user   | Resolved | Raise finding-verifier maxTurns 12 to 20; the turns went to tracing code (214 calls: 102 Read, 62 Grep, 36 Glob, 14 owasp.md reads), longest run 17 (user, 2026-09-25). Commit fa0bf86                                                                                                                                                                                                                                                                                                                                                                                         |
| O10                                                                | The finding-verifier cannot see the diff: with only `Read, Grep, Glob` it cannot run `git diff`, so it cannot establish rule 3 ("a line this diff actually changed") and burns turns looking for the base version. In run 2, 17 events show verifiers hitting the 20-turn cap, and the orchestrator resumed 13 of them with `SendMessage` messages that leaked the finder's context ("its caller is … export_all", a description of the change). That breaks the blind rule (`review/SKILL.md`, "It never sees the finder's reasoning"). Options: have the skill paste the finding's own diff hunk (`git diff` output for `FILE`, code only) into every verifier prompt and forbid resumes that add context; or give the verifier `Bash(git diff *)` and `Bash(git show *)` | flag     | build (run 2) | user   | Resolved | Give the verifier `Bash`, scoped by a zuko PreToolUse hook on `agent_type` (user, 2026-09-26; D8). A `tools:` pattern is not enforced: the sub-agents docs say a `disallowedTools` entry with a specifier "still removes the whole tool from the subagent, not only the matching commands", and that inside `Agent(...)` in a subagent "any type list inside the parentheses is ignored". A marked copy with `tools: Read, Grep, Glob, Bash(git diff *), Bash(git show *)`, run headless with all Bash allowed, ran both `git diff main...HEAD --stat` and `ls /` (2026-09-26) |
| O11                                                                | Run 3: verifiers still run out of turns (18 turn-limit events), and scenario 4 fails because A09 and A03 are dropped with 2 and 1 verifiers out of turns. The turns go to calls that are refused: 53 `git show` calls denied because `skills/review/SKILL.md:9` `allowed-tools` has `Bash(git diff *)` but not `Bash(git show *)`, and 47 `grep`/`find`/`git grep`/`git ls-files` calls the hook blocked, where the verifier's own Grep and Glob tools would have worked. Options: add `Bash(git show *)` to the review skill's `allowed-tools`, and tell the verifier to search with Grep and Glob, never Bash; and/or raise `maxTurns` again                                                                                                                              | flag     | build (run 3) | user   | Resolved | Add Bash(git show *) to review/SKILL.md allowed-tools (53 git show calls were denied in run 3) and tell the verifier to search with its Grep and Glob tools, never Bash (47 grep/find/ls-files calls blocked by the hook); maxTurns stays 20 (user, 2026-09-26). Commit 4bfd636                                                                                                                                                                                                                                                                                                |
| O12                                                                | Run 4, after O11: scenario 4 still fails. A09 (the removed failed-login log) was dropped with 1 confirmed and 2 verifiers out of turns, and 16 top-level events name a turn limit. No `git show` was denied this time (all 38 errors are git's own exit 128 on paths that do not exist, e.g. `git show main:tests/conftest.py`). But the verifiers still sent 44 `grep -r`/`find` calls to Bash that the hook blocked, despite the new line. Options: raise `maxTurns`; make the hook's block message say "use the Grep or Glob tool"; or accept that some findings drop as not confirmed and rewrite scenario 4 to require only that A03, A09 and A10 are raised by the reviewer                                                                                           | flag     | build (run 4) | user   | Resolved | Hook block message redirects searches to the Grep and Glob tools, and finding-verifier maxTurns 20 to 30 as margin (run 4: 44 grep/find calls blocked, 16 turn-limit events; user 2026-09-26). Commit 10d4fd3; run 5 passes                                                                                                                                                                                                                                                                                                                                                    |
| O13                                                                | Run 6: scenario 4 fails at the reviewer, not the verifier. The reviewer covering `auth.py` listed A09 as checked and wrote "login() and the session handling are unchanged", though the diff deletes the failed-login `log.warning` from `login()`. Runs 2 to 5 raised it every time; the seeded run is one sample (O2). Options: accept it as the variance O2 already accepted and mark the slice Built on runs 5 and 6 together; or make the reviewer's A09 check read the removed lines (`git diff` lines starting with `-`) of every auth function first, which 7b's regression-aware review also covers                                                                                                                                                                | flag     | build (run 6) | user   | Resolved | The A09 check reads every removed line in auth and security code; a removed log call on an auth or security event is a finding (run 6: the reviewer wrote 'login() unchanged' over a deleted failed-login log; user 2026-09-26)                                                                                                                                                                                                                                                                                                                                                |
| O14                                                                | /review F1: `owasp.md`'s "documentation files such as Markdown" exclusion hides permission changes in agent and skill files, which are Markdown with frontmatter                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | flag     | /review       | user   | Resolved | Plain docs stay excluded; a Markdown file with frontmatter that grants tools or permissions (`tools:`, `allowed-tools:`, `disallowedTools:`, hooks, or a plugin manifest) is configuration, and a widened permission there is an A02 finding. In "Where OWASP wins" and in A02's check list (user, 2026-09-26)                                                                                                                                                                                                                                                                 |
| O15 | /review F2: `finding-verifier.md` hard-codes `main` in `git diff main...HEAD` and `git show main:`, so a branch cut from anything else is judged against the wrong base | flag | /review | user | Resolved | The review skill passes the branch point it already measures (`SKILL.md` "Size the effort") to each verifier as `BASE: <ref or sha>`; the verifier runs `git diff <BASE>...HEAD -- <file>` and `git show <BASE>:<file>`. The hook accepts refs like `origin/main` and shas (user, 2026-09-26) |
| O16 | /review F3: scenario 1 and the Interface examples cite line 31 of `exporters/ledger.py` and the bare `/export` route, but the fixture has `invoice_api/exporters/ledger.py` with the execute call at line 11, under `GET /export/ledger` | flag | /review | user | Resolved | Scenario 1 and the Interface examples now name `invoice_api/exporters/ledger.py:11`, `GET /export/ledger` and `invoice_api/routes/export.py:27`; the fixture is unchanged, and the contract test ties the spec to it (user, 2026-09-26) |
| O17 | Run 7: scenario 4 fails at the verifiers again. A03 (the unused `requests-toolbelt` in `uv.lock`) was dropped 1 of 3, with two verifiers out of turns, and turn-limit events went from 0 in run 6 to 18 in run 7 with no change to the verifier or the hook. The hook blocked 71 verifier calls (45 other git subcommands such as `git ls-files` and `git log`, 15 `find`). The turn budget swings run to run; the same fixture has given 0, 4, 16 and 18 turn-limit events. Options: let the verifier run `git log` and `git ls-files` too; raise `maxTurns` above 30; or treat a verifier that ran out of turns as absent, not as a no, so 1 of 1 answering confirms | flag | build (run 7) | user | Open | — |
| _Never delete this section or its rows. See references/ledger.md._ |

## Glossary

- **Fail-open** — on error, the code lets the request through instead of refusing it.
- **Lockfile** — the file pinning exact dependency versions (`uv.lock`,
  `package-lock.json`).
- **SNIPPET / SYMBOL** — the offending line as written, and the function or class it
  sits in, so a finding still points at the right code after lines move.
- **Blind verifier** — a second agent that re-judges a finding without seeing why the
  first agent thought it was a bug.
