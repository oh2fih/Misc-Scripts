#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ------------------------------------------------------------------------------
# Follow changes (commits) in CVEProject / cvelistV5
#
# Usage: follow-cvelist.py [-haouv4] [-i s] [-c N]
#
#  -h, --help          show this help message and exit
#  -a, --ansi          add ansi colors to the output (default: False)
#  -o, --once          only the current tail; no active follow (default: False)
#  -u, --url           prefix cve with url to nvd nist details (default: False)
#  -v, --verbose       show verbose information on git pull (default: False)
#  -4, --cvss4         show cvss 4.0 score instead of cvss 3.1 (default: False)
#  -i s, --interval s  pull interval in seconds (default: 150)
#  -c N, --commits N   number of commits to print initially (default: 30)
#
# Requires git. Working directory must be the root of the cvelistV5 repository.
#
# Change prefix for --url mode with environment variable CVE_URL_PREFIX.
#
# Author : Esa Jokinen (oh2fih)
# Home   : https://github.com/oh2fih/Misc-Scripts
# ------------------------------------------------------------------------------

import argparse
import json
import os
import re
import sys
import signal
import subprocess
import time
from pathlib import Path


def main(args: argparse.Namespace):
    cvelist = CvelistFollower(args)
    cvelist.header()
    cvelist.pull()
    cvelist.history()
    if not args.once:
        cvelist.monitor()


