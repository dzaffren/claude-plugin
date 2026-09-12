#!/usr/bin/env bash
# Install zuko when the container has never seen it.
#
# Web and mobile sessions get a fresh container every time, and the plugin
# cache under ~/.claude/plugins/ does not survive one. The committed
# enabledPlugins entry says what to enable but never fetches a plugin that
# was never installed, so without this the workflow is absent on mobile.
#
# Installs at 'local' scope so the absolute path the CLI writes lands in
# .claude/settings.local.json (gitignored), never in the committed file.
# Always exits 0: a failure here must not block the session.
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
command -v claude >/dev/null 2>&1 || exit 0

if claude plugin list 2>/dev/null | grep -q 'zuko@dzafran-claude-plugins'; then
  exit 0
fi

claude plugin marketplace add ./ --scope local >/dev/null 2>&1
claude plugin install zuko@dzafran-claude-plugins --scope local -y >/dev/null 2>&1

if claude plugin list 2>/dev/null | grep -q 'zuko@dzafran-claude-plugins'; then
  echo "zuko installed for this container." >&2
else
  echo "zuko bootstrap failed; run 'claude plugin install zuko@dzafran-claude-plugins'." >&2
fi
exit 0
