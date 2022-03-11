# Misc-Scripts by oh2fih

Miscellaneous scripts for different purposes. Completely unrelated to each other.

| Category | Script & Language | Purpose & Usage |
|:---|:---|:---|
| Automation | [`create-site.sh`](sbin/create-site.sh) <br> Shell (bash) | Web hosting automation for Debian with Apache2, PHP-FPM & Let's Encrypt. <br> `sudo ./create-site.sh username example.com [www.example.com ...]` |
| Infosec | [`netcat-proxy.sh`](bin/netcat-proxy.sh) <br> Shell (sh) | Creates a simple persistent TCP proxy with netcat & named pipes. <br> `./netcat-proxy.sh listenport targethost targetport` |
| Infosec | [`partialpassword.sh`](bin/partialpassword.sh) <br> Shell (bash) | Creates a new wordlist from a wordlist by replacing all ambiguous characters with all their possible combinations. <br> `./partialpassword.sh input.txt output.txt O0 [Il1 ...]` |
| WordPress | [`test-cache-enabler.py`](bin/test-cache-enabler.py) <br> Python 3 | Tests whether the Cache Enabler by KeyCDN (WordPress) is working properly on the URLs given as arguments. <br> `./test-cache-enabler.py https://example.com [...]` |
| Web | [`koronarokotusaika.sh`](bin/koronarokotusaika.sh) <br> Shell (bash) | COVID-19 vaccination schedule checker for `app.koronarokotusaika.fi` users. Only meaningful for people living in Uusimaa, Finland. <br> `./koronarokotusaika.sh Municipality YearOfBirth Dose` |
| Web | [`xxl-product-pricelimiter.sh`](bin/xxl-product-pricelimiter.sh) <br> Shell (bash) | XXL.fi product price checker / limiter. <br> `./xxl-product-pricelimiter.sh XXL.fi-ProductURL MaxPrice` |
