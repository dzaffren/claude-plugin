# Sourced, not run. The files that define a project's design system tokens.
# check-design-drift.sh and check-rendered-drift.sh both read this one list,
# so the two gates never disagree about what the design system is.

find_token_files() {   # find_token_files <project-dir>: one path per line, at most 20
  find "$1" \
    -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' -not -path '*/build/*' \
    \( -name 'tokens*.css' -o -name 'theme.css' -o -name 'globals.css' -o -name 'tailwind.config.*' -o -name 'components.json' \) \
    2>/dev/null | head -20
}
