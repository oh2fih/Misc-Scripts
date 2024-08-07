#!/bin/bash
read -r -d '' USAGE << EOM
# ------------------------------------------------------------------------------
# Compare product price on a web page with a given maximum price.
#
# Usage: product-pricelimiter.sh ProductURL Element MaxPrice [N]
#
#   ProductURL  web page URL to fetch the current price from
#   Element     the HTML element containing the price (#id or .class)
#   MaxPrice    float number
#   N           in case there are multiple floats in the element, choose Nth
#
# Exit codes:
#
#   0  OK     Price is found and lower than or equal with the MaxPrice.
#   1  ERROR  An error has occured; unable to tell the result.
#   2  WAIT   Price is found but higher than the MaxPrice.
#
# Author : Esa Jokinen (oh2fih)
# Home   : https://github.com/oh2fih/Misc-Scripts
# ------------------------------------------------------------------------------
EOM

# Fake user-agent for curl

UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
UA+="(KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"

# Test the inputs...

if [ "$#" -lt 3 ]; then
  echo -e "\033[0;33m${USAGE}\033[0m" >&2
  exit 1
fi

if [[ "$3" =~ ^[+-]?[0-9]+[\.,]?[0-9]*$ ]] 2>/dev/null; then
  producturl="$1"
  selector="$2"
  maxprice=$(printf "%s" "$3" | sed 's/,/./g')
else
  echo -e "\033[0;31mMax price should be a (float) number!\033[0m" >&2
  exit 1
fi

if [ "$#" -ge 4 ]; then
  if [[ "$4" =~ ^[0-9]+$ ]] ; then
    n="$4"
  else
    echo -e "\033[0;31mN should be an integer!\033[0m" >&2
    exit 1
  fi
else
  n=1
fi

# Validate the URL

regex='(https?)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
if ! [[ $producturl =~ $regex ]]; then
  echo -e "\033[0;31mThe first argument was not a valid URL!\033[0m" >&2
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

required_command "hxselect" "; Please install html-xml-utils"
required_command "hxnormalize" "; Please install html-xml-utils"
required_command "grep" "for parsing the page content"
required_command "sed" "for converting delimiters"
required_command "curl" "for fetching the web page"
required_command "sort" "for comparing float numbers"
required_command "head" "for comparing float numbers"

if [ "$UNMET" -gt 0 ]; then
  exit 1
fi

# Normalize the web page and get the monitored element

element_contents=$(
  curl -A "$UA" -s "$producturl" \
    | hxnormalize -x \
    | hxselect -c "$selector"
  )
if [ "$element_contents" == "" ]; then
  echo -e "\033[0;31mFailed to fetch \"$selector\" in ${producturl}\033[0m" >&2
  exit 1
fi

# Extract prices from the element and compare Nth or first with the limit

prices=$(
  echo "$element_contents" \
    | grep -Eo '[0-9]+([,\.][0-9]{0,2})?' \
    | sed 's/,/./g' \
  )
if [ "$prices" == "" ]; then
  echo -e "\033[0;31mPrices not found from \"$selector\"!\033[0m" >&2
  exit 1
else
  echo -e "\033[0;32mPrices (float numbers) in \"$selector\":\033[0m" >&2
  echo "$prices" | cat -n | grep --color=always -e "^" -e "\s$n\s.*" >&2 
fi

count=$(echo "$prices" | wc -l)
if (( n > count )); then
  echo -ne "\033[0;33mNot enough numbers ($n); "
  echo -e "using the last one (#$count) for comparison!\033[0m" >&2
  n="$count"
fi
price=$(
  echo "$prices" \
    | head -n "$n" \
    | tail -n 1
  )

lower=$(printf "%s\n%s" "$price" "$maxprice" | sort -g | head -1)

if [ "$lower" = "$price" ]; then
    echo -ne "\033[0;32mGood to buy! "
    echo -e "The price (#$n in \"$selector\") is now $price €\033[0m"
    exit 0
else
    echo -ne "\033[0;33mPlease be patient! "
    echo -e "The price (#$n in \"$selector\") is still $price €\033[0m"
    exit 2
fi
