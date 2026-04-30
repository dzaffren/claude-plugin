# Commit Message Conventions

Follows [Conventional Commits](https://www.conventionalcommits.org/).

## Format

```
type(scope): imperative description
                                      ← blank line
[optional body — what and why]
                                      ← blank line
[optional footer]
```

## Subject Line Rules

- **Max 72 characters**
- **Lowercase** — no capital letters
- **Imperative mood** — "add", "fix", "validate" — not "added", "fixes", "validates"
- **No period** at the end
- **Type is required**, scope is recommended

## Types

| Type       | When to Use                                        |
| ---------- | -------------------------------------------------- |
| `feat`     | New functionality visible to users or consumers    |
| `fix`      | Bug fix                                            |
| `test`     | Adding or fixing tests (no production code change) |
| `refactor` | Code restructuring, no behavior change             |
| `chore`    | Maintenance, deps, config, tooling                 |
| `docs`     | Documentation only                                 |
| `style`    | Formatting, whitespace (no logic change)           |
| `perf`     | Performance improvement                            |
| `ci`       | CI/CD pipeline changes                             |
| `build`    | Build system or external dependency changes        |
| `revert`   | Reverting a previous commit                        |

## Scope

The module or area touched. Examples: `auth`, `api`, `profile`, `db`, `cart`, `config`.

Pick the most specific scope that describes the change. If the change spans multiple modules, use the primary one or omit the scope.

## Body

Optional. Use when the subject line alone doesn't explain the change. Wrap at 72 characters. Explain **what** changed and **why**, not how (the diff shows how).

## Footer

- **Ticket reference** (when known): `Refs: PROJ-123`
- **Breaking changes**: `BREAKING CHANGE: description of what breaks`

## Examples

```
feat(auth): add oauth2 login flow

Refs: PROJ-123
```

```
fix(cart): correct rounding on discount totals

Discount was calculated before tax, causing 1-cent discrepancy
on orders with percentage-based coupons.

Refs: DASH-456
```

```
test(profile): add integration tests for email update
```

```
refactor(api): extract rate limiter into middleware
```

```
chore: update eslint to v9
```

## Anti-Patterns

```
# Bad: past tense
feat(auth): added login flow

# Bad: uppercase
Fix(Cart): Correct rounding

# Bad: vague
fix: fix bug

# Bad: too long (exceeds 72 chars)
feat(auth): add oauth2 login flow with refresh tokens and session management and remember me

# Bad: period at end
feat(auth): add oauth2 login flow.

# Bad: no type
add oauth2 login flow

# Bad: missing imperative mood
feat(auth): adding oauth2 login flow
```
