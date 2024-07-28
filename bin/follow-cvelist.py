#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ------------------------------------------------------------------------------
# Follow changes (commits) in CVEProject / cvelistV5
#
# Usage: follow-cvelist.py [-h] [-i s] [-c N] [-a] [-v]
#
#  -h, --help          show this help message and exit
#  -i s, --interval s  pull interval in seconds
#  -c N, --commits N   amount of commits to include in the initial print
#  -o, --once          only the current tail; no active follow (default: False)
#  -a, --ansi          add ansi colors to the output (default: False)
#  -v, --verbose       show verbose information on git pull (default: False)
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
    signal.signal(signal.SIGTERM, interrupt_handler)

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
    try:
        print(f"{''.ljust(os.get_terminal_size()[0], '-')}", file=sys.stderr)
    except:
        print(f"{''.ljust(80, '-')}", file=sys.stderr)

    pull(args.verbose)
    history(args)
    if not args.once:
        monitor(args)


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


def history(args):
    """Prints CVE changes from the commit history, one commit at a time"""
    history = args.commits
    cursor = get_cursor(history)
    while history > 0:
        history -= 1
        new_cursor = get_cursor(history)
        if args.verbose:
            print(
                f"[{cursor} → {new_cursor}]",
                file=sys.stderr,
            )
        print_changes(new_cursor, cursor, colors=args.ansi)
        cursor = new_cursor
        check_interrupt()


def monitor(agrs):
    """Monitors new cvelistV5 commits and prints changed CVEs"""
    cursor = get_cursor()

    while True:
        for x in range(args.interval):
            check_interrupt()
            time.sleep(1)

        pull(args.verbose)
        new_cursor = get_cursor()

        if new_cursor != cursor:
            if args.verbose:
                print(
                    f"[{cursor} → {new_cursor}]",
                    file=sys.stderr,
                )
            print_changes(new_cursor, cursor, colors=args.ansi)
            cursor = new_cursor


def pull(verbose: bool = False):
    """Runs git pull"""
    if verbose:
        subprocess.call(["git", "pull"])
    else:
        subprocess.call(
            ["git", "pull"], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT
        )


def get_cursor(offset: int = 0) -> str:
    """Gets commit id at the offset from the current head"""
    result = subprocess.run(
        ["git", "rev-parse", "--verify", f"HEAD~{offset}"], stdout=subprocess.PIPE
    )
    return result.stdout.decode("utf-8").strip()


def print_changes(current_commit: str, past_commit: str, colors: bool = False):
    """Print summary of changed CVE"""
    lines = []
    try:
        if colors:
            # add extra width for invisible characters (ANSI codes)
            width = os.get_terminal_size()[0] + 21
        else:
            # substract one character to fit occasional wide characters like emojis
            width = os.get_terminal_size()[0] - 1
    except:
        width = False

    for file in changed_files(current_commit, past_commit):
        type = re.split(r"\t+", file.decode("utf-8").strip())[0]
        path = re.split(r"\t+", file.decode("utf-8").strip())[1]

        if type == "D":
            if colors:
                print(
                    f"{ansi('red')}Deleted: {Path(path).stem}{ansi('end')}",
                    file=sys.stderr,
                )
            else:
                print(f"Deleted: {Path(path).stem}", file=sys.stderr)
        else:
            try:
                current = json_at_commit(path, current_commit)
                modified = current["cveMetadata"]["dateUpdated"]
                modified = re.sub(r"\..*", "", modified)
                modified = re.sub(r"T", " ", modified)
                cve = current["cveMetadata"]["cveId"]
            except (KeyError, TypeError):
                print(
                    f"Unexpected structure in {current_commit}:{path}", file=sys.stderr
                )
                continue

            if type == "M":
                if colors:
                    cve = f"{ansi('bright_blue')}{cve}{ansi('end')}"
                try:
                    past = json_at_commit(path, past_commit)
                    past_cvss = cvss31score(past)
                except TypeError:
                    print(
                        f"Unexpected structure in {past_commit}:{path}", file=sys.stderr
                    )
                    past_cvss = "   "
            else:
                if colors:
                    cve = f"{ansi('bright_cyan')}{cve}{ansi('end')}"
                past_cvss = "   "

            current_cvss = cvss31score(current)

            if colors:
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
                if colors:
                    cvss = f"{past_cvss} {COLOR}→ {current_cvss}{END}"
                else:
                    cvss = f"{past_cvss} → {current_cvss}"
            else:
                if colors:
                    cvss = f"{COLOR}{current_cvss}{END}"
                else:
                    cvss = f"{current_cvss}"

            summary = re.sub(r"\n", " ", generate_summary(current))

            if colors:
                lines.append(
                    f"{modified.ljust(20)} {cve.ljust(26)} {cvss.ljust(21)} {summary}"
                )
            else:
                lines.append(
                    f"{modified.ljust(20)} {cve.ljust(15)} {cvss.ljust(10)} {summary}"
                )

    lines.sort()

    for line in lines:
        if width:
            print(line[:width])
        else:
            print(line)


