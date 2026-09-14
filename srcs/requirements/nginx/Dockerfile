# Avant-dernière Debian stable
FROM debian:bookworm-slim

# Variable de build uniquement, alimentée par build.args du compose.
ARG DOMAIN_NAME=slidriss.42.fr

# update et install dans un seul RUN : séparés, Docker garderait le update
# en cache et installerait un jour contre un index de paquets périmé.
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Certificat auto-signé : aucune autorité ne peut signer slidriss.42.fr,
# leur métier étant de vérifier qu'on possède le domaine — or il n'existe
# que dans /etc/hosts. -nodes ne chiffre pas la clé privée : sinon nginx
# réclamerait une passphrase au démarrage et resterait bloqué.
RUN mkdir -p /etc/nginx/ssl \
    && openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/inception.key \
        -out /etc/nginx/ssl/inception.crt \
        -subj "/C=FR/ST=PACA/L=Nice/O=42/OU=42/CN=${DOMAIN_NAME}"

# Le nginx.conf de Debian contient déjà un include de conf.d/*.conf,
# donc ce fichier est chargé automatiquement.
COPY conf/nginx.conf /etc/nginx/conf.d/default.conf

# Le site par défaut de Debian écoute en HTTP sur le port 80. Sans ce rm,
# deux blocs server cohabiteraient et du HTTP en clair serait servi,
# ce que le sujet interdit.
RUN rm -f /etc/nginx/sites-enabled/default

# EXPOSE n'ouvre rien : c'est de la documentation. Ce qui publie
# réellement un port vers l'hôte, c'est "ports:" dans le compose.
EXPOSE 443

# Forme exec : aucun /bin/sh ne s'intercale, nginx est PID 1 dès la
# première milliseconde. "daemon off" l'empêche de se démoniser — sinon
# le processus de départ se terminerait et le conteneur s'arrêterait.
# C'est l'équivalent exact du -F de php-fpm.
ENTRYPOINT ["nginx", "-g", "daemon off;"]