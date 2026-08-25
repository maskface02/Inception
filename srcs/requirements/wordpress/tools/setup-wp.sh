#!/bin/sh

if [ ! -f /var/www/html/wp-config.php ]; then
    echo "Downloading WordPress..."

    wget -q https://wordpress.org/latest.tar.gz -O /tmp/wp.tar.gz
    tar -xzf /tmp/wp.tar.gz -C /tmp
    cp -r /tmp/wordpress/* /var/www/html/
    rm -rf /tmp/wp.tar.gz /tmp/wordpress

    DB_PASSWORD=$(cat "$WORDPRESS_DB_PASSWORD_FILE")

    cat > /var/www/html/wp-config.php << EOF
<?php
define('DB_NAME', '${WORDPRESS_DB_NAME}');
define('DB_USER', '${WORDPRESS_DB_USER}');
define('DB_PASSWORD', '${DB_PASSWORD}');
define('DB_HOST', '${WORDPRESS_DB_HOST}');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

$(wget -q -O - https://api.wordpress.org/secret-key/1.1/salt/)

\$table_prefix = 'wp_';

define('WP_DEBUG', false);

if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}

require_once ABSPATH . 'wp-settings.php';
EOF

    chown -R nobody:nobody /var/www/html
fi

echo "Waiting for MariaDB to be ready..."
until mysqladmin ping -h"${WORDPRESS_DB_HOST}" -u"${WORDPRESS_DB_USER}" -p"$(cat "$WORDPRESS_DB_PASSWORD_FILE")" --silent 2>/dev/null; do
    sleep 2
done
echo "MariaDB is ready."

if [ ! -f /var/www/html/.installed ]; then
    echo "Installing WordPress..."

    wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/local/bin/wp
    chmod +x /usr/local/bin/wp

    wp core install --allow-root \
        --url="${DOMAIN_NAME}" \
        --title="Inception" \
        --admin_user="${WORDPRESS_ADMIN_USER}" \
        --admin_password="$(cat "$WORDPRESS_ADMIN_PASSWORD_FILE")" \
        --admin_email="${WORDPRESS_ADMIN_EMAIL}" \
        --path=/var/www/html

    wp user create --allow-root \
        "${WORDPRESS_USER}" \
        "${WORDPRESS_USER_EMAIL}" \
        --user_pass="$(cat "$WORDPRESS_USER_PASSWORD_FILE")" \
        --path=/var/www/html

    touch /var/www/html/.installed
    echo "WordPress installed successfully."
fi

exec php-fpm83 -F
