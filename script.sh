#! /bin/bash

# Variables
LOGGING_AGENT_VERSION="1.8.6"
MONITORING_AGENT_VERSION="6.1.2"
PHP_VERSION="7.4"
DRUPAL_VERSION="9.2.7"
SUPERVISOR_VERSION="4.2.2"
COMPOSER_VERSION="2.1.8"
APIGEE_SCRIPTS_PATH="/opt/apigee/scripts"

# Prerequisite
sudo dnf clean all
sudo yum upgrade -y
sudo dnf upgrade -y

# Security
sudo setenforce 0
sudo setsebool -P httpd_can_network_connect 1
sudo setsebool -P httpd_unified 1


REQPKGS=(git zip unzip wget yum-utils jq httpd-tools)

for pkg in "${REQPKGS[@]}"; do
    until rpm -qa | grep "$pkg"
    do 
        sudo yum install "$pkg" -y && echo "Successfully installed $pkg"
    done
done

# Install Cloud SQL Proxy
sudo mkdir /opt/apigee
sudo wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O /opt/apigee/cloud_sql_proxy
sudo chmod +x /opt/apigee/cloud_sql_proxy

# Install Cloud Logging Agent
sudo curl -sSO https://dl.google.com/cloudagents/add-logging-agent-repo.sh
sudo chmod +x add-logging-agent-repo.sh
sudo bash add-logging-agent-repo.sh --also-install --version=${LOGGING_AGENT_VERSION}
sudo rm -rf add-logging-agent-repo.sh

# Install Cloud Monitoring Agent
sudo curl -sSO https://dl.google.com/cloudagents/add-monitoring-agent-repo.sh
sudo chmod +x add-monitoring-agent-repo.sh 
sudo bash add-monitoring-agent-repo.sh --also-install --version=${MONITORING_AGENT_VERSION}
sudo rm -rf add-monitoring-agent-repo.sh 
sudo sed -i -e '34s/^/#/' /etc/stackdriver/collectd.conf
sudo sed -i -e '35s/^/#/' /etc/stackdriver/collectd.conf
sudo sed -i -e '36s/^/#/' /etc/stackdriver/collectd.conf
sudo sed -i -e '37s/^/#/' /etc/stackdriver/collectd.conf

# Install Supervisor 4.2.2
sudo pip3 install supervisor
sudo mkdir -p /etc/supervisor/conf.d
sudo mkdir /var/log/supervisor
cat << EOT2 >> /tmp/supervisord.conf
; supervisor config file

[unix_http_server]
file=/var/run/supervisor.sock   ; (the path to the socket file)
chmod=0700                       ; sockef file mode (default 0700)

[supervisord]
logfile=/var/log/supervisor/supervisord.log ; (main log file;default $CWD/supervisord.log)
pidfile=/var/run/supervisord.pid ; (supervisord pidfile;default supervisord.pid)
childlogdir=/var/log/supervisor            ; ('AUTO' child log dir, default $TEMP)

