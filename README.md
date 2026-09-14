*This project has been created as part of the 42 curriculum by Sylvain Lidrissi (slidriss).*

# Inception

## Description

Inception is a system administration project whose goal is to build a small web
infrastructure entirely from scratch, using Docker and Docker Compose, inside a
dedicated virtual machine.

The stack serves a WordPress website over HTTPS. It is composed of three
services, each running in its own container, built from Dockerfiles written for
this project — no ready-made image is pulled from Docker Hub, apart from the
Debian base image:

| Service     | Role                                                              |
|-------------|-------------------------------------------------------------------|
| `nginx`     | Sole entry point of the infrastructure, port 443, TLSv1.2 / TLSv1.3 |
| `wordpress` | WordPress + php-fpm, executes the PHP code, no web server inside   |
| `mariadb`   | Database server storing all WordPress content                     |

Two Docker named volumes provide persistence: one for the database, one for the
website files. A dedicated bridge network connects the three containers; only
nginx is reachable from outside.

## Instructions

### Prerequisites

- A virtual machine running Debian (this project was developed on Debian 13).
- `docker.io`, the Docker Compose v2 plugin, `docker-buildx` and `make`
  installed inside the VM (see `DEV_DOC.md` for the exact commands).
- A `srcs/.env` file and the files under `secrets/`, both excluded from Git.
  Their expected content is documented in `DEV_DOC.md`.
- The domain name resolving locally, by adding this line to `/etc/hosts`:

```
127.0.0.1   slidriss.42.fr
```

### Running the project

```bash
make          # build the images and start the stack
make down     # stop and remove the containers
make re       # restart from scratch
make logs     # follow the logs
make fclean   # remove containers, images and persistent data
```

The website is then available at <https://slidriss.42.fr>. The certificate is
self-signed, so the browser will display a warning that has to be accepted
manually.

## Project description

### Use of Docker

Every service is described by its own Dockerfile, based on
`debian:bookworm-slim` — the penultimate stable Debian release, pinned by tag so
that a rebuild always produces the same environment. The `latest` tag is never
used.

Each container runs a single service, started in the foreground so that the
service itself is PID 1: `mysqld` for MariaDB, `php-fpm8.2 -F` for WordPress and
`nginx -g "daemon off;"` for NGINX. No `tail -f`, `sleep infinity` or other
artificial loop is used to keep a container alive. Where an initialisation step
is required, an entrypoint script performs it once and then hands over to the
real service through `exec`, so that the service inherits PID 1 and receives
termination signals correctly.

### Sources included in the project

- `srcs/requirements/<service>/Dockerfile` — build recipe for each image.
- `srcs/requirements/<service>/conf/` — configuration files copied into the
  images (`50-server.cnf`, `www.conf`, `nginx.conf`).
- `srcs/requirements/<service>/tools/entrypoint.sh` — first-run initialisation
  for MariaDB and WordPress.
- `srcs/docker-compose.yml` — services, network and named volumes.
- `srcs/.env` — configuration and credentials, ignored by Git.
- `Makefile` — single entry point to build and run the whole stack.

### Main design choices

- **MariaDB initialises itself on first start only.** The entrypoint checks
  whether the data directory already contains a database. If not, it initialises
  the data files, starts a temporary server with networking disabled, creates
  the project database and its user, sets the root password, shuts that
  temporary server down, and only then starts the definitive one. On later
  starts the whole block is skipped and the existing data is reused.
- **The pre-initialised database shipped by the Debian package is removed at
  build time.** Installing `mariadb-server` populates `/var/lib/mysql` inside
  the image; because Docker copies the content of a mount point into an empty
  named volume, that data would silently make the first-run detection fail.
  Clearing it in the Dockerfile guarantees the initialisation actually runs.
- **WordPress is installed non-interactively with WP-CLI.** No graphical setup
  wizard is involved: the entrypoint downloads WordPress, generates
  `wp-config.php` from the environment variables, installs the site, creates the
  administrator and a second user, then starts php-fpm.
- **Startup order is enforced twice.** Compose waits for MariaDB's healthcheck
  before starting WordPress, and the WordPress entrypoint additionally polls the
  database until it answers. A container that is *started* is not necessarily
  *ready*, and the second check covers that gap.
