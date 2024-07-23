#!/bin/bash
read -r -d '' USAGE << EOM
# ------------------------------------------------------------------------------
# Search Git repository history for commits with SHA-256 checksum of a file
#
#   Answers the question "Has this version of this file ever been
#   committed as the file on this path of this Git repository?"
#   and shows a summary (git show --stat) of the matching commit(s).
#
# Usage: git-find-commits-by-file-hash.sh sha256sum path
#
# - The working directory should be inside a Git repository work tree.
# - The sha256sum should be an full sha256sum checksum of the file.
# - The path should be relative to the repository root.
#
# Author : Esa Jokinen (oh2fih)
# Home   : https://github.com/oh2fih/Misc-Scripts
# ------------------------------------------------------------------------------
EOM
if [ "$#" -lt 2 ]; then
  echo -e "\033[0;32m${USAGE}\033[0m" >&2
  exit 1
fi

if [[ ! "$1" =~ ^[a-f0-9]{64}$ ]]; then
  echo -e "\033[0;31mThe first argument is not a valid sha256sum!\033[0m" >&2
  exit 1
fi

# Check for requirements. Print all unmet requirements at once.

required_command() {
  if ! command -v "$1" &> /dev/null; then
    if [ -z ${2+x} ]; then
      echo -e "\033[0;31mThis script requires ${1}!\033[0m" >&2
    else
      echo -e "\033[0;31mThis script requires ${1} ${2}!\033[0m" >&2
    fi
    ((UNMET=UNMET+1))
  fi
}

UNMET=0

required_command "git" "for examining a git repository"
required_command "sha256sum" "for calculating the hashes"
required_command "awk"
required_command "grep"
required_command "xargs"

if [ "$UNMET" -gt 0 ]; then
  exit 1
fi

# Check whether this is a git repository & change to the repository root

git rev-parse --is-inside-work-tree &> /dev/null \
  || {
    echo -e "\033[0;31mNot inside a git repository!\033[0m" >&2
    exit 1
  }

cd "$(git rev-parse --show-toplevel)" \
  || {
    echo -e "\033[0;31mUnable to change to the repository root!\033[0m" >&2
    exit 1
  }

# Search for the hash & show stats of matching commits

print_commit_and_checksum() {
  while read -r commit; do
    echo "${commit}:$(
      git show "${commit}:${1}" 2> /dev/null \
        | sha256sum \
        | awk '{print $1}'
    )"
  done
}

matches=$(
  git log --oneline --no-abbrev-commit --follow -- "$2" \
    | awk '{print $1}' \
    | print_commit_and_checksum "$2" \
    | grep -E "[0-9a-f]*:${1}"
  )

if [[ "$matches" =~ [0-9a-f]+ ]]; then
  echo "$matches" \
    | awk -F: '{print $1}' \
    | xargs git show --stat
else
  echo -e "\033[0;31mHash not found in the commit history of $2!\033[0m" >&2
  exit 2
fi
