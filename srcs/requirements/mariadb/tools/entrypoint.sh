#!/bin/bash
# set -e : le script s'arrête à la première commande qui échoue, au lieu de
# poursuivre l'initialisation sur une base à moitié créée.
set -e

# MariaDB pose un problème d'œuf et de poule : créer une base exige un
# serveur démarré, mais le serveur définitif ne doit s'ouvrir qu'une fois
# tout configuré. Ce script le résout en trois temps.

# 1. Premier lancement ?
#    /var/lib/mysql/mysql est la base système interne de MariaDB : elle
#    n'existe qu'après une vraie initialisation. Si elle est là, tout le
#    bloc est sauté et les données existantes sont réutilisées — sans ce
#    test, chaque redémarrage écraserait le site. C'est aussi pourquoi le
#    Dockerfile fait un rm -rf /var/lib/mysql/* : le paquet Debian remplit
#    ce dossier au build, et Docker recopie le contenu d'un point de
#    montage dans un volume vide au premier démarrage. Sans ce rm, le test
#    serait faux dès la première seconde et ce bloc ne tournerait jamais.
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "[entrypoint] Premiere initialisation de la base..."
    # Pose les fichiers de base — c'est ce qui crée /var/lib/mysql/mysql.
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null

    # 2. Serveur TEMPORAIRE, en arrière-plan (&) et coupé du réseau
    #    (--skip-networking), le temps d'envoyer le SQL. Personne ne peut
    #    s'y connecter pendant que le mot de passe root n'est pas encore
    #    posé : c'est une mesure de sécurité, pas un détail.
    mysqld --user=mysql --datadir=/var/lib/mysql --skip-networking &
    pid="$!"   # PID du dernier processus lancé en fond, gardé pour le wait

    # Lancer un processus ne veut pas dire qu'il est prêt : on attend qu'il
    # réponde vraiment. Même logique que le healthcheck du compose et que
    # la boucle until de l'entrypoint wordpress.
    until mysqladmin ping --silent; do
        sleep 1
    done

    # Le @'%' autorise wordpress à se connecter depuis un autre conteneur :
    # en MariaDB un compte est le couple nom + hôte d'origine, donc
    # 'user'@'localhost' et 'user'@'%' sont deux comptes différents, et le
    # premier refuserait une connexion venue d'une autre IP du réseau.
    # IF NOT EXISTS rend le bloc idempotent : le rejouer ne casse rien.
    mysql -u root <<-EOSQL
        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
        GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
        FLUSH PRIVILEGES;
EOSQL

    # Arrêt propre du serveur temporaire, puis wait pour qu'il soit
    # RÉELLEMENT terminé : sans ça, le serveur définitif pourrait démarrer
    # pendant que l'ancien écrit encore, et deux processus sur les mêmes
    # fichiers corrompent la base.
    mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown
    wait "$pid"
    echo "[entrypoint] Initialisation terminee."
fi

# 3. exec remplace le shell au lieu de créer un processus : mysqld hérite
#    du PID 1, donc il reçoit directement le SIGTERM de docker stop et peut
#    écrire ses buffers sur le disque avant de quitter. Sans exec, bash
#    resterait PID 1, le signal n'arriverait jamais au serveur, et Docker
#    le tuerait au SIGKILL dix secondes plus tard — base potentiellement
#    corrompue. Cette fois le serveur démarre AVEC le réseau.
exec mysqld --user=mysql --datadir=/var/lib/mysql