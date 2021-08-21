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
import validators

def main(urllist):
    '''Causes the pages to be cached, gets them and prints the results as a table.'''

    # Initial requests to cause Cache Enabler to cache the pages.
    print ("Performing the initial request to cause uncached URLs to be cached...\n")
    for url in urllist:
        if validators.url(url):
            try:
                with urllib.request.urlopen(url) as response:
                    page = response.read()
            except:
                pass

    # Get the pages again to check the status.
    print ("{:<40} {:<40}".format("URL", "RESULT"))
    for url in urllist:
        if validators.url(url):
            try:
                with urllib.request.urlopen(url) as response:
                    page = response.read()
                    print ("{:<40} {:<40}".format(url, str(getCacheTime(page))))
            except Exception as e:
                print ("{:<40} {:<40}".format(url, str(e)))

def getCacheTime(page):
    '''Parses the cache time from the Cache Enabler comment on a HTML page.'''
    try:
        cached = re.search(b'<!-- Cache Enabler by KeyCDN (.*) -->', page).group(1)
        return cached.decode("utf-8")
    except:
        return "Not cached."

if __name__ == "__main__":
    if len(sys.argv) == 1:
        print("Usage: test-cache-enabler.py https://example.com [...]")
        exit(1)
    main(sys.argv[1:])