; the below section must remain in the config file for RPC
; (supervisorctl/web interface) to work, additional interfaces may be
; added by defining them in separate rpcinterface: sections
[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock ; use a unix:// URL  for a unix socket

; The [include] section can just contain the "files" setting.  This
; setting can list multiple files (separated by whitespace or
; newlines).  It can also contain wildcards.  The filenames are
; interpreted as relative to this file.  Included files *cannot*
; include files themselves.

[include]
files = /etc/supervisor/conf.d/*.conf
EOT2
sudo mv /tmp/supervisord.conf /etc/supervisor/supervisord.conf
cat << EOT3 >> /tmp/apigee-supervisor.conf
[program:php-fpm]
command = /usr/sbin/php-fpm -F
stdout_logfile = stdout
stdout_logfile_maxbytes=0
stderr_logfile = stderr
stderr_logfile_maxbytes=0
user = root
autostart = true
autorestart = true
priority = 5

[program:nginx]
command = /usr/sbin/nginx -g "daemon off;"
stdout_logfile = stdout
stdout_logfile_maxbytes=0
stderr_logfile = stderr
stderr_logfile_maxbytes=0
user = root
autostart = true
autorestart = true
priority = 10

[program:cloudsqlproxy]
command = /opt/apigee/scripts/start-cloudsql.sh
stdout_logfile = stdout
stdout_logfile_maxbytes=0
stderr_logfile = stderr
stderr_logfile_maxbytes=0
user = root
autostart = true
autorestart = true
priority = 10
EOT3
sudo mv /tmp/apigee-supervisor.conf /etc/supervisor/conf.d/apigee-supervisor.conf
cat << "EOT16" >> /tmp/supervisor.service
[Unit]
Description=Supervisor process control system for UNIX
Documentation=http://supervisord.org
After=network.target

[Service]
ExecStart=/usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
ExecStop=/usr/bin/supervisorctl $OPTIONS shutdown
ExecReload=/usr/bin/supervisorctl -c /etc/supervisor/supervisord.conf $OPTIONS reload
KillMode=process
Restart=on-failure
RestartSec=50s

[Install]
WantedBy=multi-user.target
EOT16
sudo mv /tmp/supervisor.service /lib/systemd/system/supervisor.service

# Install MySQL Client
sudo yum install mysql -y

# Install PHP 7.4
sudo dnf module reset php
sudo dnf module install php:${PHP_VERSION} -y
sudo dnf install -y php-{fpm,cli,mysqlnd,json,opcache,xml,mbstring,gd,curl,bcmath}
sudo sed -i -e 's/^user = apache/user = nginx/' -e 's/^group = apache/group = nginx/' /etc/php-fpm.d/www.conf
sudo systemctl enable --now php-fpm

# Install Composer
sudo wget https://getcomposer.org/download/2.1.8/composer.phar
sudo php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
sudo php -r "if (hash_file('sha384', 'composer-setup.php') === '906a84df04cea2aa72f40b5f787e49f22d4c2f19492ac310e8cba5b96ac8b64115ac402c8cd292b8a03482574915d1a8') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php composer-setup.php
sudo php -r "unlink('composer-setup.php');"
sudo mv composer.phar /usr/bin/composer

# Install Drush
composer require drush/drush
sudo wget -O drush.phar https://github.com/drush-ops/drush-launcher/releases/download/0.6.0/drush.phar
sudo chmod +x drush.phar
sudo mv drush.phar /usr/bin/drush

# Install Nginx 1.14
sudo yum install nginx git -y
sudo systemctl enable --now nginx
sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
cat << EOT6 >> /tmp/nginx.conf
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
        worker_connections 768;
        # multi_accept on;
}

http {
        ##
        # Basic Settings
        ##

        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout   65;
        types_hash_max_size 2048;
        # server_tokens off;

        # server_names_hash_bucket_size 64;
        # server_name_in_redirect off;

        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        ##
        # SSL Settings
        ##

        ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
        ssl_prefer_server_ciphers on;

        ##
        # Logging Settings
        ##

        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;

        ##
        # Gzip Settings
        ##

        gzip on;

        # gzip_vary on;
        # gzip_proxied any;
        # gzip_comp_level 6;
        # gzip_buffers 16 8k;
        # gzip_http_version 1.1;
        # gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;


        ##
        # Virtual Host Configs
        ##
        include /etc/nginx/conf.d/*.conf;
        include /etc/nginx/sites-enabled/*;
}
#mail {
#       # See sample authentication script at:
#       # http://wiki.nginx.org/ImapAuthenticateWithApachePhpScript
#
#       # auth_http localhost/auth.php;
#       # pop3_capabilities "TOP" "USER";
#       # imap_capabilities "IMAP4rev1" "UIDPLUS";
#
#       server {
#               listen     localhost:110;
#               protocol   pop3;
#               proxy      on;
#       }
#
#       server {
#               listen     localhost:143;
#               protocol   imap;
#               proxy      on;
#       }
#}
EOT6
sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf
sudo mkdir /etc/nginx/sites-enabled
cat << EOT7 >> /tmp/drupal-nginx.conf
server {
    listen 80;
    listen [::]:80;

    include /opt/apigee/scripts/nginx-basic-auth.conf;
    include /opt/apigee/scripts/drupal-common.conf;
}

# server {
#     listen 443 ssl;
#     listen [::]:443 ssl;

#     ssl_certificate     /etc/nginx/ssl/nginx.crt;
#     ssl_certificate_key /etc/nginx/ssl/nginx.key;

#     include /opt/apigee/scripts/nginx-basic-auth.conf;
#     include /opt/apigee/scripts/drupal-common.conf;
# }
EOT7
sudo mv /tmp/drupal-nginx.conf /etc/nginx/sites-enabled/drupal-nginx.conf
sudo mkdir -p /var/www/html

# Install Drupal 9
sudo mkdir /var/www/devportal
cd /var/www/devportal
sudo composer create-project apigee/devportal-kickstart-project:9.x-dev code --no-interaction

# Create Apigee Scripts
sudo mkdir -p ${APIGEE_SCRIPTS_PATH}
cat << "EOT4" >> /tmp/copy-settings-php.sh
#!/bin/bash

BASEDIR=$(dirname $(realpath "$0"))
set -x;

# Copy over the settings.php files
cp -f /var/www/devportal/code/web/sites/default/default.settings.php /var/www/devportal/code/web/sites/default/settings.php

cp /opt/apigee/scripts/solution-settings.php.txt /tmp/solution-settings.php.txt
ACCESS_TOKEN=$(curl --noproxy google.internal 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' -H "Metadata-Flavor: Google" | jq .access_token)
PORTAL_RUNTIME_CONFIG_URL=$(curl --noproxy google.internal 'http://metadata.google.internal/computeMetadata/v1/instance/attributes/PORTAL_RUNTIME_CONFIG' -H "Metadata-Flavor: Google")
PORTAL_DB_NAME=$(curl "https://runtimeconfig.googleapis.com/v1beta1/$PORTAL_RUNTIME_CONFIG_URL/variables/db/name" -H "Authorization:Bearer $ACCESS_TOKEN" | jq .text )
sed -i "s/__PORTAL_DB_NAME__/$PORTAL_DB_NAME/g"  /tmp/solution-settings.php.txt
PORTAL_DB_USERNAME=$(curl "https://runtimeconfig.googleapis.com/v1beta1/$PORTAL_RUNTIME_CONFIG_URL/variables/db/username" -H "Authorization:Bearer $ACCESS_TOKEN" | jq .text )
sed -i "s/__PORTAL_DB_USERNAME__/$PORTAL_DB_USERNAME/g"  /tmp/solution-settings.php.txt
PORTAL_DB_PASSWORD=$(curl "https://runtimeconfig.googleapis.com/v1beta1/$PORTAL_RUNTIME_CONFIG_URL/variables/db/password" -H "Authorization:Bearer $ACCESS_TOKEN" | jq .text )
sed -i "s/__PORTAL_DB_PASSWORD__/$PORTAL_DB_PASSWORD/g"  /tmp/solution-settings.php.txt
PORTAL_NAME=$(curl --noproxy google.internal -f http://metadata.google.internal/computeMetadata/v1/instance/attributes/PORTAL_NAME -H "Metadata-Flavor: Google")
sed -i "s/__PORTAL_NAME__/$PORTAL_NAME/g"  /tmp/solution-settings.php.txt

cat /tmp/solution-settings.php.txt >> /var/www/devportal/code/web/sites/default/settings.php

rm /tmp/solution-settings.php.txt

chown -R nginx:nginx /var/www/devportal/code/web/sites/default/settings.php
chmod 660 /var/www/devportal/code/web/sites/default/settings.php
EOT4
sudo mv /tmp/copy-settings-php.sh ${APIGEE_SCRIPTS_PATH}/copy-settings-php.sh
cat << "EOT5" >> /tmp/start-cloudsql.sh
#!/bin/bash
INSTANCE_CONNECTION_NAME=$(curl --noproxy google.internal -f http://metadata.google.internal/computeMetadata/v1/instance/attributes/CLOUDSQL_INSTANCE_CONNECTION_NAME -H "Metadata-Flavor: Google")

/opt/apigee/cloud_sql_proxy -instances=$INSTANCE_CONNECTION_NAME=tcp:3306
EOT5
sudo mv /tmp/start-cloudsql.sh ${APIGEE_SCRIPTS_PATH}/start-cloudsql.sh
cat << "EOT8" >> /tmp/drupal-common.conf
    root /var/www/devportal/code/web; ## <-- Your only path reference.

    location = /health-check {
       auth_basic off;
       access_log off;
       return 200 'ok';
    }

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    # Very rarely should these ever be accessed outside of your lan
    location ~* \.(txt|log)$ {
        allow 192.168.0.0/16;
        deny all;
    }

    location ~ \..*/.*\.php$ {
        return 403;
    }

    location ~ ^/sites/.*/private/ {
        return 403;
    }

    # Block access to scripts in site files directory
    location ~ ^/sites/[^/]+/files/.*\.php$ {
        deny all;
    }

    # Allow "Well-Known URIs" as per RFC 5785
    location ~* ^/.well-known/ {
        allow all;
    }

    # Block access to "hidden" files and directories whose names begin with a
    # period. This includes directories used by version control systems such
    # as Subversion or Git to store control files.
    location ~ (^|/)\. {
        return 403;
    }

    location / {
        # try_files $uri @rewrite; # For Drupal <= 6
        try_files $uri /index.php?$query_string; # For Drupal >= 7
    }

    location @rewrite {
        #rewrite ^/(.*)$ /index.php?q=$1; # For Drupal <= 6
        rewrite ^ /index.php; # For Drupal >= 7
    }

    # Don't allow direct access to PHP files in the vendor directory.
    location ~ /vendor/.*\.php$ {
        deny all;
        return 404;
    }

    # Protect files and directories from prying eyes.
    location ~* \.(engine|inc|install|make|module|profile|po|sh|.*sql|theme|twig|tpl(\.php)?|xtmpl|yml)(~|\.sw[op]|\.bak|\.orig|\.save)?$|/(\.(?!well-known).*)|Entries.*|Repository|Root|Tag|Template|composer\.(json|lock)|web\.config$|/#.*#$|\.php(~|\.sw[op]|\.bak|\.orig|\.save)$ {
        deny all;
        return 404;
    }

    # In Drupal 8, we must also match new paths where the '.php' appears in
    # the middle, such as update.php/selection. The rule we use is strict,
    # and only allows this pattern with the update.php front controller.
    # This allows legacy path aliases in the form of
    # blog/index.php/legacy-path to continue to route to Drupal nodes. If
    # you do not have any paths like that, then you might prefer to use a
    # laxer rule, such as:
    #   location ~ \.php(/|$) {
    # The laxer rule will continue to work if Drupal uses this new URL
    # pattern with front controllers other than update.php in a future
    # release.
    location ~ '\.php$|^/update.php' {
        fastcgi_split_path_info ^(.+?\.php)(|/.*)$;
        # Ensure the php file exists. Mitigates CVE-2019-11043
        try_files $fastcgi_script_name =404;
        # Security note: If you're running a version of PHP older than the
        # latest 5.3, you should have "cgi.fix_pathinfo = 0;" in php.ini.
        # See http://serverfault.com/q/627903/94922 for details.
        include fastcgi_params;
        # Block httpoxy attacks. See https://httpoxy.org/.
        fastcgi_param HTTP_PROXY "";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_param QUERY_STRING $query_string;
        fastcgi_intercept_errors on;
        # PHP 5 socket location.
        #fastcgi_pass unix:/var/run/php5-fpm.sock;
        # PHP 7 socket location.
        #fastcgi_pass 127.0.0.1:9000;
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_read_timeout 300;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        try_files $uri @rewrite;
        expires max;
        log_not_found off;
    }

    # Fighting with Styles? This little gem is amazing.
    # location ~ ^/sites/.*/files/imagecache/ { # For Drupal <= 6
    location ~ ^/sites/.*/files/styles/ { # For Drupal >= 7
        try_files $uri @rewrite;
    }

    # Handle private files through Drupal. Private file's path can come
    # with a language prefix.
    location ~ ^(/[a-z\-]+)?/system/files/ { # For Drupal >= 7
        try_files $uri /index.php?$query_string;
    }

    # Enforce clean URLs
    # Removes index.php from urls like www.example.com/index.php/my-page --> www.example.com/my-page
    # Could be done with 301 for permanent or other redirect codes.
    if ($request_uri ~* "^(.*/)index\.php/(.*)") {
        return 307 $1$2;
    }
