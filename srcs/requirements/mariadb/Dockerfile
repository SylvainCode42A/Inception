# Avant-dernière Debian stable
FROM debian:bookworm-slim

# update et install dans un seul RUN : séparés, Docker garderait le update
# en cache et installerait un jour contre un index de paquets périmé.
# mariadb-client fournit mysql et mysqladmin, dont l'entrypoint et le
# healthcheck du compose ont besoin.
RUN apt-get update && apt-get install -y mariadb-server mariadb-client

# La ligne la moins évidente du projet. Le paquet Debian initialise déjà
# une base pendant le build, dans l'image. Or Docker recopie le contenu
# d'un point de montage dans un volume vide au premier démarrage : sans ce
# rm, /var/lib/mysql ne serait jamais vide, le test de l'entrypoint
# [ ! -d /var/lib/mysql/mysql ] serait faux dès la première seconde, et le
# bloc d'initialisation ne tournerait jamais. Base absente, utilisateur
# absent, et WordPress bloqué à l'infini sur sa boucle d'attente.
RUN rm -rf /var/lib/mysql/*

# Les chemins sources sont relatifs au contexte de build, pas à la racine
# du dépôt. mariadb.conf.d est le dossier où MariaDB cherche ses confs ;
# /usr/local/bin est dans le $PATH, ce qui permet d'écrire l'ENTRYPOINT
# sans chemin absolu.
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

# Un fichier copié n'est pas exécutable par défaut. Et /run/mysqld est le
# dossier où MariaDB crée son fichier socket au démarrage : il ne sait pas
# le créer lui-même, donc sans ces deux lignes le serveur refuse de
# démarrer et le conteneur redémarre en boucle.
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p /run/mysqld \
    && chown -R mysql:mysql /run/mysqld

# EXPOSE n'ouvre rien : c'est de la documentation. Ce port n'est jamais
# publié vers l'hôte, il n'existe que dans le réseau inception.
EXPOSE 3306

# Désigne ce qui devient PID 1. Ici un script, parce qu'il y a de
# l'initialisation à faire avant de lancer le serveur définitif : créer la
# base, l'utilisateur, le mot de passe root. Le script se termine par un
# exec qui lui cède la place.
ENTRYPOINT ["entrypoint.sh"]