---
name: security-review
description: >
  Reviews a pending diff for common security weaknesses before it ships.
  Looks for injection sinks, missing authn/authz, hardcoded secrets, weak
  crypto, input-validation gaps, PII in logs, and vulnerable dependencies.
  Auto-invoked as step 0 of /forge:ship and step 6 of /forge:fix. Can also
  be invoked manually via /forge:security-review or phrases like "review
  for security", "check this diff for vulnerabilities", "owasp check this",
  or "security-review". Emits one of three results — PASS, WARN, or FAIL —
  and hands control back to the caller.
---

# Security Review

Review a pending diff against a focused security checklist and return a
three-valued result the caller uses as a gate.

Return values:

- **PASS** — no findings. Silent result.
- **WARN** — non-blocking findings. Caller prompts the user.
- **FAIL** — blocking findings (e.g. hardcoded live secret, SQL string
  concatenation with user input). Caller must stop the pipeline.

## Step 1 — Determine diff scope

Resolve the diff to review. In order:

1. If `$ARGUMENTS` contains a ref range (e.g. `main..HEAD`), use it.
2. If the branch has an upstream, use `@{upstream}..HEAD` plus the working
   tree (`git diff` + `git diff --cached`).
3. Otherwise use `main..HEAD` plus the working tree. If `main` is not an
   ancestor, try `develop`, then fall back to the last 20 commits.

Collect:

- File list (`git diff --name-status <range>` + working tree)
- Full diff (`git diff <range>`, `git diff`, `git diff --cached`)
- Dependency manifest changes (`package.json`, `pyproject.toml`,
  `Cargo.toml`, `go.mod`, `Gemfile`, `*.csproj`) — needed for the
  dependency check

## Step 2 — Run the checklist

Evaluate every category below against the diff. For each hit, record:
category, severity (WARN|FAIL), file:line, one-line explanation.

### 2.1 — Injection

- **SQL string concatenation / template injection** (FAIL)
  Look for raw queries built with `+`, `%` formatting, or template literals
  that interpolate request data. Parametrised queries are fine.
- **`exec` / `eval` / `Function(...)` with user input** (FAIL)
  Any dynamic code evaluation that touches request-shaped data.
- **Shell injection** (FAIL)
  Shell calls (`child_process.exec`, `subprocess.Popen(..., shell=True)`,
  `os.system`, backticks) built from user input.

### 2.2 — Authentication & authorization

- **New routes without auth middleware** (WARN by default, FAIL if the route
  clearly returns user data)
  Detect newly added route definitions (`app.get`, `router.post`,
  `@GetMapping`, etc.) and check that a known auth middleware decorator is
  applied — the repo's own middleware name is usually documented in
  `CLAUDE.md`. When unclear, emit WARN.
- **Missing role / permission check** (WARN)
  New routes that mention `admin`, `owner`, or privileged data should have a
  role check. Flag absence.

### 2.3 — Secrets in source

- **Hardcoded API key / token / key material** (FAIL)
  High-confidence patterns overlap with the `secret-scan` hook. Re-run the
  same regex set here in case the diff hasn't been committed yet.

### 2.4 — Crypto

- **`md5` / `sha1` for anything security-adjacent** (WARN)
  Password hashing, token derivation, HMAC. Non-security uses (cache keys,
  fingerprints) are fine if the comment or context makes it clear.
- **`Math.random()` / `rand()` for tokens or secrets** (FAIL)
  Use `crypto.randomBytes`, `secrets.token_urlsafe`, `rand::thread_rng` with
  a CSPRNG, etc.
- **Hardcoded IVs / keys** (FAIL)

### 2.5 — Dependencies

If a dependency manifest changed, run the stack-appropriate vulnerability
scan and surface any HIGH/CRITICAL advisories:

| Stack  | Command                                                  |
| ------ | -------------------------------------------------------- | ------------------------ |
| Node   | `npm audit --omit=dev --json`                            |
| Python | `pip-audit --format json` (if installed)                 |
| Go     | `govulncheck ./...`                                      |
| Rust   | `cargo audit --json`                                     |
| Ruby   | `bundler-audit check`                                    |
| .NET   | `dotnet list package --vulnerable --include-transitive`  |
| GitHub | `gh api repos/{owner}/{repo}/dependabot/alerts --jq '.[] | select(.state=="open")'` |

HIGH/CRITICAL → FAIL; MODERATE → WARN; LOW → ignore. If the scanner is not
installed, emit a WARN explaining how to install it — don't fail for tooling
gaps.

### 2.6 — Input validation

- **Missing validation on request bodies** (WARN)
  New handlers that read `req.body` / `request.json()` without going through
  a validator (zod, pydantic, joi, Bean Validation, etc.).
- **Unsafe deserialization** (FAIL)
  `pickle.loads`, `yaml.load` without `SafeLoader`, `ObjectInputStream`
  reading untrusted data.

### 2.7 — Logging / PII

- **PII or secrets in log lines** (WARN)
  Log calls whose format strings include `password`, `token`, `email`,
  `ssn`, or similar.

## Step 3 — Resolve the verdict

- **FAIL** if any FAIL-severity finding is present.
- Else **WARN** if any WARN-severity finding is present.
- Else **PASS**.

## Step 4 — Render the result

Print exactly one of:

```
SECURITY-REVIEW: PASS
```

```
SECURITY-REVIEW: WARN (<N>)
<category> [<severity>] <file>:<line> — <one-line explanation>
<category> [<severity>] <file>:<line> — <one-line explanation>
```

```
SECURITY-REVIEW: FAIL (<N>)
<category> [<severity>] <file>:<line> — <one-line explanation>
...
```

The caller (`/forge:ship` or `/forge:fix`) parses the first line and decides
whether to continue, prompt, or abort.

## Step 5 — Do not modify code

This skill is read-only. It never edits files, stages anything, or runs
`git commit`. If the user wants a fix, they ask `/forge:fix` or return to
`/forge:build`.
