# Misc-Scripts by oh2fih

Miscellaneous scripts for different purposes. Mostly unrelated to each other.

![ShellCheck](https://github.com/oh2fih/Misc-Scripts/workflows/ShellCheck/badge.svg)
![Python Code Quality)](https://github.com/oh2fih/Misc-Scripts/workflows/Python%20Code%20Quality/badge.svg)

| Category | Script & Language | Purpose & Usage |
|:---|:---|:---|
| Automation | [`find-inactive-ssh-sessions.sh`](bin/find-inactive-ssh-sessions.sh)<br>Shell (bash) | Find inactive (idle) SSH sessions or kill (`-k`) them. Could be used as a [workaround](https://serverfault.com/a/1162840/274176) for OpenSSH < 9.2 that did not have the [sshd_config(5)](https://man.openbsd.org/sshd_config) keywords `ChannelTimeout` & `UnusedConnectionTimeout`.<br>`find-inactive-ssh-sessions.sh [-k] [-i seconds] [-s]`|
| DNS<br>DANE | [`letsencrypt-tlsa.sh`](bin/letsencrypt-tlsa.sh)<br>Shell (bash) | Create TLSA records from the current & backup Let's Encrypt Intermediate CAs. Defaults to `le-ca TLSA 2 1 1` with configurable selector (`-f`) & matching type (`-m`).<br>`letsencrypt-tlsa.sh [-f] [-m N] [-l "label [TTL]"] [-h] [2>/dev/null]`|
| Email | [`mail-prepender.sh`](bin/mail-prepender.sh)<br>Shell (bash) | Prepends (to stdin/stdout) email header strings given in as flags `i`, `I`, `a`, or `A`; after possible mbox `From` & `Return-Path` header lines. Intended as a limited `formail` replacement that ignores the nyanses of the flags and simply prepends the valid (RFC 5322, 2.2) non-empty headers keeping the other headers as is. Flags `x` & `X` are implemented. Any other flags are ignored. |
| Git | [`git-find-commits-by-file-hash.sh`](bin/git-find-commits-by-file-hash.sh)<br>Shell (bash) | Search Git repository history for commits with SHA-256 checksum of a file. Answers the question "Has this version of this file ever been committed as the file on this path of this Git repository?" and shows a summary (`git show --stat`) of the matching commit(s). The `path` should be relative to the repository root.<br>`git-find-commits-by-file-hash.sh sha256sum path`|
| Infosec | [`netcat-proxy.sh`](bin/netcat-proxy.sh)<br>Shell (sh) | Creates a simple persistent TCP proxy with netcat & named pipes.<br>`netcat-proxy.sh listenport targethost targetport` |
| Infosec | [`follow-cvelist.py`](bin/follow-cvelist.py)<br>Python 3.6+ | Follow changes (commits) in CVEProject / [cvelistV5](https://github.com/CVEProject/cvelistV5). Requires git. Working directory must be the root of the cvelistV5 repository.<br>`follow-cvelist.py [-haForu4] [-vvvv] [-i s] [-c N] [-w N]`|
| Infosec | [`partialpassword.sh`](bin/partialpassword.sh)<br>Shell (bash) | Creates a new wordlist from a wordlist by replacing all ambiguous characters with all their possible combinations.<br>`partialpassword.sh input.txt output.txt O0 [Il1 ...]` |
| Infosec | [`duplicate-ssh-hostkeys.sh`](bin/duplicate-ssh-hostkeys.sh)<br>Shell (bash) | Find duplicate SSH host keys in a CIDR range. Examine your network for shared host keys that could potentially be dangerous.<br>`duplicate-ssh-hostkeys.sh CIDR [HostKeyAlgorithm ...]` |
| Infosec<br>Automation | [`make-mac-prefixes.py`](bin/make-mac-prefixes.py)<br>Python 3.6+ | Processes registered MAC address prefixes from [IEEE MA-L Assignments (CSV)](https://standards.ieee.org/products-programs/regauth/) (stdin) to Nmap's [`nmap-mac-prefixes`](https://github.com/nmap/nmap/blob/master/nmap-mac-prefixes)  (stdout) with a few additional unregistered OUIs.<br>`curl https://standards-oui.ieee.org/oui/oui.csv \| make-mac-prefixes.py > nmap-mac-prefixes` |
| WordPress | [`test-cache-enabler.py`](bin/test-cache-enabler.py)<br>Python 3.6+ | Tests whether the Cache Enabler by KeyCDN (WordPress) is working properly on the URLs given as arguments.<br>`test-cache-enabler.py https://example.com [...]` |
| Web | [`detect-modified-html-element.sh`](bin/detect-modified-html-element.sh)<br>Shell (bash) | Checks HTML element changes on a web page since last run. Configured via environment variables.<br>Recommended to be executed as a SystemD [service](systemd/detect-modified-html-element.service.example). |
| Web | [`http-dns-round-robin.sh`](bin/http-dns-round-robin.sh)<br>Shell (bash) | Print HTTP headers for every DNS round-robin IP (IPv4 + IPv6)<br>`http-dns-round-robin.sh URL`|
| Web | [`product-pricelimiter.sh`](bin/product-pricelimiter.sh)<br>Shell (bash) | Compare product price on a web page with a given maximum price. Use, e.g., developer tools on your browser to find the HTML element containing the price.<br>`product-pricelimiter.sh -u URL -s Selector [-m MaxPrice] [-n N] [-d N]` |
| Web | <del>`koronarokotusaika.sh`</del><br>Shell (bash) | This script has been removed as koronarokotusaika.fi (bookcovidvaccine.fi) has been shut down on April 28, 2023. |
| Web | <del>`xxl-product-pricelimiter.sh`</del><br>Shell (bash) | This script has been replaced by the generalized [`product-pricelimiter.sh`](bin/product-pricelimiter.sh) as the HTML structure of XXL.fi has changed. |

## Scripts that require `sudo` privileges ([`sbin/`](sbin/))

| Category | Script & Language | Purpose & Usage |
|:---|:---|:---|
| Automation | [`autoreboot-on-segfaults.sh`](sbin/autoreboot-on-segfaults.sh)<br>Shell (sh) | Temporary solution that automatically reboots the system if there has been more than `MAX_SEGFAULTS` segmentation faults on the current boot. Fix the system!<br>Recommended to be scheduled with a SystemD [service](systemd/autoreboot-on-segfaults.service.example) & [timer](systemd/autoreboot-on-segfaults.service.example).|
| Automation | [`backup-mysql-databases.sh`](sbin/backup-mysql-databases.sh)<br>Shell (bash) | Backup all MySQL/MariaDB databases; dump & compress. Overwrites older backups matching the same date pattern.<br>Recommended to be scheduled with a SystemD [service](systemd/backup-mysql-databases.service.example) & [timer](systemd/backup-mysql-databases.timer.example).|
| Automation | [`create-site.sh`](sbin/create-site.sh)<br>Shell (bash) | Web hosting automation for Debian with Apache2, PHP-FPM & Let's Encrypt.<br>`sudo create-site.sh username example.com [www.example.com ...]` |
| Firewall | [`list2bans.sh`](sbin/list2bans.sh)<br>Shell (bash) | Lists all Fail2Ban jail statuses or jails banning an IP.<br>`sudo list2bans.sh [ip]` |
| Firewall | [`unfail2ban.sh`](sbin/unfail2ban.sh)<br>Shell (bash) | Unbans the given IPs from all Fail2Ban jails.<br>`sudo unfail2ban.sh ip [ip ...]` |
| Infosec | [`fake-bitlocker.sh`](sbin/fake-bitlocker.sh)<br>Shell (bash) | Overwrite disk with random data & inject a fake BitLocker header. Simulates a corrupted BitLocker-encrypted disk at a glance, but not suitable for forensic deception. <br>`sudo fake-bitlocker.sh /dev/sdX [passes [label]]` |

## Install & update

Interactive installer & updater `install.sh` and simple updater `update.sh` help putting the scripts in directories that are typically in your `$PATH`. While using these installers as root/sudo, you might need to add an exception for the repository with:

```bash
sudo git config --global --add safe.directory <path>
```