class CvelistFollower:
    """Follows changes (commits) in CVEProject / cvelistV5"""

    def __init__(self, args: argparse.Namespace):
        self.args = args
        self.INTERRUPT = None

        # URL prefix for --url mode
        self.URL_PREFIX = os.environ.get(
            "CVE_URL_PREFIX", "https://nvd.nist.gov/vuln/detail/"
        )

        # Handle keyboard interruptions
        signal.signal(signal.SIGINT, self.interrupt_handler)
        # Handle termination signals
        signal.signal(signal.SIGTERM, self.interrupt_handler)

        try:
            subprocess.call(
                ["git", "version"], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT
            )
        except FileNotFoundError:
            print("This script requires git", file=sys.stderr)
            exit(1)

        if not self.cvelist_repo():
            print(
                "Current directory is not the cvelistV5 repository root",
                file=sys.stderr,
            )
            exit(1)

    def interrupt_handler(self, signum, frame):
        """Tells that an interrupt signal is received through variable INTERRUPT"""
        self.INTERRUPT = signum

    def check_interrupt(self):
        """Exits if interrupt is received"""
        if self.INTERRUPT:
            print(
                f"Exiting after receiving {signal.Signals(self.INTERRUPT).name}...",
                file=sys.stderr,
            )
            sys.exit(0)

    def header(self):
        """Print header"""
        if self.args.cvss4:
            cvss_title = "CVSS 4.0"
        else:
            cvss_title = "CVSS 3.1"
        if self.args.url:
            cve_title = "URL to CVE details"
            prefixlen = len(self.URL_PREFIX)
        else:
            cve_title = "CVE ID"
            prefixlen = 0
        print(
            f"{'TIME UPDATED (UTC)'.ljust(20)} {cve_title.ljust(15+prefixlen)} "
            f"{cvss_title.ljust(10)} SUMMARY [vendor: product]",
            file=sys.stderr,
        )
        try:
            print(f"{''.ljust(os.get_terminal_size()[0], '-')}", file=sys.stderr)
        except OSError:
            print(f"{''.ljust(80, '-')}", file=sys.stderr)

    def history(self):
        """Prints CVE changes from the commit history, one commit at a time"""
        history = self.args.commits
        try:
            cursor = self.get_cursor(history)
        except IndexError as e:
            print(
                f"{e}; try lower --commit",
                file=sys.stderr,
            )
            exit(1)
        while history > 0:
            history -= 1
            new_cursor = self.get_cursor(history)
            if self.args.verbose:
                print(f"[{cursor} → {new_cursor}]", file=sys.stderr)
            self.print_changes(new_cursor, cursor)
            cursor = new_cursor
            self.check_interrupt()

    def monitor(self):
        """Monitors new cvelistV5 commits and prints changed CVEs"""
        cursor = self.get_cursor()

        while True:
            for x in range(self.args.interval):
                self.check_interrupt()
                time.sleep(1)
            self.pull()
            new_cursor = self.get_cursor()
            if new_cursor != cursor:
                if self.args.verbose:
                    print(f"[{cursor} → {new_cursor}]", file=sys.stderr)
                self.print_changes(new_cursor, cursor)
                cursor = new_cursor

    def pull(self):
        """Runs git pull"""
        if self.args.verbose:
            subprocess.call(["git", "pull"])
        else:
            subprocess.call(
                ["git", "pull"], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT
            )

    def get_cursor(self, offset: int = 0) -> str:
        """Gets commit id at the offset from the current head"""
        result = subprocess.run(
            ["git", "rev-parse", "--verify", f"HEAD~{offset}"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if result.stderr:
            raise IndexError(f"Commit at HEAD~{offset} not found")
        return result.stdout.decode("utf-8").strip()

    def print_changes(self, current_commit: str, past_commit: str):
        """Print summary of changed CVE"""
        lines = []
        try:
            if self.args.ansi:
                # add extra width for invisible characters (ANSI codes)
                width = os.get_terminal_size()[0] + 21
            else:
                # substract one character to fit occasional wide characters like emojis
                width = os.get_terminal_size()[0] - 1
        except OSError:
            width = False

        for change in self.get_changes(current_commit, past_commit):
            lines.append(self.format_line(change))
        lines.sort()
        for line in lines:
            if width:
                print(line[:width])
            else:
                print(line)

    def get_changes(
        self, current_commit: str, past_commit: str
    ) -> list[dict[str, str]]:
        """Return changes in CVEs between two commits"""
        changes = []
        for file in self.changed_files(current_commit, past_commit):
            type = re.split(r"\t+", file.decode("utf-8").strip())[0]
            path = re.split(r"\t+", file.decode("utf-8").strip())[1]

            if type == "D":
                if self.args.ansi:
                    print(
                        f"{ANSI.code('red')}Deleted: "
                        f"{Path(path).stem}{ANSI.code('end')}",
                        file=sys.stderr,
                    )
                else:
                    print(f"Deleted: {Path(path).stem}", file=sys.stderr)
                continue

            try:
                current = self.json_at_commit(path, current_commit)
                modified = current["cveMetadata"]["dateUpdated"]
                modified = re.sub(r"\..*", "", modified)
                modified = re.sub(r"T", " ", modified)
                cve = current["cveMetadata"]["cveId"]
            except (KeyError, TypeError):
                print(
                    f"Unexpected structure in {current_commit}:{path}",
                    file=sys.stderr,
                )
                continue

            if type == "M":
                try:
                    past = self.json_at_commit(path, past_commit)
                    if self.args.cvss4:
                        past_cvss = self.cvss40score(past)
                    else:
                        past_cvss = self.cvss31score(past)
                except TypeError:
                    print(
                        f"Unexpected structure in {past_commit}:{path}",
                        file=sys.stderr,
                    )
                    past_cvss = 0.0
            else:
                past_cvss = 0.0

            if self.args.cvss4:
                current_cvss = self.cvss40score(current)
            else:
                current_cvss = self.cvss31score(current)

            changes.append(
                {
                    "type": type,
                    "modified": modified,
                    "cve": cve,
                    "past_cvss": past_cvss,
                    "current_cvss": current_cvss,
                    "summary": re.sub(r"\n", " ", self.generate_summary(current)),
                }
            )
        return changes

    def format_line(self, line) -> str:
        """Format a line based on the selected modes"""
        modified = line["modified"]

        if self.args.url:
            cve = f"{self.URL_PREFIX}{line['cve']}"
            prefixlen = len(self.URL_PREFIX)
        else:
            cve = line["cve"]
            prefixlen = 0
        if self.args.ansi:
            if line["type"] == "M":
                cve = f"{ANSI.code('bright_blue')}{cve}{ANSI.code('end')}"
            else:
                cve = f"{ANSI.code('bright_cyan')}{cve}{ANSI.code('end')}"

        if line["current_cvss"] == 0.0:
            current_cvss = "   "
        else:
            current_cvss = line["current_cvss"]
        if line["past_cvss"] == 0.0:
            past_cvss = "   "
        else:
            past_cvss = line["past_cvss"]
        if self.args.ansi:
            END = ANSI.code("end")
            if line["current_cvss"] >= 9.0:
                cvss_color = ANSI.code("bright_red", "bold")
            elif line["current_cvss"] >= 7.0:
                cvss_color = ANSI.code("red")
            elif line["current_cvss"] >= 4.0:
                cvss_color = ANSI.code("yellow")
            elif line["current_cvss"] >= 0.1:
                cvss_color = ANSI.code("green")
            else:
                cvss_color = f"{END}\000\000\000"
        if current_cvss != past_cvss:
            if self.args.ansi:
                cvss = f"{past_cvss} {cvss_color}→ {current_cvss}{END}"
            else:
                cvss = f"{past_cvss} → {current_cvss}"
        else:
            if self.args.ansi:
                cvss = f"{cvss_color}{current_cvss}{END}"
            else:
                cvss = f"{current_cvss}"

        if self.args.ansi:
            return (
                f"{modified.ljust(20)} {cve.ljust(26+prefixlen)} "
                f"{cvss.ljust(21)} {line['summary']}"
            )
        else:
            return (
                f"{modified.ljust(20)} {cve.ljust(15+prefixlen)} "
                f"{cvss.ljust(10)} {line['summary']}"
            )

    def cvss31score(self, cve: dict) -> float:
        """Gets CVSS 3.1 Score. If present in both containers, take higher"""
        cvss_adp = 0.0
        try:
            adp_metrics = cve["containers"]["adp"][0]["metrics"]
            for metric in adp_metrics:
                try:
                    if metric["cvssV3_1"]["version"] == "3.1":
                        cvss_adp = metric["cvssV3_1"]["baseScore"]
                        break
                except KeyError:
                    pass
        except KeyError:
            pass

        cvss_cna = 0.0
        try:
            cna_metrics = cve["containers"]["cna"]["metrics"]
            for metric in cna_metrics:
                try:
                    if metric["cvssV3_1"]["version"] == "3.1":
                        cvss_cna = metric["cvssV3_1"]["baseScore"]
                        break
                except KeyError:
                    pass
        except KeyError:
            pass

        cvss = max(cvss_adp, cvss_cna)
        return float("%0.1f" % cvss)

    def cvss40score(self, cve: dict) -> float:
        """Gets CVSS 4.0 Score; only available in the cna container"""
        cvss_cna = 0.0
        try:
            cna_metrics = cve["containers"]["cna"]["metrics"]
            for metric in cna_metrics:
                try:
                    if metric["cvssV4_0"]["version"] == "4.0":
                        cvss_cna = metric["cvssV4_0"]["baseScore"]
                        break
                except KeyError:
                    pass
        except KeyError:
            pass
        return float("%0.1f" % cvss_cna)

    def generate_summary(self, cve: dict) -> str:
        """Generates summary from title or description & affected vendor/product"""
        title = ""
        description = ""
        try:
            title = cve["containers"]["cna"]["title"]
        except KeyError:
            try:
                for description in cve["containers"]["cna"]["descriptions"]:
                    if description["lang"] in ("en", "en-US", "en_US"):
                        description = description["value"]
                        title = ""
                        break
            except KeyError:
                try:
                    # This is not a very good title, but a last resort.
                    title = cve["containers"]["adp"][0]["title"]
                except KeyError:
                    pass

        vendor = ""
        try:
            vendor = cve["containers"]["adp"][0]["affected"][0]["vendor"]
        except KeyError:
            try:
                if cve["containers"]["cna"]["affected"][0]["vendor"] != "n/a":
                    vendor = cve["containers"]["cna"]["affected"][0]["vendor"]
            except KeyError:
                pass

        product = ""
        try:
            product = cve["containers"]["adp"][0]["affected"][0]["product"]
        except KeyError:
            try:
                if cve["containers"]["cna"]["affected"][0]["product"] != "n/a":
                    product = cve["containers"]["cna"]["affected"][0]["product"]
            except KeyError:
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

    def changed_files(self, current_commit: str, past_commit: str) -> list:
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

    def json_at_commit(self, path: Path, commit: str) -> dict:
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
        return {}

    def cvelist_repo(self):
        """Detects whether the working directory is the root of CVEProject/cvelistV5"""
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
        except (FileNotFoundError, PermissionError):
            return False


class ANSI:
    @staticmethod
    def code(color: str, style: str = "normal") -> str:
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
        usage="%(prog)s [-haouv4] [-i s] [-c N]",
        epilog="Requires git. "
        "Working directory must be the root of cvelistV5 repository.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    argParser.add_argument(
        "-a",
        "--ansi",
        action="store_true",
        help="add ansi colors to the output",
        default=False,
    )
    argParser.add_argument(
        "-o",
        "--once",
        action="store_true",
        help="only the current tail; no active follow",
        default=False,
    )
    argParser.add_argument(
        "-u",
        "--url",
        action="store_true",
        help="prefix cve with url to nvd nist details",
        default=False,
    )
    argParser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="show verbose information on git pull",
        default=False,
    )
    argParser.add_argument(
        "-4",
        "--cvss4",
        action="store_true",
        help="show cvss 4.0 score instead of cvss 3.1",
        default=False,
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
        help="number of commits to print initially",
        default=30,
    )
    args = argParser.parse_args()
    main(args)
