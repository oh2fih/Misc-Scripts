#!/bin/bash
read -r -d '' USAGE << EOM
# ------------------------------------------------------------------------------
# Compare product price on a web page with a given maximum price.
#
# Usage: product-pricelimiter.sh -u URL -s Selector [-m MaxPrice] [-n N] [-d N]
#
#   -u URL       web page URL to fetch the current price from
#   -s Selector  the HTML element containing the price; search the price from
#                elements or attributes that match a (CSS) selector (e.g.
#                h3, #id, .class or combinations like "#id div.class")
#   -m MaxPrice  maximum price used for comparison; float number
#   -n N         in case there are multiple floats in the element, choose Nth
#   -d 0..14     use 0..14 decimals in the currency; requires 'bc' (default: 2)
#
# Exit codes:
#
#   0  OK     Price is found and lower than or equal with the MaxPrice.
#   1  ERROR  An error has occured; unable to tell the result.
#   2  WAIT   Price is found but higher than the MaxPrice.
#
# Environment variables:
#
#   $USER_AGENT  Fake User-Agent for curl; defaults to Google Chrome.
#
# Requires html-xml-utils for parsing the HTML & curl for fetching the page.
# It is recommended to have 'bc' installed for more accurate comparison.
#
# Author : Esa Jokinen (oh2fih)
# Home   : https://github.com/oh2fih/Misc-Scripts
# ------------------------------------------------------------------------------
EOM

# Fake user-agent for curl

DEFAULT_UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
DEFAULT_UA+="(KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36"
UA="${USER_AGENT:-$DEFAULT_UA}"

# Validate arguments

n=1
d=2
INVALID=0

while getopts ":hu:s:m:n:d:" opt; do
  case ${opt} in
    h)
      # Allow -h for help; invalid or missing arguments prints the usage anyway.
      ;;
    u)
      producturl="$OPTARG"
      regex='http(s)?://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
      if ! [[ $producturl =~ $regex ]]; then
        echo -e "\033[0;31mThe argument for -u was not a valid URL!\033[0m" >&2
        echo -e "\033[0;31m(Expecting regex: ${regex} )\033[0m" >&2
        ((INVALID=INVALID+1))
      fi
      ;;
    s)
      selector="$OPTARG"
      ;;
    m)
      if [[ "$OPTARG" =~ ^[+-]?[0-9]+[\.,]?[0-9]*$ ]] 2>/dev/null; then
        maxprice=$(printf "%s" "$OPTARG" | sed 's/,/./g')
      else
        echo -e "\033[0;31mMaxPrice (-m) should be a (float) number!\033[0m" >&2
        ((INVALID=INVALID+1))
      fi
      ;;
    n)
      if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
        n="$OPTARG"
      else
        echo -e "\033[0;31mNth element (-n) should be an integer!\033[0m" >&2
        ((INVALID=INVALID+1))
      fi
      ;;
    d)
      if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
        d="$OPTARG"
      else
        echo -e "\033[0;31mDecimals (-d) should be an integer!\033[0m" >&2
        ((INVALID=INVALID+1))
      fi
      if (( d > 14)); then
        echo -e "\033[0;31mNo currency has >14 decimals (-d)!\033[0m" >&2
        ((INVALID=INVALID+1))
      fi
      if ! command -v bc &> /dev/null; then
        echo -e "\033[0;33mWarning! 'bc' is required for -d!\033[0m" >&2
      fi
      ;;
    \?)
      echo -e "\033[0;31mInvalid option: -${OPTARG}\033[0m" >&2
      ((INVALID=INVALID+1))
      ;;
    :)
      echo -e "\033[0;31mOption -${OPTARG} requires an argument\033[0m" >&2
      ((INVALID=INVALID+1))
      ;;
  esac
done

if [ -z "$producturl" ] || [ -z "$selector" ]; then
  echo -e "\033[0;31mMissing mandatory options (-u or -s)!\033[0m" >&2
  ((INVALID=INVALID+1))
fi

