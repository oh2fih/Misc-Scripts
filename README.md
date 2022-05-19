# Misc-Scripts by oh2fih

Miscellaneous scripts for different purposes. Completely unrelated to each other.

| Category | Script & Language | Purpose & Usage |
|:---|:---|:---|
| Automation | [`create-site.sh`](sbin/create-site.sh) <br> Shell (bash) | Web hosting automation for Debian with Apache2, PHP-FPM & Let's Encrypt. <br> `sudo ./create-site.sh username example.com [www.example.com ...]` |
| Firewall | [`list2bans.sh`](sbin/list2bans.sh) <br> Shell (bash) | Lists all Fail2Ban jail statuses or jails banning an ip. <br> `sudo ./list2bans.sh [ip]` |
| Firewall | [`unfail2ban.sh`](sbin/unfail2ban.sh) <br> Shell (bash) | Unbans the given IPs from all Fail2Ban jails. <br> `sudo ./unfail2ban.sh ip [ip ...]` |
| Infosec | [`netcat-proxy.sh`](bin/netcat-proxy.sh) <br> Shell (sh) | Creates a simple persistent TCP proxy with netcat & named pipes. <br> `./netcat-proxy.sh listenport targethost targetport` |
| Infosec | [`partialpassword.sh`](bin/partialpassword.sh) <br> Shell (bash) | Creates a new wordlist from a wordlist by replacing all ambiguous characters with all their possible combinations. <br> `./partialpassword.sh input.txt output.txt O0 [Il1 ...]` |
| Infosec <br> Automation | [`make-mac-prefixes.py`](bin/make-mac-prefixes.py) <br> Python 3 | Processes registered MAC address prefixes from [IEEE MA-L Assignments (CSV)](https://standards.ieee.org/products-programs/regauth/) (stdin) to Nmap's [`nmap-mac-prefixes`](https://github.com/nmap/nmap/blob/master/nmap-mac-prefixes)  (stdout) with a few additional unregistered OUIs.<br> `curl https://standards-oui.ieee.org/oui/oui.csv \| ./make-mac-prefixes.py > nmap-mac-prefixes` |
| WordPress | [`test-cache-enabler.py`](bin/test-cache-enabler.py) <br> Python 3 | Tests whether the Cache Enabler by KeyCDN (WordPress) is working properly on the URLs given as arguments. <br> `./test-cache-enabler.py https://example.com [...]` |
| Web | [`koronarokotusaika.sh`](bin/koronarokotusaika.sh) <br> Shell (bash) | COVID-19 vaccination schedule checker for `app.koronarokotusaika.fi` users. Only meaningful for people living in Uusimaa, Finland. <br> `./koronarokotusaika.sh Municipality YearOfBirth Dose` |
| Web | [`xxl-product-pricelimiter.sh`](bin/xxl-product-pricelimiter.sh) <br> Shell (bash) | XXL.fi product price checker / limiter. <br> `./xxl-product-pricelimiter.sh XXL.fi-ProductURL MaxPrice` |

## Install & update

Interactive installer & updater `install.sh` and simple updater `update.sh` help putting the scripts in directories that are typically in your `$PATH`. While using these installers as root/sudo, you might need to add an exception for the repository with:

```
sudo git config --global --add safe.directory <path>
```
