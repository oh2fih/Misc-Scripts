#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# -----------------------------------------------------------
# Tests whether the Cache Enabler by KeyCDN (WordPress) is
# working properly on the URLs given as arguments.
#
# Usage: test-cache-enabler.py https://example.com [...]
#
# Author : Esa Jokinen (oh2fih)
# -----------------------------------------------------------

import sys
import re
import urllib.request
try:
    import validators
except ImportError:
    class validators:
        def url(url):
            return True

def main(urllist):
    '''Causes the pages to be cached, gets them and prints the results as a table.'''

    # Adjust the output column to the longest URL.
    # Remove invalid URLs if optional 'validators' library is imported.
    maxlength = 0
    for url in urllist:
        if validators.url(url):
            if len(url) > maxlength:
                maxlength = len(url)
        else:
            urllist.remove(url)
            print("\033[91mInvalid URL: " + url + "\033[0m\n")
    if len(urllist) == 0:
        usage()

    print ("\033[1m{:<{width}} {:<10}\033[0m".format("URL", "RESULT", width=maxlength+2))
    for url in urllist:
        try:
            # Initial request to cause Cache Enabler to cache the page.
            with urllib.request.urlopen(url) as response:
                page = response.read()
            # Get the cached page for processing.
            with urllib.request.urlopen(url) as response:
                page = response.read()
                print ("{:<{width}} {:<10}".format(url, str(getCacheTime(page)), width=maxlength+2))
        except Exception as e:
            print ("{:<{width}} \033[91m{:<10}\033[0m".format(url, str(e), width=maxlength+2))

def getCacheTime(page):
    '''Parses the cache time from the Cache Enabler comment on a HTML page.'''
    try:
        cached = re.search(b'<!-- Cache Enabler by KeyCDN (.*) -->', page).group(1)
        return ('\033[92m' + cached.decode("utf-8") + '\033[0m')
    except:
        return "\033[93mNot cached.\033[0m"

def usage():
    print("Usage: " + sys.argv[0] + " https://example.com [...]")
    exit(1)

if __name__ == "__main__":
    if len(sys.argv) == 1:
        usage()
    main(sys.argv[1:])