if [ "$INVALID" -gt 0 ]; then
  echo -e "\033[0;33m${USAGE}\033[0m" >&2
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
required_command "curl" "for fetching the web page"
required_command "grep" "for parsing float numbers from the page content"
required_command "sed" "for normalizing decimal separators"
required_command "head" "for picking the correct number as the price"
required_command "tail" "for picking the correct number as the price"
if ! command -v bc &> /dev/null; then
  required_command "sort" "or (recommended) bc for comparing float numbers"
fi

if [ "$UNMET" -gt 0 ] || [ "$INVALID" -gt 0 ]; then
  exit 1
fi

# Normalize the web page and get the monitored element

element_contents=$(
  curl -A "$UA" -s "$producturl" \
    | hxnormalize -x \
    | hxselect -c "$selector"
  )
if [ "$element_contents" == "" ]; then
  echo -ne "\033[0;31mFailed to fetch '${selector}' "
  echo -e "in ${producturl}\033[0m" >&2
  exit 1
fi

# Extract prices from the element & Nth price from the prices.

if (( d > 0)); then
  priceregex="(0|[1-9][0-9]*)([,\.][0-9]{1,${d}})?"
else
  priceregex="[0-9]+"
fi
prices=$(
  echo "$element_contents" \
    | grep -Eo "$priceregex" \
    | sed 's/,/./g' \
  )
if [ "$prices" == "" ]; then
  echo -ne "\033[0;31mPotential prices (float numbers, max ${d} " >&2
  echo -e "decimals) not found in '${selector}'!\033[0m" >&2
  exit 1
else
  echo -ne "\033[0;32mPotential prices (float numbers, max ${d} " >&2
  echo -e "decimals) in '${selector}':\033[0m" >&2
  export GREP_COLORS='ms=00;32'
  echo "$prices" | cat -n | grep --color=always -e "^" -e "\s${n}\s.*" >&2
fi

count=$(echo "$prices" | wc -l)
if (( n > count )); then
  echo -ne "\033[0;33mNot enough numbers (${n}); " >&2
  echo -e "using the last one (#${count}) for comparison!\033[0m" >&2
  n="$count"
fi

price=$(echo "$prices" | head -n "$n" | tail -n 1)
if command -v bc &> /dev/null; then
  price=$(echo "scale=${d}; ${price}/1" | bc | sed 's/^\./0./')
fi
echo -e "\033[0;32mThe price (#${n} in '${selector}') is now ${price}\033[0m"

# Compare (Nth or first) price with the limit.
# If installed, use bc for more accurate comparison.

if [ -n "$maxprice" ]; then
  if command -v bc &> /dev/null; then
    maxprice=$(echo "scale=${d}; ${maxprice}/1" | bc | sed 's/^\./0./')
    diff=$(
      echo "scale=${d}; (${maxprice} - ${price})/1" \
        | bc \
        | sed 's/-//' \
        | sed 's/^\./0./'
      )
    if (( $(echo "${maxprice} < ${price}" | bc -l) )); then
      isLowerOrEqual=0
      echo -ne "\033[0;33mMaximum price ${maxprice}; "
      echo -e "the price is ${diff} higher\033[0m"
    else
      isLowerOrEqual=1
      echo -ne "\033[0;32mMaximum price ${maxprice}; "
      echo -e "the price is ${diff} lower\033[0m"
    fi
  else
    echo -ne "\033[0;33mWarning! Install 'bc' for more accurate " >&2
    echo -e "comparison; using a fallback solution!\033[0m" >&2
    lower=$(printf "%s\n%s" "$price" "$maxprice" | sort -g | head -1)
    if [ "$lower" = "$price" ]; then
      isLowerOrEqual=1
      echo -ne "\033[0;32mThat is lower than (or equal to) "
      echo -e "the maximum price of ${maxprice}\033[0m"
    else
      isLowerOrEqual=0
      echo -ne "\033[0;33mThat is higher than "
      echo -e "the maximum price of ${maxprice}\033[0m"
    fi
  fi

  if [ "$maxprice" == "$price" ] || [ "$isLowerOrEqual" = 1 ]; then
    echo -e "\033[0;32mGood to buy!\033[0m"
    exit 0
  else
    echo -e "\033[0;33mPlease be patient!\033[0m"
    exit 2
  fi
fi
