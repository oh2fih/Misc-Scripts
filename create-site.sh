#!/bin/bash
# -----------------------------------------------------------
# A web hosting automation script (Debian: Apache2, PHP, LE).
#
# Usage: sudo $0 username example.com [www.example.com ...]
#
# Creates:
#  - PHP-FPM pool for the user (controlled with $PHPVERSION)
#  - Webroot directory at /var/www/username/example.com
#  - Common alias for Let's Encrypt ($LETSENCRYPT_WEBROOT)
#  - Gets a Let's Encrypt certificate (HTTP-01 challenge)
#  - Apache2 VirtualHost configuration.
#
# Requires:
# - Apache2 with the following modules enabled:
#   - mod_ssl
#   - mod_proxy
#   - mod_proxy_fcgi
# - PHP FPM
# - Certbot
#
# Author : Esa Jokinen (oh2fih)
# -----------------------------------------------------------

### CONFIGURATION

PHPVERSION="8.0"
LETSENCRYPT_WEBROOT="/var/www/letsencrypt"


### Check for sudo privileges and the requirements.

if [ "$#" -le 1 ]; then
  echo "Usage: sudo $0 username example.com [www.example.com ...]"
  exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "*** ERROR! This script requires sudo privileges."
  exit 1
fi

if ! command -v certbot > /dev/null 2>&1; then
  echo "*** ERROR! This script requires certbot!"
  exit 1
fi

[ -f /etc/apache2/mods-enabled/ssl.load ] \
  || { echo "*** ERROR! Apache2 module ssl not enabled." ; exit 1; }
[ -f /etc/apache2/mods-enabled/proxy.load ] \
  || { echo "*** ERROR! Apache2 module proxy not enabled." ; exit 1; }
[ -f /etc/apache2/mods-enabled/proxy_fcgi.load ] \
  || { echo "*** ERROR! Apache2 module proxy_fcgi not enabled." ; exit 1; }


### Validate the user exists.

if id "$1" &>/dev/null; then
  echo "--- User '$1' found."
else
  echo "*** ERROR! User $1 not found. Please 'adduser' first."
  exit 1
fi


### Check that the hostnames are pointing to the server.

MYIP=$(hostname -I | cut -d " " -f1)
echo "--- My IP address is $MYIP. Comparing..."

additional_hostnames=""
letsencrypt_hostnames=""

for hostname in "${@:2}"; do
  validated_hostname=$(echo "$hostname" \
    | grep -P '(?=^.{5,254}$)(^(?:(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+(?:[a-zA-Z]{2,})$)')
  if [ -z "$validated_hostname" ]; then
    echo "*** ERROR! $hostname is not valid!"
    exit 1
  else
    ip_of_hostname=$(dig "$validated_hostname" +short)
    if [ "$MYIP" = "$ip_of_hostname" ]; then
      echo "  - $validated_hostname [$ip_of_hostname] OK"
      if [ "$letsencrypt_hostnames" = "" ]; then
        letsencrypt_hostnames=$(echo "$validated_hostname" | xargs)
      else
        additional_hostnames=$(echo "$additional_hostnames $validated_hostname" | xargs)
        letsencrypt_hostnames=$(echo "$letsencrypt_hostnames,$validated_hostname" | xargs)
      fi
    else
      echo "*** ERROR! $validated_hostname [$ip_of_hostname] not pointing to [$MYIP]"
    fi
  fi
done


### Validate the necessary services are running.

systemctl is-active --quiet "php$PHPVERSION-fpm" \
  || { echo "*** ERROR! service php$PHPVERSION-fpm not running." ; exit 1; }
systemctl is-active --quiet "apache2" \
  || { echo "*** ERROR! service apache2 not running." ; exit 1; }


### Create the webroot directory with correct permission.

mkdir -p "/var/www/$1/$2"
chown "$1:www-data" "/var/www/$1/$2"
chmod 750 "/var/www/$1/$2"


### Ensure common alias for LE HTTP-01 validation & get LE certificate.

echo "=== WRITING CONFIGURATION FILE /etc/apache2/conf-available/common-letsencrypt-path.conf ==="
cat <<'EOF' \
  | sed "s|WEBROOT|$LETSENCRYPT_WEBROOT|" \
  | tee "/etc/apache2/conf-available/common-letsencrypt-path.conf" \
  || { echo "*** ERROR! Unable to write /etc/apache2/conf-available/common-letsencrypt-path.conf" ; exit 1; }
<IfModule alias_module>
        Alias /.well-known/acme-challenge/ WEBROOT/.well-known/acme-challenge/
</IfModule>
EOF

echo "=== Enabling Let's Encrypt common webroot configuration ==="
a2enconf common-letsencrypt-path \
  || { echo "*** ERROR! Unable to enable common-letsencrypt-path.conf" ; exit 1; }
echo "--- Reloading Apache2."
systemctl reload apache2 \
  || { echo "*** ERROR! Unable to reload apache2" ; exit 1; }

