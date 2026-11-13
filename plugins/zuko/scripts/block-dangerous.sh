#!/usr/bin/env bash
# PreToolUse[Bash] hook: block destructive git/file commands.
set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | python3 -I -c 'import json,sys; [s.reconfigure(encoding="utf-8", errors="surrogateescape", newline="\n") for s in (sys.stdin, sys.stdout)]; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null) || { printf '%s\n' "Blocked: could not read the hook payload, so this command was not checked." "Run it again without unusual characters." >&2; exit 2; }
[ -z "$cmd" ] && exit 0

# Where the command starts: the hook's cwd, which follows the session's cd.
base=$(printf '%s' "$input" | python3 -I -c 'import json,sys; [s.reconfigure(encoding="utf-8", errors="surrogateescape", newline="\n") for s in (sys.stdin, sys.stdout)]; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)
project="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -n "$base" ] || base="$project"

deny() { echo "$1" >&2; exit 2; }

# What git is actually being asked to do, one invocation per line, so a command
# that only mentions "git commit" in a quoted argument, a heredoc body or a
# comment is not mistaken for one.
#
# A push forces with --force and its -with-lease form, with -f alone or bundled
# (-uf), with --mirror or any prefix of it (git takes --mi), and with a refspec
# that starts with +. A brace or glob is expanded by the shell before git runs,
# so the words read here are not the words git gets.
#
# A command the parser cannot read is blocked (D52): bash runs the lines before
# an unclosed quote, and an unclosed heredoc to the end of the text. So is a
# command over its 64 KB limit, exit 4 (D51). A check of the raw text instead
# missed `git -C . push --force` and `git -C . commit`. secret-scan.sh and
# block-attribution.sh still fall back to the raw text; this hook runs on every
# Bash call, so its block covers theirs. The parser writes to stderr only when
# it fails, and then its last ": " part is the reason.
git_args=$(printf '%s' "$cmd" | python3 "$(dirname "${BASH_SOURCE[0]}")/lib/git-command.py" --base "$base" 2>&1)
parsed=$?
[ "$parsed" -eq 4 ] && deny "Blocked: this command is over 65536 characters, too long to check. Put the long text in a heredoc or a file, then run it again."
[ "$parsed" -ne 0 ] && deny "Blocked: this command could not be checked: ${git_args##*: }. bash runs the lines before a broken quote or heredoc. Close it, or put the text in a file, then run it again."
push_re='^push( .*)? (--force[^[:space:]]*|--m[^[:space:]]*|-[^-[:space:]]*f[^[:space:]]*|\+[^[:space:]]*)([[:space:]]|$)'
expand_re='^push( .*)? [^[:space:]]*[][{}*?]'
# Each subcommand that makes a commit on the branch it runs on (shape O4).
commit_re='^(commit|merge|cherry-pick|rebase|pull|revert|am)([[:space:]]|$)'

if grep -qE "$push_re" <<<"$git_args"; then
  deny "Blocked: force push rewrites shared history. Ask the user first."
fi

if grep -qE "$expand_re" <<<"$git_args"; then
  deny "Blocked: this push has a brace or glob character, which the shell can expand into a force flag. Write the arguments out in full, or ask the user first."
fi

# A push deletes a branch on the remote with a :name refspec, or with each
# name after --delete, -d bundled or any prefix of --delete (git takes --de).
# --prune deletes each remote branch that has no local one. Only main and
# master are judged (D30), and a name the text cannot show can be either.
deletes_main() {   # deletes_main <push call>
  local word words name deleting=
  read -r -a words <<<"$1"
  for word in "${words[@]:1}"; do
    case "$word" in
      --de*) deleting=1 ;;
      --pru*) return 0 ;;
      --*) ;;
      -*d*) deleting=1 ;;
    esac
  done
  for word in "${words[@]:1}"; do
    case "$word" in
      -*) continue ;;
      :?*) name=${word#:} ;;
      *) [ -n "$deleting" ] || continue; name=$word ;;
    esac
    case "${name##*/}" in main|master) return 0 ;; esac
    case "$name" in *[\$\`]*) return 0 ;; esac
  done
  return 1
}

while IFS= read -r call; do
  case "$call" in push|push\ *)
    deletes_main "$call" && deny "Blocked: this push can delete main or master on the remote. Ask the user first." ;;
  esac
done <<<"$git_args"

if grep -qE '(^|[;&|[:space:]])rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)[[:space:]]+(/([[:space:]]|$)|/[a-z]+([[:space:]]|$)|~|\.\.)' <<<"$cmd"; then
  deny "Blocked: recursive delete of a top-level or home path."
fi

# The same rule on the parsed rm calls, so quotes, $HOME, a glob, a split or
# long flag and a nested command count (D158). The regex above stays, so no
# form that it blocks starts to pass (D159). A command with no rm word runs no
# rm, and starts no second parse.
if grep -qiwE 'rm(\.exe)?' <<<"$cmd"; then
  rm_path=$(printf '%s' "$cmd" | python3 "$(dirname "${BASH_SOURCE[0]}")/lib/git-command.py" --base "$base" --rm 2>&1)
  case $? in
    0) ;;
    1) deny "Blocked: recursive delete of a top-level or home path." ;;
    *) deny "Blocked: this command could not be checked: ${rm_path##*: }. bash runs the lines before a broken quote or heredoc. Close it, or put the text in a file, then run it again." ;;
  esac
fi

# A call that cannot make a commit: a merge or pull with --ff-only, which git
# 2.52.0 refuses to turn into a merge or a rebase, or an --abort or --quit for
# the others. The line has lost its quotes, so `-m "a --ff-only"` reads as
# --ff-only: each option must be on the list, and each other word must be a
# plain name or a redirection, with no $, quote, glob or comma. bash can also
# give git words the line does not show: from a backtick that ends the call, or
# from xargs or another program that runs git. A command where that happens
# allows nothing.
no_new_commit() {   # no_new_commit <git call>
  local word words sub allowed=
  read -r -a words <<<"$1"
  sub=${words[0]}
  [ "$sub" = commit ] && return 1
  for word in "${words[@]:1}"; do
    case "$word" in
      --ff-only) case "$sub" in merge|pull) allowed=1 ;; *) return 1 ;; esac ;;
      --abort|--quit) [ "$sub" = pull ] && return 1; allowed=1 ;;
      -q|--quiet|-v|--verbose) ;;
      -*) return 1 ;;
      *[!A-Za-z0-9._/@{}^~:-]*)
        case "$word" in *[!\<\>\&]*) return 1 ;; esac ;;
    esac
  done
  [ -n "$allowed" ] || return 1
  printf '%s' "$cmd" | python3 "$(dirname "${BASH_SOURCE[0]}")/lib/git-command.py" --hidden-words >/dev/null 2>&1
}

on_main_why() {   # on_main_why <git call> <branch>
  local sub=${1%% *}
  case "$sub" in
    commit) echo "Blocked: committing directly on $2. Create a branch first." ;;
    merge|pull) echo "Blocked: git $sub can make a commit on $2. Create a branch first, or run git $sub --ff-only." ;;
    *) echo "Blocked: git $sub makes commits on $2. Create a branch first." ;;
  esac
}

# A rebase leaves HEAD detached while it runs, and its --continue moves the
# branch it started on, which git keeps in head-name.
rebase_branch() {   # rebase_branch <dir>
  local name file
  for name in rebase-merge rebase-apply; do
    file=$(git -C "$1" rev-parse --path-format=absolute --git-path "$name/head-name" 2>/dev/null) || continue
    [ -f "$file" ] && { sed 's|^refs/heads/||' "$file"; return; }
  done
}

# A checkout or switch moves HEAD before the next call runs. Prints main or
# master when HEAD can end on it: the new branch of a create option, or else a
# word that is not an option. A target the text cannot show can be main too.
# A checkout with a path after -- and no create option restores paths and
# moves nothing; after a switch's --, each word is a name. Each subcommand has
# its own create options, and git refuses the other's.
# Exit 2 when a create option moves HEAD to a branch that is not main: only
# then is HEAD off main for sure, because a plain name can be a path.
may_reach_main() {   # may_reach_main <checkout or switch call>
  local words word rest pre i sub=${1%% *} create= paths= letters=bB
  local -a names=()
  [ "$sub" = switch ] && letters=cC
  read -r -a words <<<"$1"
  for ((i = 1; i < ${#words[@]}; i++)); do
    word=${words[i]}
    case "$word" in
      --)
        if [ "$sub" = switch ]; then names+=("${words[@]:i+1}")
        elif [ $((i + 1)) -lt ${#words[@]} ]; then paths=1
        fi
        break ;;
      --detach) return 1 ;;
      --orphan) i=$((i + 1)); create=${words[i]-} ;;
      --orphan=*) create=${word#*=} ;;
      --create|--force-create)
        [ "$sub" = switch ] && { i=$((i + 1)); create=${words[i]-}; } ;;
      --create=*|--force-create=*) [ "$sub" = switch ] && create=${word#*=} ;;
      --*) ;;
      -?*)
        rest=${word#-}
        pre=${rest%%[$letters]*}
        [ "$sub" = switch ] && case "$pre" in *d*) return 1 ;; esac
        if [ "$pre" != "$rest" ]; then
          create=${rest:${#pre}+1}
          [ -n "$create" ] || { i=$((i + 1)); create=${words[i]-}; }
        fi ;;
      *) names+=("$word") ;;
    esac
  done
  if [ -n "$create" ]; then
    case "${create##*/}" in main|master) echo "${create##*/}"; return 0 ;; esac
    case "$create" in *[\$\`*?[{]*) echo main; return 0 ;; esac
    return 2
  elif [ -n "$paths" ] && [ "$sub" = checkout ]; then return 1
  fi
  for word in ${names[@]+"${names[@]}"}; do
    case "${word##*/}" in main|master) echo "${word##*/}"; return 0 ;; esac
    case "$word" in -|@\{-*|*[\$\`*?[{]*) echo main; return 0 ;; esac
  done
  return 1
}

# release-ok: the commit's own directory is known, so it may be the release
# commit release.py cut prepared, the one commit allowed on main (D30). A
# branch, when given, is judged in place of the directory's own.
deny_commit_on_main() {   # deny_commit_on_main <dir> <git call> [release-ok] [branch]
  local branch out
  branch=${4:-$(git -C "$1" symbolic-ref --short HEAD 2>/dev/null || rebase_branch "$1")}
  case "$branch" in
    main|master)
      if [ "${3:-}" = release-ok ] && [ "${2%% *}" = commit ]; then
        out=$(printf '%s' "$cmd" | python3 "$(dirname "${BASH_SOURCE[0]}")/lib/release-commit.py" "$1" 2>/dev/null)
        case $? in
          0) return 0 ;;
          1) deny "Blocked: committing directly on $branch. $out" ;;
          4) ;;
          *) deny "Blocked: committing directly on $branch. A release commit needs the marker
release.py cut writes; run /release." ;;
        esac
      fi
      deny "$(on_main_why "$2" "$branch")" ;;
  esac
}

# A commit lands on the branch of the directory it runs in: the start moved by
# a cd before it and by git's -C. A directory the parser cannot know comes back
# empty, and then the start, the project dir and each directory the command
# names are checked, as the start and the project dir are for every commit in
# a command that will not parse — never looser than the project dir alone.
deny_commit_anywhere() {   # deny_commit_anywhere <git call> [candidates]
  local dir
  deny_commit_on_main "$base" "$1"
  deny_commit_on_main "$project" "$1"
  [ "${2:-}" = candidates ] || return 0
  if [ -z "${candidates+set}" ]; then
    candidates=$(printf '%s' "$cmd" | python3 "$(dirname "${BASH_SOURCE[0]}")/lib/git-command.py" --candidate-dirs "$base" 2>&1) \
      || deny "Blocked: this command could not be checked: ${candidates##*: }."
  fi
  while IFS= read -r dir; do
    [ -n "$dir" ] && deny_commit_on_main "$dir" "$1"
  done <<<"$candidates"
}

if grep -qE "$commit_re" <<<"$git_args"; then
  if dirs=$(printf '%s' "$cmd" | python3 "$(dirname "${BASH_SOURCE[0]}")/lib/git-command.py" --dir "$base" 2>/dev/null); then
    # Split on the first tab by hand: read with IFS=tab strips a leading one,
    # and an empty directory would shift the arguments into it. A checkout or
    # switch to main makes each later call count as on main, until a switch
    # that creates another branch.
    switched=
    unset candidates
    while IFS= read -r line; do
      dir=${line%%$'\t'*}
      call=${line#*$'\t'}
      case "$call" in checkout|checkout\ *|switch|switch\ *)
        if reached=$(may_reach_main "$call"); then switched=$reached
        elif [ $? -eq 2 ]; then switched=
        fi ;;
      esac
      grep -qE "$commit_re" <<<"$call" || continue
      no_new_commit "$call" && continue
      [ -n "$switched" ] && deny_commit_on_main "${dir:-$base}" "$call" "${dir:+release-ok}" "$switched"
      if [ -n "$dir" ]; then deny_commit_on_main "$dir" "$call" release-ok; else deny_commit_anywhere "$call" candidates; fi
    done <<<"$dirs"
  else
    while IFS= read -r call; do
      grep -qE "$commit_re" <<<"$call" || continue
      no_new_commit "$call" || deny_commit_anywhere "$call"
    done <<<"$git_args"
  fi
fi

exit 0
