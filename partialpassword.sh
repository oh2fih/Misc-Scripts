#!/bin/bash
# -----------------------------------------------------------
# Creates a new wordlist from a wordlist by replacing all
# ambiguous characters with all their possible combinations.
#
# Usage: partialpassword.sh input.txt output.txt O0 [Il1 ...]
#
# Using "--" as the output prints the list to stdout.
# -----------------------------------------------------------

if [ "$#" -lt 3 ]; then
  echo -e "\nUsage: $0 input.txt output.txt O0 [Il1 ...]\n"
  echo -e "Using \"--\" as the output prints the list to stdout.\n"
  exit 1
fi

if ! command -v sed &> /dev/null; then
  echo -e "\nThis script requires sed!\n"
  exit 1
fi

if ! command -v awk &> /dev/null; then
  echo -e "\nThis script requires awk!\n"
  exit 1
fi

if [ "$2" != "--" ]; then
  if [ -f "$2" ]; then
    echo -e "\n$2 already exists.\n"
    read -p "Overwrite? (y/N) " answer
    if [ "${answer,,}" != "y" ]; then
      exit 1
    fi
  fi
fi

pwlist=$(cat "$1") || exit 1

for alternatives in "${@:3}"; do

  # First, replace all other characters with the first one.
  for (( i=1; i<${#alternatives}; i++ )); do
    pwlist=$(echo -e "$pwlist" | sed 's/'${alternatives:$i:1}'/'${alternatives:0:1}'/g')
  done

  # Get max number of characters to be replaced.
  max=$(echo -e "$pwlist" | sed 's/[^'$alternatives']//g' | awk '{ print length }' | sort -n | tail -n 1)

  # Add new combinations.
  for (( i=1; i<${#alternatives}; i++ )); do
    for (( j=1; j<=$max; j++ )); do
      for (( k=$max; k>=j; k-- )); do
        new=$(echo -e "$pwlist" | sed "s/"${alternatives:0:1}"/"${alternatives:$i:1}/$k"")
        pwlist=$(echo -e "$pwlist\n$new" | sort -u | sed '/^$/d')
      done
    done
  done

done

# Save the file or print the output to stdout.
if [ "$2" = "--" ]; then
  echo -e "$pwlist"
else
  echo -e "$pwlist" > $2 || exit 1
  echo -e "\nDone.\n"
fi
