#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ------------------------------------------------------------------------------
# Follow changes (commits) in CVEProject / cvelistV5
#
# Usage: follow-cvelist.py [-h] [-i s] [-c N]
#
#  -h, --help          show this help message and exit
#  -i s, --interval s  pull interval in seconds
#  -c N, --commits N   amount of commits to include in the initial print
#
# Requires git. Working directory must be the root of the cvelistV5 repository.
#
# Author : Esa Jokinen (oh2fih)
# Home   : https://github.com/oh2fih/Misc-Scripts
# ------------------------------------------------------------------------------

import argparse, json, os, re, sys, signal, subprocess, time
from pathlib import Path

# Variable used for interruption handling
INTERRUPT = None


def main(args):
    # Handle keyboard interruptions
    signal.signal(signal.SIGINT, interrupt_handler)
    # Handle termination signals
    signal.signal(signal.SIGINT, interrupt_handler)

    try:
        subprocess.call(
            ["git", "version"], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT
        )
    except FileNotFoundError:
        print("This script requires git", file=sys.stderr)
        exit(1)

    if not cvelist_repo():
        print(
            f"Current directory is not the cvelistV5 repository root", file=sys.stderr
        )
        exit(1)

    # Header
    print(
        f"{'TIME (UTC)'.ljust(20)} {'CVE'.ljust(15)} "
        f"{'CVSS 3.1'.ljust(10)} SUMMARY [vendor: product]",
        file=sys.stderr,
    )
    print(f"{''.ljust(os.get_terminal_size()[0], '-')}", file=sys.stderr)

    monitor(get_cursor(args.commits), args.interval)


def interrupt_handler(signum, frame):
    """Tells that an interrupt signal is received through global variable INTERRUPT"""
    global INTERRUPT
    INTERRUPT = signum


def check_interrupt():
    """Exits if interrupt is received"""
    if INTERRUPT:
        print(
            f"Exiting after receiving {signal.Signals(INTERRUPT).name}...",
            file=sys.stderr,
        )
        sys.exit(0)


def monitor(cursor: str, interval: int):
    """Monitors cvelistV5 commits and prints changed CVEs"""
    while True:
        pull()
        new_cursor = get_cursor()

        if new_cursor != cursor:
            print_changes(new_cursor, cursor)

        cursor = new_cursor

        for x in range(interval):
            check_interrupt()
            time.sleep(1)


def pull():
    """Runs git pull"""
    subprocess.call(
        ["git", "pull"], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT
    )


def get_cursor(offset: int = 0) -> str:
    """Gets commit id at the offset from the current head"""
    result = subprocess.run(
        ["git", "rev-parse", "--verify", f"HEAD~{offset}"], stdout=subprocess.PIPE
    )
    return result.stdout.decode("utf-8").strip()


def print_changes(current_commit: str, past_commit: str):
    """Print summary of changed CVE"""
    lines = []

    # adjust screen width to the ansi colors in CVSS
    width = os.get_terminal_size()[0] + 21

    for file in changed_files(current_commit, past_commit):
        type = re.split(r"\t+", file.decode("utf-8").strip())[0]
        path = re.split(r"\t+", file.decode("utf-8").strip())[1]

        # Skip delta files
        if "delta" in path:
            continue

        if type == "D":
            print(
                f"{ansi('red')}Deleted: {Path(path).stem}{ansi('end')}", file=sys.stderr
            )
        else:
            current = json_at_commit(path, current_commit)
            modified = current["cveMetadata"]["dateUpdated"]
            modified = re.sub(r"\..*", "", modified)
            modified = re.sub(r"T", " ", modified)
            cve = current["cveMetadata"]["cveId"]

            if type == "M":
                cve = f"{ansi('bright_blue')}{cve}{ansi('end')}"
                past = json_at_commit(path, past_commit)
                past_cvss = cvss31score(past)
            else:
                cve = f"{ansi('bright_cyan')}{cve}{ansi('end')}"
                past_cvss = "   "

            current_cvss = cvss31score(current)

            END = ansi("end")
            if current_cvss >= 9.0:
                COLOR = ansi("bright_red", "bold")
            elif current_cvss >= 7.0:
                COLOR = ansi("red")
            elif current_cvss >= 4.0:
                COLOR = ansi("yellow")
            elif current_cvss >= 0.1:
                COLOR = ansi("green")
            else:
                COLOR = f"{END}\000\000\000"

            if current_cvss == 0.0:
                current_cvss = "   "
            if past_cvss == 0.0:
                past_cvss = "   "

            if current_cvss != past_cvss:
                cvss = f"{past_cvss} {COLOR}→ {current_cvss}{END}"
            else:
                cvss = f"{COLOR}{current_cvss}{END}"

            summary = re.sub(r"\n", " ", generate_summary(current))

            lines.append(
                f"{modified.ljust(20)} {cve.ljust(26)} {cvss.ljust(21)} {summary}"
            )

    lines.sort()

    for line in lines:
        print(line[:width])


