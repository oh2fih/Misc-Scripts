# Misc-Scripts by oh2fih

Miscellaneous scripts for different purposes. Completely unrelated to each other.

| Category | Script | Purpose & Usage| Language |
|:---|:---|:---|:---|
| Automation | [`create-site.sh`](create-site.sh) | Web hosting automation for Debian with Apache2, PHP-FPM & Let's Encrypt. <br> `sudo ./create-site.sh username example.com [www.example.com ...]` | Shell (bash) |
| Infosec | [`netcat-proxy.sh`](netcat-proxy.sh) | Creates a simple persistent TCP proxy with netcat & named pipes. <br> `./netcat-proxy.sh listenport targethost targetport` | Shell (sh) |
| Infosec | [`partialpassword.sh`](partialpassword.sh) | Creates a new wordlist from a wordlist by replacing all ambiguous characters with all their possible combinations. <br> `./partialpassword.sh input.txt output.txt O0 [Il1 ...]` | Shell (bash) |
| WordPress | [`test-cache-enabler.py`](test-cache-enabler.py) | Tests whether the Cache Enabler by KeyCDN (WordPress) is working properly on the URLs given as arguments. <br> `./test-cache-enabler.py https://example.com [...]` | Python 3 |
| Web | [`koronarokotusaika.sh`](koronarokotusaika.sh) | COVID-19 vaccination schedule checker for `app.koronarokotusaika.fi` users. Only meaningful for people living in Uusimaa, Finland. <br> `./koronarokotusaika.sh Municipality YearOfBirth Dose` | Shell (bash) |
| Web | [`xxl-product-pricelimiter.sh`](xxl-product-pricelimiter.sh) | XXL.fi product price checker / limiter. <br> `./xxl-product-pricelimiter.sh XXL.fi-ProductURL MaxPrice` | Shell (bash) |
