# Avant-dernière Debian stable
FROM debian:bookworm-slim

# php-mysql fournit l'extension mysqli, sans laquelle WordPress refuse de
# démarrer. mariadb-client n'est là que pour le mysqladmin ping de la boucle
# d'attente — aucun serveur ici. ca-certificates permet à curl de valider
# le certificat de GitHub à la ligne suivante.
RUN apt-get update && apt-get install -y --no-install-recommends \
    php-fpm \
    php-mysql \
    php-gd \
    php-curl \
    php-xml \
    php-mbstring \
    php-zip \
    mariadb-client \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# WP-CLI n'existe pas comme paquet Debian : on télécharge le .phar, on le
# rend exécutable et on le pose dans le $PATH. Même schéma que l'install
# de docker compose et buildx dans la VM.
RUN curl -sSLo /usr/local/bin/wp \
    https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

# La version 8.2 est écrite en dur ici et dans le exec de l'entrypoint.
# C'est le point fragile du projet : si Debian en installait une autre, la
# conf atterrirait dans un dossier inexistant et php-fpm garderait ses
# réglages par défaut — donc un socket Unix, donc 502 sur toutes les pages.
# À vérifier au premier lancement : docker exec -it wordpress ls /etc/php/
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

# Un fichier copié n'est pas exécutable par défaut. /run/php est le dossier
# d'exécution de php-fpm, l'équivalent du /run/mysqld de mariadb. Et les
# fichiers doivent appartenir à www-data, l'utilisateur sous lequel
# tourneront les processus enfants.
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p /run/php /var/www/html \
    && chown -R www-data:www-data /var/www/html

# Définit le répertoire courant dans le conteneur. C'est ce qui permet aux
# commandes wp de l'entrypoint de fonctionner sans --path=.
WORKDIR /var/www/html

# EXPOSE n'ouvre rien : c'est de la documentation. Ce port n'est jamais
# publié vers l'hôte, il n'existe que dans le réseau inception.
EXPOSE 9000

# Désigne ce qui devient PID 1. Ici un script, parce qu'il y a de
# l'initialisation à faire avant de lancer le service : attendre mariadb,
# télécharger WordPress, l'installer. Le script se termine par un exec qui
# lui cède la place.
ENTRYPOINT ["entrypoint.sh"]