#!/bin/bash
# set -e : le script s'arrête à la première commande qui échoue, au lieu de
# continuer sur un état incohérent. Un conteneur qui meurt tout de suite est
# plus facile à diagnostiquer qu'un WordPress à moitié installé.
set -e

# 1. Attendre que mariadb réponde VRAIMENT.
#    Deuxième filet par-dessus le healthcheck du compose, et les deux ne
#    testent pas la même chose : le healthcheck vérifie que le serveur
#    répond, cette boucle vérifie en plus que l'utilisateur WordPress peut
#    s'authentifier — ce qui n'est vrai qu'une fois le bloc SQL de
#    l'entrypoint mariadb terminé. Le -h est un nom de conteneur, résolu
#    par le DNS du réseau bridge : aucune IP écrite nulle part.
until mysqladmin ping -h"${WORDPRESS_DB_HOST}" \
        -u"${WORDPRESS_DB_USER}" -p"${WORDPRESS_DB_PASSWORD}" --silent; do
    echo "[entrypoint] en attente de mariadb..."
    sleep 2
done

# 2. Installation UNE SEULE FOIS.
#    wp-config.php est le premier fichier que WordPress ne peut pas avoir
#    sans être configuré : son absence signifie volume wp_data vide, donc
#    premier lancement. Aux démarrages suivants tout ce bloc est sauté et
#    le site existant est conservé. Noter le -f : on teste un FICHIER,
#    là où mariadb teste un dossier avec -d.
if [ ! -f /var/www/html/wp-config.php ]; then
    # Télécharge le cœur de WordPress dans le répertoire courant, défini
    # par le WORKDIR du Dockerfile. Cette commande s'exécute au DÉMARRAGE
    # et pas au build : la VM a donc besoin d'internet au premier make.
    echo "[entrypoint] Telechargement de WordPress..."
    wp core download --allow-root

    # Génère wp-config.php à partir des variables du .env. Ces quatre
    # options sont exactement ce qu'il faut pour ouvrir une connexion :
    # quelle base, quel compte, quel mot de passe, sur quelle machine.
    echo "[entrypoint] Creation de wp-config.php..."
    wp config create \
        --dbname="${WORDPRESS_DB_NAME}" \
        --dbuser="${WORDPRESS_DB_USER}" \
        --dbpass="${WORDPRESS_DB_PASSWORD}" \
        --dbhost="${WORDPRESS_DB_HOST}" \
        --allow-root

    # Crée les tables dans MariaDB et l'administrateur. C'est WP-CLI qui
    # génère le SQL : aucun CREATE TABLE écrit à la main. --skip-email
    # évite un envoi de mail de bienvenue, qui échouerait faute de SMTP.
    echo "[entrypoint] Installation du site et de l'administrateur..."
    wp core install \
        --url="${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root

    # Le second utilisateur exigé par le sujet. --role=author est la seule
    # ligne qui le distingue de l'administrateur : il publie ses propres
    # articles mais ne touche ni aux réglages ni aux autres comptes.
    echo "[entrypoint] Creation du second utilisateur..."
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
        --user_pass="${WP_USER_PASSWORD}" \
        --role=author \
        --allow-root

    # Répété ici et pas seulement dans le Dockerfile : ces fichiers
    # viennent d'être créés au runtime, en root, dans le volume. Sans ce
    # chown, php-fpm qui tourne en www-data ne pourrait pas écrire dans
    # wp-content/uploads.
    chown -R www-data:www-data /var/www/html
    echo "[entrypoint] Installation terminee."
fi

# 3. exec remplace le shell au lieu de créer un processus : php-fpm hérite
#    du PID 1, donc il reçoit directement le SIGTERM de docker stop.
#    -F (foreground) l'empêche de se démoniser — sinon le script rendrait
#    la main, se terminerait, et le conteneur s'arrêterait aussitôt.
#    C'est l'équivalent du daemon off de nginx.
exec php-fpm8.2 -F