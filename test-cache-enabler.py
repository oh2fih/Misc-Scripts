#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# -----------------------------------------------------------
# Tests whether the Cache Enabler by KeyCDN (WordPress) is
# working properly on the URLs given as arguments.
#
# Usage: test-cache-enabler.py https://example.com [...]
#
# Also takes line break separated URLs from a pipe.
#
# Author : Esa Jokinen (oh2fih)
# -----------------------------------------------------------

import sys
import re
import os
import urllib.request
try:
    import validators
except ImportError:
    class validators:
        def url(url):
            return True

def main(urllist):
    '''Causes the pages to be cached, gets them and prints the results as a table.'''

    # Enable ANSI colors on Windows
    os.system("color")

    # Strip whitespace and adjust the output column to the longest URL.
    # Remove invalid URLs if optional 'validators' module is imported.
    maxlength = 2
    validurls = []
    for url in urllist:
        url = url.strip(' \n\r\t')
        if validators.url(url) and url != '':
            validurls.append(url)
            if len(url) > maxlength:
                maxlength = len(url)
        else:
            print("\033[91mInvalid URL: " + url + "\033[0m")
    if len(validurls) == 0:
        usage()

    print("\n\033[1m", end="")
    printResultLine("URL", "RESULT", maxlength, 1)
    for url in validurls:
        try:
            # Initial request to cause Cache Enabler to cache the page.
            with urllib.request.urlopen(url) as response:
                page = response.read()
            # Get the cached page for processing.
            with urllib.request.urlopen(url) as response:
                page = response.read()
                result = str(getCacheTime(page))
                if result == "Not cached.":
                    printResultLine(url, result, maxlength, 93)
                else:
                    printResultLine(url, result, maxlength, 92)
        except Exception as e:
            printResultLine(url, str(e), maxlength, 91)
    print()

def getCacheTime(page):
    '''Parses the cache time from the Cache Enabler comment on a HTML page.'''
    try:
        cached = re.search(b'<!-- Cache Enabler by KeyCDN (.*) -->', page).group(1)
        return cached.decode("utf-8")
    except:
        return "Not cached."

def printResultLine(url, result, urlmaxlenght, SGR=0):
    '''Prints table formatted result line & ANSI colors.'''
    width = urlmaxlenght + 2
    ansi = "\033[" + str(SGR) + "m"
    print("{u:<{w}}{a}{r:<10}\033[0m".format(u=url, r=result, w=width, a=ansi))

def usage():
    print("\nUsage: " + sys.argv[0] + " https://example.com [...]")
    print("\nAlso takes line break separated URLs from a pipe.\n")
    exit(1)

if __name__ == "__main__":
    urllist = []
    if len(sys.argv) == 1:
        if sys.stdin.isatty():
            usage()
    else:
        urllist.extend(sys.argv[1:])
    if not sys.stdin.isatty():
        for line in sys.stdin:
            urllist.append(line)
    main(urllist)
