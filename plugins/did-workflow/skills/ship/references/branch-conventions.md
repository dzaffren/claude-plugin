# Branch Naming Conventions

## Protected Branches

**NEVER** commit directly to these branches:

- `main`
- `master`
- `develop`

If you are on a protected branch with uncommitted changes, you **must** create a new branch first.

## Branch Prefixes

Prefixes are aligned to conventional commit types, with one exception: `feature/` keeps its full form for readability.

| Prefix      | When to Use                            | Commit Type |
| ----------- | -------------------------------------- | ----------- |
| `feature/`  | New functionality                      | `feat`      |
| `fix/`      | Bug fixes                              | `fix`       |
| `chore/`    | Maintenance, dependencies, config      | `chore`     |
| `refactor/` | Code restructuring, no behavior change | `refactor`  |
| `docs/`     | Documentation only                     | `docs`      |
| `test/`     | Adding or fixing tests only            | `test`      |

## Naming Format

```
{prefix}{ticket-id}-{description}
{prefix}{description}
```

- **Ticket ID** (optional): uppercase project key + hyphen + number (e.g., `PROJ-123`)
- **Description**: kebab-case, lowercase, 2-5 words, descriptive of the change

## Rules

- All lowercase
- Kebab-case (hyphens, no underscores or spaces)
- Max ~60 characters total
- Description should be meaningful — someone reading the branch name should understand the intent

## Examples

```
feature/PROJ-123-add-user-auth
feature/add-notification-service
fix/null-pointer-on-login
fix/DASH-456-cart-total-rounding
chore/update-dependencies
refactor/extract-payment-module
docs/update-api-reference
test/add-checkout-integration-tests
```

## Anti-Patterns

```
# Bad: camelCase
feature/addUserAuth

# Bad: too vague
fix/bug

# Bad: too long
feature/PROJ-123-add-user-authentication-with-oauth2-and-refresh-tokens-and-session-management

# Bad: no prefix
add-user-auth

# Bad: spaces or underscores
feature/add_user_auth
feature/add user auth

# Bad: committing directly to protected branch
main  ← never commit here directly
```
