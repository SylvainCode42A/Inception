FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y mariadb-server mariadb-client

RUN rm -rf /var/lib/mysql/*

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p /run/mysqld \
    && chown -R mysql:mysql /run/mysqld

EXPOSE 3306

ENTRYPOINT ["entrypoint.sh"]