def cvss31score(cve: dict) -> float:
    """Gets CVSS 3.1 Score. If CVSS score is present in both containers, take higher"""
    try:
        cvss_adp = cve["containers"]["adp"][0]["metrics"][0]["cvssV3_1"]["baseScore"]
    except:
        cvss_adp = 0.0
    try:
        cvss_cna = cve["containers"]["cna"]["metrics"][0]["cvssV3_1"]["baseScore"]
    except:
        cvss_cna = 0.0

    cvss = max(cvss_adp, cvss_cna)
    return float("%0.1f" % cvss)


def generate_summary(cve: dict) -> str:
    """Generates summary from title or description & affected vendor/product"""
    title = ""
    description = ""
    try:
        title = cve["containers"]["cna"]["title"]
    except:
        try:
            for description in cve["containers"]["cna"]["descriptions"]:
                if description["lang"] in ("en", "en-US", "en_US"):
                    description = description["value"]
                    title = ""
                    break
        except:
            try:
                # This is not a very good title, but a last resort.
                title = cve["containers"]["adp"][0]["title"]
            except:
                pass

    vendor = ""
    try:
        vendor = cve["containers"]["adp"][0]["affected"][0]["vendor"]
    except:
        try:
            if cve["containers"]["cna"]["affected"][0]["vendor"] != "n/a":
                vendor = cve["containers"]["cna"]["affected"][0]["vendor"]
        except:
            pass

    product = ""
    try:
        product = cve["containers"]["adp"][0]["affected"][0]["product"]
    except:
        try:
            if cve["containers"]["cna"]["affected"][0]["product"] != "n/a":
                product = cve["containers"]["cna"]["affected"][0]["product"]
        except:
            pass

    # Title is typically short and likely contains the vendor and product, whereas
    # description can tell a long story in any order. Therefore, we get the most
    # informative view when title comes before vendor:product but after description.
    if title == "":
        if vendor != "" or product != "":
            return f"[{vendor}: {product}] {description}"
        else:
            return description
    elif vendor != "" or product != "":
        return f"{title} [{vendor}: {product}]"
    else:
        return title


def changed_files(current_commit: str, past_commit: str) -> list:
    """List cve files changed between two commits; ignore delta files"""
    result = subprocess.Popen(
        [
            "git",
            "diff",
            "--name-status",
            past_commit,
            current_commit,
            "cves/",
            ":!cves/delta*",
        ],
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
        print(f"Could not open {commit}:{path}", file=sys.stderr)
    except json.decoder.JSONDecodeError:
        print(f"Could not parse {commit}:{path}", file=sys.stderr)


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
    """Convert color & optional style to ANSI code"""
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
    if color in ansi and style in sgr:
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
    argParser.add_argument(
        "-o",
        "--once",
        action="store_true",
        help="only the current tail; no active follow (default: False)",
        default=False,
    )
    argParser.add_argument(
        "-a",
        "--ansi",
        action="store_true",
        help="add ansi colors to the output",
        default=False,
    )
    argParser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="show verbose information on git pull",
        default=False,
    )
    args = argParser.parse_args()
    main(args)
