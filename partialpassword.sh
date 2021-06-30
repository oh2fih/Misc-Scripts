#!/bin/bash
# -----------------------------------------------------------
# Creates a new wordlist from a wordlist by replacing all
# ambiguous characters with all their possible combinations.
#
# Usage: partialpassword.sh input.txt output.txt O0 [Il1 ...]
#
# Using "-" as the input reads the passwords from stdin.
# Using "-" as the output prints the password list to stdout.
#
# Author : Esa Jokinen (oh2fih)
# -----------------------------------------------------------

if [ "$#" -lt 3 ]; then
  printf "\n%s\n" "Usage: $0 input.txt output.txt O0 [Il1 ...]"
  printf "\n%s\n" "Using \"-\" as the input reads the passwords from stdin."
  printf "%s\n" "Using \"-\" as the output prints the password list to stdout."
  exit 1
fi

if ! command -v sed &> /dev/null; then
  printf "\n%s\n" "This script requires sed!"
  exit 1
fi

if ! command -v awk &> /dev/null; then
  printf "\n%s\n" "This script requires awk!"
  exit 1
fi

if [ "$2" != "-" ]; then
  if [ -f "$2" ]; then
    printf "\n%s %s\n" "$2" "already exists."
    if [ "$1" != "-" ]; then
      read -p "Overwrite? (y/N) " answer
      if [ "${answer,,}" != "y" ]; then
        exit 1
      fi
    fi
  fi
fi

# Read file or stdin.
pwlist=$(< "$1") || exit 1

for alternatives in "${@:3}"; do

  # First, replace all other characters with the first one.
  for (( i=1; i<${#alternatives}; i++ )); do
    pwlist=$(printf "%s" "$pwlist" | sed 's/'${alternatives:$i:1}'/'${alternatives:0:1}'/g')
  done

  # Get max number of characters to be replaced.
  max=$(printf "%s" "$pwlist" | sed 's/[^'$alternatives']//g' | awk '{ print length }' | sort -n | tail -n 1)

  # Add new combinations.
  for (( i=1; i<${#alternatives}; i++ )); do
    for (( j=1; j<=$max; j++ )); do
      for (( k=$max; k>=j; k-- )); do
        new=$(printf "%s" "$pwlist" | sed "s/"${alternatives:0:1}"/"${alternatives:$i:1}/$k"")
        pwlist=$(printf "%s\n%s" "$pwlist" "$new" | sort -u)
      done
    done
  done

done

# Save the file or print the output to stdout.
if [ "$2" = "-" ]; then
  printf "%s" "$pwlist"
else
  printf "%s" "$pwlist" > $2 || exit 1
  printf "\n%s\n" "Done."
fi
