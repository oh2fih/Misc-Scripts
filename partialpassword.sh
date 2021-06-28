#!/bin/bash
# -----------------------------------------------------------
# Creates a new wordlist from a wordlist by replacing all
# ambigous characters with all their possible combinations.
#
# Usage: partialpassword.sh input.txt output.txt O0 [Il1 ...]
# -----------------------------------------------------------

if [ "$#" -lt 3 ]; then
  echo -e "\nUsage: $0 input.txt output.txt O0 [Il1 ...]\n"
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

cp $1 $2 || { echo -e '\nCannot write output to '$2'\n' ; exit 1; }

for alternatives in "${@:3}"; do

  # First, replace all other characters with the first one.
  for (( i=1; i<${#alternatives}; i++ )); do
    sed -i 's/'${alternatives:$i:1}'/'${alternatives:0:1}'/g' $2
  done

  # Get max number of characters to be replaced.
  max=$(sed 's/[^'$alternatives']//g' $1 | awk '{ print length }' | sort -n | tail -n 1)

  # Add new combinations to the file.
  for (( i=1; i<${#alternatives}; i++ )); do
    for (( j=1; j<=$max; j++ )); do
      for (( k=$max; k>=j; k-- )); do
        new=$(sed "s/"${alternatives:0:1}"/"${alternatives:$i:1}/$k"" $2)
        echo -e "$new" >> $2
        uniq=$(cat $2 | sort -u)
        echo -e "$uniq" > $2
      done
    done
  done

done
