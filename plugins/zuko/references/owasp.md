# OWASP Top 10:2025 for a diff

The security lens `/review` runs, and the list slice 5's pentest walks. It
checks a branch diff against the ten categories of OWASP Top 10:2025
(top10.owasp.org/2025). For each category it says when a diff can touch it,
what to check, and what is not a finding.

Read it top to bottom once: context first, then severity, then the two
exclusion sections, then only the categories the context step picked.

## Context first

Before judging any line, learn how this repo already defends itself. Grep for
it; do not assume it.

- **Access control:** the decorator, middleware or check that guards a route
  or command (`login_required`, `requireAuth`, a policy class).
- **Validation:** where input is parsed or checked before use (schemas,
  regexes, `CUSTOMER.match`, pydantic models).
- **Queries:** the parameterised helper every other query goes through
  (`db.run(sql, params)`, an ORM, a query builder).
- **Escaping and rendering:** the template engine and whether autoescape is on;
  the shell-free way the repo runs commands (`subprocess.run([...])`).

List each defence you found in the `DEFENCES:` line of the scope block, with
its file. New code that bypasses one of them is the strongest kind of finding:
the claim names the defence it skipped ("builds SQL by concatenation instead of
calling db.run").

The same step picks the categories. Read each category's "The diff can touch
it when" line against the diff. Check only the categories that match. Every
other category goes in `NOT CHECKED:` with a one-line reason drawn from the
diff ("A07 no login, session or password code changed"). A diff that touches no
category says so; that is a result, not a skipped review.

## Severity

Exploitability × impact. Between two tiers, pick the lower.

| Exploitability ↓ · Impact →                                     | **Severe** — code runs, auth bypassed, every user's data | **Serious** — one other user's data, a secret, a privilege step | **Limited** — no secret, a missing log, own data only |
| --------------------------------------------------------------- | -------------------------------------------------------- | --------------------------------------------------------------- | ----------------------------------------------------- |
| **Direct** — anyone, one request, no login                      | critical                                                 | high                                                            | medium                                                |
| **Conditional** — a logged-in user, a setting, or a second step | high                                                     | medium                                                          | low                                                   |
| **Privileged** — an admin, or local access                      | medium                                                   | low                                                             | low                                                   |

- A new or changed dependency (A03) with no known advisory is low. With one, it
  takes the advisory's severity.
- The reviewer sets the tier. The verifier may lower it, never raise it.
- Only security findings carry a severity.

## Never a finding

These hold in every category. They start from Anthropic's `security-review`
command (anthropics/claude-code-security-review,
`.claude/commands/security-review.md` at commit c19afa7): its hard exclusions
1–8, 10–13, 15 and 16, and its precedents 1–8 and 10–12. Exclusions 1, 9, 14
and 17 are narrowed under "Where OWASP wins" below. Its precedent 9 and its
confidence scores are left out, because the blind verifier does that filtering.

- Denial of service, resource exhaustion, memory or CPU exhaustion, rate
  limiting, and regex DoS.
- Secrets or credentials stored on disk when they are otherwise secured.
- Missing validation on a field with no security impact.
- A missing hardening measure with no concrete vulnerability behind it.
- Race conditions and timing attacks that are theoretical rather than
  practical.
- Memory-safety issues in a memory-safe language (Rust, Python, Go, Java, JS).
- Files that are only tests or only used to run tests, and documentation files
  such as Markdown.
- Log spoofing: unsanitised input written to a log.
- SSRF that controls only the path. SSRF counts only when the attacker controls
  the host or the protocol.
- Regex injection: untrusted text inside a regex.
- GitHub Actions input concerns, unless an untrusted trigger clearly reaches
  them with a specific attack path.
- Values from environment variables and CLI flags. Both are trusted; an attack
  that needs control of one is invalid.
- Logging a URL. Logging non-PII data, even if sensitive. Logging is a finding
  only when it writes a secret, a password or PII.
- UUIDs: assume them unguessable.
- Memory or file-descriptor leaks.
- Tabnabbing, XS-Leaks, prototype pollution and open redirects, unless the
  path is certain.
- XSS in React or Angular, or through a template engine with autoescape on,
  unless the code uses a raw-HTML escape hatch (`dangerouslySetInnerHTML`,
  `bypassSecurityTrustHtml`, `|safe`, `Markup`).
- Missing permission checks in client-side JS or TS; the server does that.
- Notebook (`.ipynb`) issues without a specific untrusted input that reaches
  them.
- Command injection in a shell script, unless untrusted input concretely
  reaches it.

## Where OWASP wins

Four exclusions in Anthropic's list would hide an OWASP 2025 category. Here
OWASP wins, narrowed to what this diff introduced.

- **Outdated libraries (exclusion 9) → A03.** A dependency this branch adds, or
  whose version it changes, in a lockfile or manifest is a finding. A
  dependency already there before the branch is not. The finding needs no
  caller: the risk lands at install time, so the lockfile line in the diff is
  the whole path, whether or not any code imports the package.
- **Missing audit logs (exclusion 17) → A09.** Logging this branch removes, or
  never writes, on an auth or security event (a failed login, a permission
  denied, a role change) is a finding. Missing logs elsewhere are not.
- **Denial of service (exclusion 1) → A10.** DoS stays out. Code that fails
  open stays in: an auth or validation check that allows the request when it
  errors.
- **User content in AI prompts (exclusion 14) → A05.** Untrusted text reaching
  a prompt is not a finding by itself. It is one when that text can make the
  model call a tool or write a file the user did not ask for, e.g. a skill that
  reads a PR template and obeys "run git push --force" written in it.

## A01:2025 Broken Access Control

**The diff can touch it when:** it adds or changes a route, command, handler or
query that reads or writes data belonging to a user, tenant or role.

**Check:**

- A new entry point without the repo's access-control guard.
- A lookup by an id from the request with no check that the caller owns it.
- A role or permission check moved, weakened, or done only on the client.
- File paths built from input that can leave the intended directory (path
  traversal).

**Not a finding:**

- An entry point that is public by design and says so.
- A client-side check with the server-side check still in place.

## A02:2025 Security Misconfiguration

**The diff can touch it when:** it changes config, deployment files, framework
settings, CORS, headers, debug flags, or default credentials.

**Check:**

- Debug mode, stack traces or admin consoles turned on for production.
- CORS opened to `*` with credentials, or a security header removed.
- A default password, key or account shipped in config.
- A permission widened in a manifest, IAM policy or container spec.

**Not a finding:**

- A development-only config file that production never loads.
- A missing hardening header with no concrete attack behind it.

## A03:2025 Software Supply Chain Failures

**The diff can touch it when:** it changes a lockfile, a manifest's
dependencies, a CI install step, or vendors third-party code.

**Check:**

- A dependency added, or its version changed, in the lockfile. Name it and the
  version. This needs no caller; see **Where OWASP wins**.
- A dependency pulled from a new registry, a git URL, or an unpinned range.
- An install or build step that runs a downloaded script.

**Not a finding:**

- A dependency already in the lockfile before this branch, at the same version.
- A dev-only tool in a test group, unless it runs in CI with secrets.

## A04:2025 Cryptographic Failures

**The diff can touch it when:** it hashes, signs, encrypts, generates tokens,
or handles TLS or certificates.

**Check:**

- Passwords hashed with a fast hash (MD5, SHA-1, plain SHA-256) instead of a
  password hash.
- Tokens from a non-cryptographic random source.
- Secrets compared with `==` where timing matters.
- Certificate validation turned off.

**Not a finding:**

- A fast hash used for a cache key or checksum, not a secret.
- UUIDs used as identifiers.

## A05:2025 Injection

**The diff can touch it when:** it builds a query, shell command, file path,
template or prompt from input.

**Check:**

- A query built by string formatting or concatenation instead of the repo's
  parameterised helper.
- A shell command built from input, or `shell=True` with any input in it.
- `eval`, `exec`, unsafe YAML or pickle loads on input.
- Input rendered through a raw-HTML escape hatch.
- Untrusted text in a prompt that can steer a tool call or a file write.

**Not a finding:**

- A value from an env var or a CLI flag. Both are trusted.
- Output through a template engine with autoescape on.
- A value checked against a strict allow-list before it reaches the sink; the
  claim then has to show the check does not hold.

## A06:2025 Insecure Design

**The diff can touch it when:** it adds a new flow, a new trust boundary, or a
new way for data to move between users or systems.

**Check:**

- A flow that trusts a value the client controls for a decision the server
  should make (price, role, owner id).
- A multi-step process that can be done out of order to skip a check.
- A new boundary with no control at all where the rest of the repo has one.

**Not a finding:**

- A design preference with no concrete abuse path.
- A missing control the repo has nowhere else and the spec did not ask for.

## A07:2025 Authentication Failures

**The diff can touch it when:** it changes login, sessions, passwords, tokens,
MFA or account recovery.

**Check:**

- A login path that accepts a missing or empty credential.
- Sessions not rotated on login, or not ended on logout.
- A reset or recovery token that does not expire or can be reused.
- Password rules or lockout removed.

**Not a finding:**

- No rate limit on login; that is excluded as DoS.
- A session setting that matches the framework's secure default.

## A08:2025 Software or Data Integrity Failures

**The diff can touch it when:** it deserialises data, applies updates, loads
plugins, or changes a CI or release path.

**Check:**

- Deserialising untrusted data into objects (pickle, unsafe YAML, Java
  serialisation).
- An update, plugin or artifact loaded without checking its signature or hash.
- A CI step that runs code from a fork or an untrusted trigger with secrets.

**Not a finding:**

- JSON parsed into plain data.
- A CI change with no untrusted trigger that reaches it.

## A09:2025 Security Logging and Alerting Failures

**The diff can touch it when:** it adds, removes or changes logging on an auth
or security event.

**Check:**

- Read the removed (`-`) lines of every changed function in auth, session,
  access-control and security code, not only the added ones. A function whose
  other lines are unchanged can still have lost its log call.
- A deleted log or alert call on an auth or security event is a finding
  even when nothing was added, e.g. `log.warning("login failed for %s", username)`
  gone from `login()`.
- A log line removed from a failed login, a permission denied, or a role change.
- A new auth or security event with no log at all, where the repo logs its
  siblings.
- A secret, password or PII written to a log.

**Not a finding:**

- Missing logs on events that are not auth or security events.
- Logging a URL, or non-PII data.
- Unsanitised input in a log line (log spoofing).

## A10:2025 Mishandling of Exceptional Conditions

**The diff can touch it when:** it adds or changes error handling around auth,
validation, payments, or any check that decides whether to allow something.

**Check:**

- A check that allows the request when it raises: `except: return True`, a
  default of "allowed" on error.
- An error swallowed on a security path so the caller carries on as if it
  passed.
- A retry or fallback that skips a check.

**Not a finding:**

- Error handling that fails closed (deny, abort, re-raise).
- Resource exhaustion or crashes; those are excluded as DoS.