echo "=== Getting a Let's Encrypt certificate with HTTP-01 challenge ==="
mkdir -p "$LETSENCRYPT_WEBROOT"
certbot certonly --noninteractive --agree-tos -d "$letsencrypt_hostnames" \
  --register-unsafely-without-email --webroot -w "$LETSENCRYPT_WEBROOT"


### Create configuration files.

echo "=== WRITING CONFIGURATION FILE /etc/php/$PHPVERSION/fpm/pool.d/$1.conf ==="

cat <<'EOF' \
  | sed "s/USERNAME/$1/" \
  | tee "/etc/php/$PHPVERSION/fpm/pool.d/$1.conf"
[USERNAME]
user = USERNAME
group = USERNAME

listen = /run/php/USERNAME.sock
chdir = /var/www/USERNAME

listen.owner = www-data
listen.group = www-data

pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3

php_admin_value[disable_functions] = exec,passthru,shell_exec
php_admin_flag[allow_url_fopen] = off
php_admin_value[cgi.fix_pathinfo] = 1

security.limit_extensions =
EOF

echo "=== WRITING CONFIGURATION FILE /etc/apache2/sites-enabled/$2.conf ==="

if [ "$additional_hostnames" = "" ]; then
  cat <<'EOF' \
    | sed "s/USERNAME/$1/" \
    | sed "s/MAINHOSTNAME/$2/" \
    | tee "/etc/apache2/sites-available/$2.conf"
<VirtualHost *:80>
        ServerName MAINHOSTNAME

        Redirect permanent / https://MAINHOSTNAME/
</VirtualHost>

<VirtualHost *:443>
        ServerName MAINHOSTNAME

        SSLEngine on
        SSLCertificateFile /etc/letsencrypt/live/MAINHOSTNAME/fullchain.pem
        SSLCertificateKeyFile /etc/letsencrypt/live/MAINHOSTNAME/privkey.pem
        SSLVerifyClient None

        DocumentRoot /var/www/USERNAME/MAINHOSTNAME

        <FilesMatch "\.php$">
                SetHandler  "proxy:unix:/run/php/USERNAME.sock|fcgi://localhost"
        </FilesMatch>
        <Proxy "fcgi://localhost/">
        </Proxy>

        <IfModule mod_headers.c>
                Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
        </IfModule>

        ErrorLog ${APACHE_LOG_DIR}/MAINHOSTNAME-error.log
        CustomLog ${APACHE_LOG_DIR}/MAINHOSTNAME-access.log combined
</VirtualHost>
EOF

else
  cat <<'EOF' \
    | sed "s/USERNAME/$1/" \
    | sed "s/MAINHOSTNAME/$2/" \
    | sed "s/ADDITIONALHOSTNAMES/$additional_hostnames/" \
    | tee "/etc/apache2/sites-available/$2.conf"
<VirtualHost *:80>
        ServerName MAINHOSTNAME
        ServerAlias ADDITIONALHOSTNAMES

        Redirect permanent / https://MAINHOSTNAME/
</VirtualHost>

<VirtualHost *:443>
        ServerName MAINHOSTNAME

        SSLEngine on
        SSLCertificateFile /etc/letsencrypt/live/MAINHOSTNAME/fullchain.pem
        SSLCertificateKeyFile /etc/letsencrypt/live/MAINHOSTNAME/privkey.pem
        SSLVerifyClient None

        DocumentRoot /var/www/USERNAME/MAINHOSTNAME

        <FilesMatch "\.php$">
                SetHandler  "proxy:unix:/run/php/USERNAME.sock|fcgi://localhost"
        </FilesMatch>
        <Proxy "fcgi://localhost/">
        </Proxy>

        <IfModule mod_headers.c>
                Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
        </IfModule>

        ErrorLog ${APACHE_LOG_DIR}/MAINHOSTNAME-error.log
        CustomLog ${APACHE_LOG_DIR}/MAINHOSTNAME-access.log combined
</VirtualHost>

<VirtualHost *:443>
        ServerName JUST4REDIR.MAINHOSTNAME
        ServerAlias ADDITIONALHOSTNAMES

        SSLEngine on
        SSLCertificateFile /etc/letsencrypt/live/MAINHOSTNAME/fullchain.pem
        SSLCertificateKeyFile /etc/letsencrypt/live/MAINHOSTNAME/privkey.pem
        SSLVerifyClient None

        Redirect permanent / https://MAINHOSTNAME/
</VirtualHost>
EOF

fi

echo "=== Enabling the site created ==="
systemctl reload "php$PHPVERSION-fpm" \
  || echo "*** ERROR! Unable to reload php$PHPVERSION-fpm"
a2ensite "$2" \
  || echo "*** ERROR! Unable to enable $2.conf"
echo "--- Reloading Apache2."
systemctl reload apache2 \
  || echo "*** ERROR! Unable to reload apache2"


### Commit changes with etckeeper if in use.

if command -v etckeeper > /dev/null 2>&1; then
  echo "--- Commit changes with etckeeper."
  etckeeper commit "$0 $*"
fi
