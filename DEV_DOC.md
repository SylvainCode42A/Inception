# Developer documentation

This document describes how to set up the project from scratch, how it is built
and launched, and where its data lives.

## Setting up the environment from scratch

### 1. Virtual machine

The whole project runs inside a virtual machine, as required by the subject.
It was developed on Debian 13 with a light desktop environment, 2 GB of RAM,
2 vCPUs and a 20 GB disk, created with VirtualBox.

The user account inside the VM must be named `slidriss`, so that the home
directory is `/home/slidriss` — the path the named volumes are pinned to.

### 2. Docker

Inside the VM, as root:

```bash
apt update
apt install -y docker.io make git curl
```

Debian does not ship the Compose v2 plugin nor buildx, so both are installed
manually:

```bash
mkdir -p /usr/local/lib/docker/cli-plugins

curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

BUILDX_VER=$(curl -s https://api.github.com/repos/docker/buildx/releases/latest \
  | grep -oP '"tag_name": "\K[^"]+')
curl -SL "https://github.com/docker/buildx/releases/download/${BUILDX_VER}/buildx-${BUILDX_VER}.linux-amd64" \
  -o /usr/local/lib/docker/cli-plugins/docker-buildx
chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx
```

Allow the normal user to talk to Docker, then log out and back in:

```bash
usermod -aG docker,sudo slidriss
```

Verify:

```bash
docker --version
docker compose version
docker buildx version
docker run hello-world
```

### 3. Domain name

```bash
echo "127.0.0.1   slidriss.42.fr" | sudo tee -a /etc/hosts
```

### 4. Configuration file

`srcs/.env` is not versioned and must be recreated. It holds every variable the
three services read:

```
DOMAIN_NAME=slidriss.42.fr

# MariaDB
MYSQL_DATABASE=wordpress
MYSQL_USER=<database user>
MYSQL_PASSWORD=<database user password>
MYSQL_ROOT_PASSWORD=<database root password>

# WordPress -> database connection
WORDPRESS_DB_HOST=mariadb
WORDPRESS_DB_NAME=wordpress
WORDPRESS_DB_USER=<same as MYSQL_USER>
WORDPRESS_DB_PASSWORD=<same as MYSQL_PASSWORD>

# WordPress site and accounts
WP_TITLE=Inception
WP_ADMIN_USER=<must not contain "admin" or "administrator">
WP_ADMIN_PASSWORD=<administrator password>
WP_ADMIN_EMAIL=<administrator email>
WP_USER=<second user>
WP_USER_PASSWORD=<second user password>
WP_USER_EMAIL=<second user email>
```

The three `WORDPRESS_DB_*` values must match the corresponding `MYSQL_*` values,
otherwise WordPress cannot connect to the database MariaDB created.

### 5. Secrets

The `secrets/` directory holds the confidential values as plain files, kept
locally and excluded from Git:

- `db_root_password.txt` — MariaDB root password
- `db_password.txt` — MariaDB user password
- `credentials.txt` — WordPress administrator and user credentials

Neither `srcs/.env` nor `secrets/*.txt` may ever be committed. `.gitignore`
covers both, plus `*.log`.

## Building and launching

The `Makefile` at the root of the repository is the single entry point. It calls
`docker compose` with `srcs/docker-compose.yml`, which in turn builds the three
Dockerfiles.

```bash
make          # mkdir the data directories, then build the images and start the stack
make down     # stop and remove containers and network, keep the volumes
make stop     # stop without removing
make start    # start again
make re       # down + up
make logs     # follow the logs of the three services
make ps       # status of the containers
make clean    # down -v --rmi local: also removes volumes and locally built images
make fclean   # clean + delete the data directories + prune the Docker system
```

`make` runs `docker compose up -d --build`, so a modified Dockerfile is rebuilt
automatically. Note that `--build` requires buildx to be installed (see above).

## Managing containers and volumes

```bash
docker ps                          # running containers
docker ps -a                       # all containers, including stopped ones
docker logs -f mariadb             # follow one container's logs
docker exec -it wordpress bash     # open a shell inside a container
docker inspect nginx               # full configuration of a container

docker network ls                  # networks; srcs_inception is the project one
docker network inspect srcs_inception

docker volume ls                   # volumes; srcs_db_data and srcs_wp_data
docker volume inspect srcs_db_data

docker images                      # built images: mariadb, wordpress, nginx
```

Useful checks:

```bash
docker exec -it mariadb mariadb -u root -p -e "SHOW DATABASES"
docker exec -it mariadb mariadb -u root -p -e "SELECT User, Host FROM mysql.user"
docker exec -it wordpress wp user list --allow-root --path=/var/www/html
```

## Where the data lives and how it persists

Two Docker named volumes hold everything that must survive a restart:

| Volume         | Mounted at        | Host location                    | Content                          |
|----------------|-------------------|----------------------------------|----------------------------------|
| `db_data`      | `/var/lib/mysql`  | `/home/slidriss/data/db_data`    | MariaDB data files and tables    |
| `wp_data`      | `/var/www/html`   | `/home/slidriss/data/wp_data`    | WordPress code, themes, uploads  |

They are declared in `docker-compose.yml` with the `local` driver and
`driver_opts` pinning `device` to those host paths, so the data ends up under
`/home/slidriss/data` while remaining Docker named volumes rather than bind
mounts.

`wp_data` is mounted in two containers: WordPress writes the files, NGINX reads
them to serve static assets.

Consequences to keep in mind:

- `make down` removes the containers but keeps the volumes, so the site survives.
- `make clean` and `make fclean` delete the data. After that, the next start
  re-runs the full initialisation from scratch.
- Both entrypoints detect an already-initialised state and skip initialisation:
  MariaDB checks for `/var/lib/mysql/mysql`, WordPress checks for
  `/var/www/html/wp-config.php`. Deleting the volume content is therefore the
  way to force a clean reinstall.