def cvss31score(cve: dict) -> float:
    """Gets CVSS 3.1 Score"""
    try:
        cvss = cve["containers"]["adp"][0]["metrics"][0]["cvssV3_1"]["baseScore"]
    except:
        cvss = 0.0
    return float("%0.1f" % cvss)


def generate_summary(cve: dict) -> str:
    """Generates summary from title & affected product"""
    title = ""
    try:
        title = cve["containers"]["cna"]["title"]
    except:
        try:
            for description in cve["containers"]["cna"]["descriptions"]:
                if description["lang"] in ("en", "en-US", "en_US"):
                    title = description["value"]
                    break
        except:
            try:
                title = cve["containers"]["adp"][0]["title"]
            except:
                pass

    vendor = ""
    product = ""
    try:
        vendor = cve["containers"]["adp"][0]["affected"][0]["vendor"]
        product = cve["containers"]["adp"][0]["affected"][0]["product"]
    except:
        try:
            if cve["containers"]["cna"]["affected"][0]["vendor"] != "n/a":
                vendor = cve["containers"]["cna"]["affected"][0]["vendor"]
            if cve["containers"]["cna"]["affected"][0]["product"] != "n/a":
                product = cve["containers"]["cna"]["affected"][0]["product"]
        except:
            pass

    if title == "":
        return f"[{vendor}: {product}]"
    elif vendor != "" or product != "":
        return f"{title}[{vendor}: {product}]"
    else:
        return title


def changed_files(current_commit: str, past_commit: str) -> list:
    """List files changed between two commits"""
    result = subprocess.Popen(
        ["git", "diff", "--name-status", past_commit, current_commit],
        stdout=subprocess.PIPE,
    )
    return result.stdout.readlines()


def json_at_commit(path: Path, commit: str) -> dict:
    """Dictionary of JSON file contents at given commit"""
    try:
        result = subprocess.run(
            ["git", "show", f"{commit}:{path}"], stdout=subprocess.PIPE
        )
        data = json.loads(result.stdout.decode("utf-8"))
        return data
    except IOError:
        print(f"Could not open {path}", file=sys.stderr)


def cvelist_repo():
    """Detects whether the working directory is the root of CVEProject / cvelistV5"""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"], stdout=subprocess.PIPE
        )
        toplevel = Path(result.stdout.decode("utf-8").strip())
        working = Path(os.getcwd())

        if os.path.samefile(str(toplevel), str(working)):
            readmefile = open("README.md", "r")
            readme = readmefile.readlines()
            readmefile.close()
            for line in readme:
                if "# CVE List V5" in line:
                    return True

        return False
    except:
        return False


def ansi(color: str, style: str = "normal") -> str:
    """Convert color to ANSI code"""
    sgr = {
        "normal": 0,
        "bold": 1,
        "dim": 2,
        "italic": 3,
    }
    ansi = {
        "end": "\033[0m",
        "black": f"\033[{sgr[style]};30m",
        "red": f"\033[{sgr[style]};31m",
        "green": f"\033[{sgr[style]};32m",
        "yellow": f"\033[{sgr[style]};33m",
        "blue": f"\033[{sgr[style]};34m",
        "magenta": f"\033[{sgr[style]};35m",
        "cyan": f"\033[{sgr[style]};36m",
        "white": f"\033[{sgr[style]};37m",
        "gray": f"\033[{sgr[style]};90m",
        "bright_red": f"\033[{sgr[style]};91m",
        "bright_green": f"\033[{sgr[style]};92m",
        "bright_yellow": f"\033[{sgr[style]};93m",
        "bright_blue": f"\033[{sgr[style]};94m",
        "bright_magenta": f"\033[{sgr[style]};95m",
        "bright_cyan": f"\033[{sgr[style]};96m",
        "bright_white": f"\033[{sgr[style]};97m",
    }
    if color in ansi:
        return ansi[color.lower()]
    else:
        return ansi["end"]


def check_positive(value: int):
    ivalue = int(value)
    if ivalue <= 0:
        raise argparse.ArgumentTypeError(f"{value} is not a positive integer")
    return ivalue


if __name__ == "__main__":
    argParser = argparse.ArgumentParser(
        description="Follow changes (commits) in CVEProject / cvelistV5",
        epilog="Requires git. "
        "Working directory must be the root of cvelistV5 repository.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    argParser.add_argument(
        "-i",
        "--interval",
        type=check_positive,
        metavar="s",
        help="pull interval in seconds",
        default=150,
    )
    argParser.add_argument(
        "-c",
        "--commits",
        type=check_positive,
        metavar="N",
        help="amount of commits to include in the initial print",
        default=30,
    )
    args = argParser.parse_args()
    main(args)