EOT8
sudo mv /tmp/drupal-common.conf ${APIGEE_SCRIPTS_PATH}/drupal-common.conf
cat << "EOT9" >> /tmp/export-code.sh
#!/bin/bash
PORTAL_NAME=$(curl --noproxy google.internal -f http://metadata.google.internal/computeMetadata/v1/instance/attributes/PORTAL_NAME -H "Metadata-Flavor: Google")
mkdir -p /mnt/fileshare/$PORTAL_NAME
cd /var/www/devportal/
tar -czf /mnt/fileshare/$PORTAL_NAME/portal-code.tar.gz code
EOT9
sudo mv /tmp/export-code.sh ${APIGEE_SCRIPTS_PATH}/export-code.sh
cat << "EOT10" >> /tmp/fix-code-permissions.sh
#!/bin/bash
BASEDIR=$(dirname $(realpath "$0"))
set -x;
(find /var/www/devportal/code -type d -name ".git" && find /var/www/devportal/code -name ".gitignore" && find /var/www/devportal/code -name ".gitmodules")  | xargs rm -rf
cd /var/www/devportal/code/
chown -R nginx:nginx .
find . -type d -exec chmod u=rwx,g=rx,o= '{}' \;
find . -type f -exec chmod u=rw,g=r,o= '{}' \;

# Need to be able to run Drush command
cd /var/www/devportal/code/vendor
chown -R nginx:nginx .
find . -type d -exec chmod u=rwx,g=rx,o=rx '{}' \;
find . -type f -exec chmod u=rwx,g=rx,o=rx '{}' \;
EOT10
sudo mv /tmp/fix-code-permissions.sh ${APIGEE_SCRIPTS_PATH}/fix-code-permissions.sh
cat << "EOT11" >> /tmp/fix-file-permissions.sh
#!/bin/bash

BASEDIR=$(dirname $(realpath "$0"))
set -x;

# Unlink existing sites/default/files directory
rm -rf /var/www/devportal/code/web/sites/default/files

# Create directories if they don't exist
mkdir -p /var/www/devportal/files/public \
        /var/www/devportal/files/private \
        /var/www/devportal/files/temp \
        /var/www/devportal/files/config

# link the public files directory in the webroot
ln -sf /var/www/devportal/files/public /var/www/devportal/code/web/sites/default/files

cd /var/www/devportal/files/
chown -R nginx:nginx .
find . -type d -exec chmod ug=rwx,o= '{}' \;
find . -type f -exec chmod ug=rw,o= '{}' \;

cd /var/www/devportal/code/web/sites/default
chown -R nginx:nginx .
find . -type d -exec chmod ug=rwx,o= '{}' \;
find . -type f -exec chmod ug=rw,o= '{}' \;
EOT11
sudo mv /tmp/fix-file-permissions.sh ${APIGEE_SCRIPTS_PATH}/fix-file-permissions.sh
cat << "EOT12" >> /tmp/setup-basic-auth.sh
#!/bin/bash

#protect the site with Basic Auth
ACCESS_TOKEN=$(curl --noproxy google.internal 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token' -H "Metadata-Flavor: Google" | jq .access_token)
PORTAL_RUNTIME_CONFIG_URL=$(curl --noproxy google.internal 'http://metadata.google.internal/computeMetadata/v1/instance/attributes/PORTAL_RUNTIME_CONFIG' -H "Metadata-Flavor: Google")
BASICAUTH_ENABLED=$(curl "https://runtimeconfig.googleapis.com/v1beta1/$PORTAL_RUNTIME_CONFIG_URL/variables/site_basic_auth/enabled" -H "Authorization:Bearer $ACCESS_TOKEN" | jq -r .value | base64 -d )
BASICAUTH_USER=$(curl "https://runtimeconfig.googleapis.com/v1beta1/$PORTAL_RUNTIME_CONFIG_URL/variables/site_basic_auth/user" -H "Authorization:Bearer $ACCESS_TOKEN" | jq -r .value | base64 -d )
BASICAUTH_PASSWD=$(curl "https://runtimeconfig.googleapis.com/v1beta1/$PORTAL_RUNTIME_CONFIG_URL/variables/site_basic_auth/password" -H "Authorization:Bearer $ACCESS_TOKEN" | jq -r .value | base64 -d )

echo "BASICAUTH_ENABLED = '$BASICAUTH_ENABLED'";

if [ "$BASICAUTH_ENABLED" == "1" ]; then
  htpasswd  -b -c /etc/nginx/.htpasswd $BASICAUTH_USER $BASICAUTH_PASSWD
  echo "auth_basic \"This site is protected.\";" > /opt/apigee/scripts/nginx-basic-auth.conf
  echo "auth_basic_user_file /etc/nginx/.htpasswd;" >> /opt/apigee/scripts/nginx-basic-auth.conf
else
  echo "auth_basic off;" > /opt/apigee/scripts/nginx-basic-auth.conf
fi
EOT12
sudo mv /tmp/setup-basic-auth.sh ${APIGEE_SCRIPTS_PATH}/setup-basic-auth.sh
sudo cat << "EOT13" >> /tmp/solution-settings.php.txt
$databases['default']['default'] = [
    'database' => __PORTAL_DB_NAME__,
    'username' => __PORTAL_DB_USERNAME__,
    'password' => __PORTAL_DB_PASSWORD__,
    'host' => '127.0.0.1',
    'port' => '3306',
    'driver' => 'mysql',
];

$settings['config_sync_directory'] = "/var/www/devportal/files/config";
$settings['update_free_access'] = FALSE;
$settings['allow_authorize_operations'] = FALSE;
$settings['file_public_path'] = 'sites/default/files';
$settings['file_private_path'] = '/var/www/devportal/files/private';
$settings['file_temp_path'] = '/var/www/devportal/files/temp';


$salt_file = $settings['file_private_path'] ."/salt.txt";
if(!file_exists($salt_file)) {
    file_put_contents($salt_file, \Drupal\Component\Utility\Crypt::randomBytesBase64(55));
}
$settings['hash_salt'] = file_get_contents($salt_file);

if(file_exists('/mnt/fileshare/__PORTAL_NAME__/settings.custom.php')) {
    include '/mnt/fileshare/__PORTAL_NAME__/settings.custom.php';
}
EOT13
sudo mv /tmp/solution-settings.php.txt ${APIGEE_SCRIPTS_PATH}/solution-settings.php.txt
cat << "EOT14" >> /tmp/update-drupal.sh
#!/bin/bash
BASEDIR=$(dirname $(realpath "$0"))
echo "$BASEDIR"

php -d memory_limit=2G /usr/local/bin/composer update --with-dependencies -o --working-dir=/var/www/devportal/code --no-interaction

$BASEDIR/fix-code-permissions.sh
$BASEDIR/copy-settings-php.sh
$BASEDIR/fix-file-permissions.sh

$BASEDIR/export-code.sh

drush updb -y
EOT14
sudo mv /tmp/update-drupal.sh ${APIGEE_SCRIPTS_PATH}/update-drupal.sh
cat << EOT15 >> /tmp/nginx-basic-auth.conf
auth_basic "This site is protected.";
auth_basic_user_file /etc/nginx/.htpasswd;
EOT15
sudo mv /tmp/nginx-basic-auth.conf ${APIGEE_SCRIPTS_PATH}/nginx-basic-auth.conf

# Apigee Startup Script
cat << "EOT1" >> /tmp/startup.sh
#!/bin/bash
BASEDIR=$(dirname $(realpath "$0"))
echo "$BASEDIR"
set -x;

#Create dummy SSL certs for getting around gcp restriction for now.
#mkdir -p /etc/nginx/ssl
#openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
#-subj "/CN=$(hostname -i)" \
#-keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt
#chmod -R 600 /etc/nginx/ssl

#setup basic auth to protect the site
$BASEDIR/setup-basic-auth.sh

# Start the Cloud Monitoring agent
service stackdriver-agent restart

# Start the Cloud Logging agent
service google-fluentd restart

# Restart the supervisor service for nginx to pickup new certs
service supervisor restart

#Mount the filestore share
FILESTORE=$(curl --noproxy google.internal -f http://metadata.google.internal/computeMetadata/v1/instance/attributes/PORTAL_FILESTORE -H "Metadata-Flavor: Google")
mkdir -p /mnt/fileshare /var/www/devportal/
mount $FILESTORE /mnt/fileshare
chmod go+rw /mnt/fileshare

PORTAL_NAME=$(curl --noproxy google.internal -f http://metadata.google.internal/computeMetadata/v1/instance/attributes/PORTAL_NAME -H "Metadata-Flavor: Google")

# create file directory on the fileshare
mkdir -p /mnt/fileshare/$PORTAL_NAME/files
chcon -t httpd_sys_content_t -R /mnt/fileshare/$PORTAL_NAME/files


if [ -f "/mnt/fileshare/$PORTAL_NAME/portal-code.tar.gz" ]
then
  rm -rf /var/www/devportal/*
  #Extract previously exported code
  tar -xzf /mnt/fileshare/$PORTAL_NAME/portal-code.tar.gz -C /var/www/devportal/
  $BASEDIR/fix-code-permissions.sh
fi

#setup the files folders
ln -sf  /mnt/fileshare/$PORTAL_NAME/files /var/www/devportal/files

$BASEDIR/copy-settings-php.sh

#Fix permissions of files
$BASEDIR/fix-file-permissions.sh

drush updb -y || true
drush cr || true

if [ -f "/mnt/fileshare/$PORTAL_NAME/custom-startup-script.sh" ]
then
  /mnt/fileshare/$PORTAL_NAME/custom-startup-script.sh
fi

# Restart Nginx
service nginx restart

EOT1
sudo mv /tmp/startup.sh ${APIGEE_SCRIPTS_PATH}/startup.sh

# Make all scripts executable
sudo chmod +x ${APIGEE_SCRIPTS_PATH}/*