- **Only NGINX publishes a port.** MariaDB and WordPress are reachable only
  through the internal `inception` network, by container name.

### Virtual Machines vs Docker

A virtual machine emulates a complete computer: it runs its own kernel, boots a
full operating system, and reserves memory and disk up front. Isolation is
strong, but each VM costs gigabytes and starts in minutes.

A container shares the host kernel and isolates only the process tree, the
filesystem view and the network stack. It holds just the files a given service
needs, weighs tens or hundreds of megabytes, and starts in under a second. This
makes it practical to run one service per container and to rebuild the whole
stack on every change.

The trade-off is isolation: containers are separated by kernel features, not by
a hypervisor, so they are less isolated than VMs and cannot run a different
kernel from the host. Here both are used together — Docker provides the service
isolation, the VM provides a controlled Linux host to run it on.

### Secrets vs Environment Variables

Environment variables are simple and read by any process in the container. They
are convenient for configuration, but a variable is visible in
`docker inspect`, in the process environment and often in logs, which makes it a
poor place for a password.

Docker secrets are mounted as files inside the container, readable only by that
container, and never stored in the image or in its metadata. They are the
recommended place for confidential values.

In this project, configuration lives in `srcs/.env` — mandatory per the subject
— while every credential is also kept in `secrets/`. Both are listed in
`.gitignore`, so no password is ever committed: publicly stored credentials
would fail the project outright.

### Docker Network vs Host Network

With `network_mode: host`, a container shares the host's network stack directly:
no isolation, ports bound by the container are bound on the host, and two
services wanting the same port collide.

A user-defined bridge network — used here under the name `inception` — gives the
containers a private network of their own, with an embedded DNS server that
resolves container names. This is why WordPress reaches the database at
`mariadb:3306` and NGINX reaches PHP at `wordpress:9000`, with no IP address
written anywhere. Only the ports explicitly published (443 for NGINX) are
exposed to the outside world.

### Docker Volumes vs Bind Mounts

A bind mount maps an arbitrary host path into a container. It is immediate but
tied to the host layout, and its ownership and permissions come from the host,
which makes it fragile to move between machines.

A named volume is managed by Docker: it has a name, an explicit lifecycle
(`docker volume ls`, `docker volume rm`), survives `docker compose down`, and is
handled independently of the containers using it.

This project uses named volumes, as required. Their `driver_opts` pin the
underlying storage to `/home/slidriss/data`, so the data lands where the subject
asks for it while the volumes remain Docker named volumes rather than bind
mounts.

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Dockerfile best practices](https://docs.docker.com/build/building/best-practices/)
- [Docker and PID 1 / signal handling](https://docs.docker.com/engine/containers/multi-service_container/)
- [MariaDB documentation](https://mariadb.com/kb/en/documentation/)
- [`mysql_install_db`](https://mariadb.com/kb/en/mysql_install_db/)
- [WP-CLI handbook](https://make.wordpress.org/cli/handbook/)
- [NGINX documentation — `ngx_http_ssl_module`](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
- [Filesystem Hierarchy Standard](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html)
- [Debian releases](https://www.debian.org/releases/)

### Use of AI

An AI assistant was used throughout this project, mainly as a tutor and a
debugging partner rather than as a code generator:

- **Understanding concepts.** Explanations of images versus containers, PID 1
  and signal handling, why `exec` matters at the end of an entrypoint, the
  difference between named volumes and bind mounts, and why an artificial
  infinite loop is a bad way to keep a container alive.
- **Debugging.** Three real failures were diagnosed with its help and fixed by
  hand: a missing `/run/mysqld` directory preventing MariaDB from creating its
  socket, a data volume that was not actually emptied between test runs, and the
  pre-initialised database shipped inside the Debian `mariadb-server` package
  silently skipping the first-run initialisation.
- **Environment setup.** Guidance while creating the virtual machine, installing
  Docker and the Compose plugin on Debian, and cleaning credentials out of the
  Git repository.
- **Drafting.** First drafts of configuration files and of this documentation,
  which were then read, adjusted and tested.

Every file in this repository was reviewed line by line and tested in the
virtual machine. Nothing was kept that could not be explained.
