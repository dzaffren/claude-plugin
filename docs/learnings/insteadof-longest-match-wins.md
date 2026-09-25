# A test's insteadOf must name the full remote URL

**Learned:** 2026-09-25 · **From:** release build

The release e2e needs an `origin` that reads `https://github.com/acme/invoice-cli.git`
but pushes into a local bare repo. That is `url.<bare>.insteadOf`. This laptop's
global git config already rewrites `https://github.com/` to `git@github.com:`, so
a test rule on a shorter prefix would lose and the push would try real GitHub.

## The rule

Write the test's `insteadOf` as the whole remote URL, in the repo's local config.
git applies the longest matching prefix, so the full URL beats any global rewrite
of the host. Never rely on the machine having no `url.*` rules.
