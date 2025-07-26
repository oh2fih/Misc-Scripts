#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ------------------------------------------------------------------------------
# Follow changes (commits) in CVEProject / cvelistV5
#
# Usage: follow-cvelist.py [-haForu4] [-vvvv] [-i s] [-c N] [-w N] [-m f]
#
#  -h, --help          show this help message and exit
#  -a, --ansi          add ansi colors to the output (default: False)
#  -F, --force         origin/main hard reset if git pull fails (default: False)
#  -o, --once          only the current tail; no active follow (default: False)
#  -r, --reload-only   skip pulls & only follow local changes (default: False)
#  -u, --url           prefix cve with url to nvd nist details (default: False)
#  -4, --cvss4         show cvss 4.0 score instead of cvss 3.1 (default: False)
#  -v, --verbose       each -v increases verbosity (commits, git pull, raw data)
#  -i s, --interval s  pull interval in seconds (default: 150)
#  -c N, --commits N   number of commits to print initially (default: 30)
#  -w N, --width N     overwrite autodetected terminal width (<50 => multiline)
#  -m f, --cvss-min f  minimum cvss score; skip lower values (default: None)
#
# Requires git. Working directory must be the root of the cvelistV5 repository.
#
# Change prefix for --url mode with environment variable CVE_URL_PREFIX.
#
# Author : Esa Jokinen (oh2fih)
# Home   : https://github.com/oh2fih/Misc-Scripts
# ------------------------------------------------------------------------------
# flake8: noqa: E501

import argparse
import json
import os
import re
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List


