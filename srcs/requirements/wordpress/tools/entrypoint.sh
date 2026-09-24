set -e

until mysqladmin ping -h"${WORDPRESS_DB_HOST}" \
        -u"${WORDPRESS_DB_USER}" -p"${WORDPRESS_DB_PASSWORD}" --silent; do
    echo "[entrypoint] en attente de mariadb..."
    sleep 2
done

if [ ! -f /var/www/html/wp-config.php ]; then
    echo "[entrypoint] Telechargement de WordPress..."
    wp core download --allow-root

    echo "[entrypoint] Creation de wp-config.php..."
    wp config create \
        --dbname="${WORDPRESS_DB_NAME}" \
        --dbuser="${WORDPRESS_DB_USER}" \
        --dbpass="${WORDPRESS_DB_PASSWORD}" \
        --dbhost="${WORDPRESS_DB_HOST}" \
        --allow-root

    echo "[entrypoint] Installation du site et de l'administrateur..."
    wp core install \
        --url="${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root

    echo "[entrypoint] Creation du second utilisateur..."
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
        --user_pass="${WP_USER_PASSWORD}" \
        --role=author \
        --allow-root

    chown -R www-data:www-data /var/www/html
    echo "[entrypoint] Installation terminee."
fi

exec php-fpm8.2 -F