#!/usr/bin/env bash
# Render the README's zuko block from OVERVIEW.md.
# Usage: render-readme-block.sh [--write|--check]   -- see lib/readme_block.py
set -uo pipefail

exec python3 "$(dirname "${BASH_SOURCE[0]}")/lib/readme_block.py" "${CLAUDE_PROJECT_DIR:-$PWD}" "$@"