def main(args: argparse.Namespace) -> None:
    cvelist = CvelistFollower(args)
    cvelist.header()
    if not args.reload_only:
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

    def interrupt_handler(self, signum: Any, frame: Any) -> None:
        """Tells that an interrupt signal is received through variable INTERRUPT"""
        self.INTERRUPT = signum

    def check_interrupt(self) -> None:
        """Exits if interrupt is received"""
        if self.INTERRUPT:
            print(
                f"Exiting after receiving {signal.Signals(self.INTERRUPT).name}...",
                file=sys.stderr,
            )
            sys.exit(0)

    def width(self) -> int:
        """Configured or detected terminal width for line lenght limits"""
        if args.width:
            return int(args.width)
        else:
            try:
                return os.get_terminal_size()[0]
            except OSError:
                return 1

    def header(self) -> None:
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
        print(f"{''.ljust(self.width(), '-')}", file=sys.stderr)

    def history(self) -> None:
        """Prints CVE changes from the commit history, one commit at a time"""
        history = self.args.commits
        try:
            cursor = self.get_cursor(history)
        except IndexError as e:
            print(
                f"{e}; showing only the latest update (try lower --commit)",
                file=sys.stderr,
            )
            history = 1
            cursor = self.get_cursor(history)
        while history > 0:
            history -= 1
            new_cursor = self.get_cursor(history)
            if self.args.verbose > 0:
                print(f"[{cursor} → {new_cursor}]", file=sys.stderr)
            self.print_changes(new_cursor, cursor)
            cursor = new_cursor
            self.check_interrupt()

    def monitor(self) -> None:
        """Monitors new cvelistV5 commits and prints changed CVEs"""
        cursor = self.get_cursor()

        while True:
            for x in range(self.args.interval):
                self.check_interrupt()
                time.sleep(1)
            if not self.args.reload_only:
                self.pull()
            elif self.args.verbose > 1:
                print(
                    f"{time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime())}  Reload",
                    file=sys.stderr,
                )
            new_cursor = self.get_cursor()
            if new_cursor != cursor:
                if self.args.verbose > 0:
                    print(f"[{cursor} → {new_cursor}]", file=sys.stderr)
                self.print_changes(new_cursor, cursor)
                cursor = new_cursor

    def pull(self) -> None:
        """Runs git pull. Exits on permanent, unrecoverable errors"""
        result = subprocess.run(
            ["git", "pull"], stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        if self.args.verbose > 1:
            print(
                f"{time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime())}  "
                f"{result.stdout.decode('utf-8').strip()}",
                file=sys.stderr,
            )
        if result.returncode > 0:
            if self.fetch_all():
                if self.args.force:
                    if self.args.verbose > 1:
                        print(
                            f"{result.stderr.decode('utf-8').strip()}",
                            file=sys.stderr,
                        )
                    self.reset_repo()
                else:
                    print(
                        f"{result.stderr.decode('utf-8').strip()}",
                        file=sys.stderr,
                    )
                    begin = f"{ANSI.code('red')}" if self.args.ansi else ""
                    end = f"{ANSI.code('end')}" if self.args.ansi else ""
                    print(
                        f"{begin}Manual intervention (or -F/--force) "
                        f"required; 'git pull' failed permanently!{end}",
                        file=sys.stderr,
                    )
                    sys.exit(1)

    def fetch_all(self) -> bool:
        """Try fetch; good for distinguishing connectivity issues from other failures"""
        result = subprocess.run(
            ["git", "fetch", "--all"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT
        )
        if self.args.verbose > 1:
            print(f"{result.stdout.decode('utf-8').strip()}", file=sys.stderr)
        if result.returncode > 0:
            begin = f"{ANSI.code('yellow')}" if self.args.ansi else ""
            end = f"{ANSI.code('end')}" if self.args.ansi else ""
            print(
                f"{begin}{time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime())}  "
                f"Fetch failed; connectivity issues?{end}",
                file=sys.stderr,
            )
            return False  # fetch failed
        return True  # fetch successful

    def reset_repo(self) -> None:
        """Tries to recover from git pull errors by hard resetting to origin/main"""
        begin = f"{ANSI.code('yellow')}" if self.args.ansi else ""
        end = f"{ANSI.code('end')}" if self.args.ansi else ""
        print(
            f"{begin}{time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime())}"
            f"  Recovering from a failed git pull...{end}",
            file=sys.stderr,
        )
        result = subprocess.run(
            ["git", "reset", "--hard", "origin/main"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        if self.args.verbose > 1:
            print(f"{result.stdout.decode('utf-8').strip()}", file=sys.stderr)
        if result.returncode > 0:
            begin = f"{ANSI.code('red')}" if self.args.ansi else ""
            end = f"{ANSI.code('end')}" if self.args.ansi else ""
            print(
                f"{begin}Hard reset to origin/main failed; "
                f"manual intervention required!{end}",
                file=sys.stderr,
            )
            sys.exit(1)
        begin = f"{ANSI.code('green')}" if self.args.ansi else ""
        end = f"{ANSI.code('end')}" if self.args.ansi else ""
        print(f"{begin}Successfully recovered.{end}", file=sys.stderr)

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

    def print_changes(self, current_commit: str, past_commit: str) -> None:
        """Print summary of changed CVE"""
        lines = []
        # multiline mode if terminal width is too small to fit summary on the same line
        if self.width() >= 50:
            if self.args.ansi:
                # add extra width for invisible characters (ANSI codes)
                width = self.width() + 21
            else:
                # substract one character to fit occasional wide characters like emojis
                width = self.width() - 1
        else:
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
    ) -> List[Dict[str, str]]:
        """Return changes in CVEs between two commits"""
        changes = []
        skipped = 0
        for file in self.changed_files(current_commit, past_commit):
            type = re.split(r"\t+", file.decode("utf-8").strip())[0]
            path = Path(re.split(r"\t+", file.decode("utf-8").strip())[1])

            if type == "D":
                if self.args.ansi:
                    print(
                        f"{ANSI.code('red')}Deleted: " f"{path.stem}{ANSI.code('end')}",
                        file=sys.stderr,
                    )
                else:
                    print(f"Deleted: {path.stem}", file=sys.stderr)
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

            if args.cvss_min:
                try:
                    if float(current_cvss) < args.cvss_min:
                        skipped += 1
                        continue
                except (TypeError, ValueError):
                    skipped += 1
                    continue

            change = {
                "type": type,
                "modified": modified,
                "cve": cve,
                "past_cvss": past_cvss,
                "current_cvss": current_cvss,
                "summary": re.sub(r"\n", " ", self.generate_summary(current)),
            }
            if self.args.verbose > 2:
                print(f"[change] {change}", file=sys.stderr)
            changes.append(change)

        if args.cvss_min and args.verbose > 0 and skipped > 0:
            print(
                f"Skipped {skipped} CVEs with CVSS < {args.cvss_min}", file=sys.stderr
            )
        return changes

    def format_line(self, line: Dict[str, Any]) -> str:
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

    def cvss31score(self, cve: Dict[str, Any]) -> float:
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

    def cvss40score(self, cve: Dict[str, Any]) -> float:
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

    def generate_summary(self, cve: Dict[str, Any]) -> str:
        """Generates summary from title or description & affected vendor/product"""
        title = ""
        description = ""
        try:
            title = cve["containers"]["cna"]["title"]
        except KeyError:
            try:
                for description in cve["containers"]["cna"]["descriptions"]:
                    if description["lang"] in ["en", "en-US", "en_US"]:
                        description = description["value"]
                        title = ""
                        break
            except KeyError:
                try:
                    # This is not a very good title, but a last resort.
                    title = cve["containers"]["adp"][0]["title"]
                except KeyError:
                    try:
                        # Mostly for rejected or withdrawn CVEs
                        try:
                            assignerShortName = cve["cveMetadata"]["assignerShortName"]
                            assigner = f" – assigner: {assignerShortName}"
                        except KeyError:
                            assigner = ""
                        title = f"{cve['cveMetadata']['state']}{assigner}"
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

    def changed_files(self, current_commit: str, past_commit: str) -> List[bytes]:
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
        if result.stdout:
            return result.stdout.readlines()
        else:
            return []

    def json_at_commit(self, path: Path, commit: str) -> Any:
        """Dictionary of JSON file contents at given commit"""
        try:
            pathstr = path.as_posix()  # for Windows compatibility
            result = subprocess.run(
                ["git", "show", f"{commit}:{pathstr}"], stdout=subprocess.PIPE
            )
            data = json.loads(result.stdout.decode("utf-8"))
            if self.args.verbose > 3:
                print(f"[{commit}:{pathstr}] {data}", file=sys.stderr)
            return data
        except IOError:
            print(f"Could not open {commit}:{pathstr}", file=sys.stderr)
        except json.decoder.JSONDecodeError:
            print(f"Could not parse {commit}:{pathstr}", file=sys.stderr)
        return {}

    def cvelist_repo(self) -> bool:
        """Detects whether the working directory is the root of CVEProject/cvelistV5"""
        try:
            result = subprocess.run(
                ["git", "rev-parse", "--show-toplevel"], stdout=subprocess.PIPE
            )
            toplevel = Path(result.stdout.decode("utf-8").strip())
            working = Path(os.getcwd())

            if os.path.samefile(str(toplevel), str(working)):
                readmefile = open("README.md", "r", encoding="utf-8")
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


def check_positive(value: str) -> int:
    ivalue = int(value)
    if ivalue <= 0:
        raise argparse.ArgumentTypeError(f"{value} is not a positive integer")
    return ivalue


if __name__ == "__main__":
    argParser = argparse.ArgumentParser(
        description="Follow changes (commits) in CVEProject / cvelistV5",
        usage="%(prog)s [-haForu4] [-vvvv] [-i s] [-c N] [-w N] [-m f]",
        epilog="Requires git. "
        "Working directory must be the root of the cvelistV5 repository.",
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
        "-F",
        "--force",
        action="store_true",
        help="origin/main hard reset if git pull fails",
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
        "-r",
        "--reload-only",
        action="store_true",
        help="skip pulls & only follow local changes",
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
        "-4",
        "--cvss4",
        action="store_true",
        help="show cvss 4.0 score instead of cvss 3.1",
        default=False,
    )
    argParser.add_argument(
        "-v",
        "--verbose",
        action="count",
        help="each -v increases verbosity (commits, git pull, raw data)",
        default=0,
    )
    param_group = argParser.add_argument_group("parameters")
    param_group.add_argument(
        "-i",
        "--interval",
        type=check_positive,
        metavar="s",
        help="pull/reload interval in seconds",
        default=150,
    )
    param_group.add_argument(
        "-c",
        "--commits",
        type=check_positive,
        metavar="N",
        help="number of commits to print initially",
        default=30,
    )
    param_group.add_argument(
        "-w",
        "--width",
        type=check_positive,
        metavar="N",
        help="overwrite autodetected terminal width (<50 => multiline)",
    )
    param_group.add_argument(
        "-m",
        "--cvss-min",
        type=float,
        metavar="f",
        help="minimum cvss score; skip lower values",
    )
    args = argParser.parse_args()
    if args.verbose > 4:
        args.verbose = 4
    if args.cvss_min:
        verbosity = {
            4: "raw json, raw changes, git pulls, commit ID, skipped CVEs",
            3: "raw changes, git pulls, commit IDs, skipped CVEs",
            2: "git pulls, commit IDs, skipped CVEs",
            1: "commit IDs, skipped CVEs",
        }
    else:
        verbosity = {
            4: "raw json, raw changes, git pulls, commit ID",
            3: "raw changes, git pulls, commit IDs",
            2: "git pulls, commit IDs",
            1: "commit IDs",
        }
    if args.verbose > 0:
        print(f"VERBOSITY: {verbosity[args.verbose]}", file=sys.stderr)
    if args.reload_only:
        print(
            "Reload only mode; "
            "make sure the periodic 'git pull' gets run somewhere else",
            file=sys.stderr,
        )
    main(args)
