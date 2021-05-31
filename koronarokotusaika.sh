#!/bin/bash
# -----------------------------------------------------------
# Checks from app.koronarokotusaika.fi whether people your
# age (without a risk group) are yet eligible for Covid-19
# vaccination or not. Requires curl and jq.
#
# Usage: koronarokotusaika.sh Municipality Age
# -----------------------------------------------------------

# Test the inputs...
if [ "$#" -ne 2 ]; then
  echo -e "\nUsage: $0 Municipality Age\n"
  exit 1
fi

if [ -n "$2" ] && [ "$2" -eq "$2" ] 2>/dev/null; then
  MUNICIPALITY=$1
  AGE=$2
else
  echo -e "\nAge should be a number!\n"
  exit 1
fi

# Tests for the requirements...
if ! command -v jq &> /dev/null; then
  echo -e "\nThis script requires jq!\n"
  exit 1
fi
if ! command -v curl &> /dev/null; then
  echo -e "\nThis script requires curl!\n"
  exit 1
fi

# Get the data for the municipality...
JSON=$(curl -s "https://api.koronarokotusaika.fi/api/options/municipalities/")
LABEL=$(echo "$JSON" | jq -c '.[] | select(.label=="'$MUNICIPALITY'")' )

if [ -z "$LABEL" ]; then
  echo -e "\nMunicipality $MUNICIPALITY not found!\n"
  exit 1
fi

# Check the non-risk groups based on the age...
ELIGIBLE_SINCE=$(echo "$LABEL" | jq -c '.vaccinationGroups[] | select((.min<='$AGE') and (.max>='$AGE' or .max==null) and (.conditionTextKey==null) and (.startDate!=null)) | "\(.startDate) (ages \(.min)-\(.max), source \(.source))"' )
CURRENT_TIME=$(date --iso-8601=seconds)
echo -e "\n[$CURRENT_TIME]"

if [ -z "$ELIGIBLE_SINCE" ]; then
  echo -e "\nSorry, but you are not yet eligible for Covid-19 vaccination! :(\n"
  exit 0
else
  echo -e "\nCongratulations! You have been eligible for Covid-19 vaccination since:"
  echo -e "$ELIGIBLE_SINCE\n"
  exit 0
fi
