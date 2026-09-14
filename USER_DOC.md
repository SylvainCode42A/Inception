# User documentation

This document is aimed at a user or an administrator who wants to run and use
the stack, without modifying it.

## What this stack provides

Three services run together and form a complete WordPress website served over
HTTPS:

| Service     | What it does                                                                     |
|-------------|----------------------------------------------------------------------------------|
| `nginx`     | Receives every request on port 443 over TLSv1.2 / TLSv1.3 and forwards PHP to WordPress. It is the only service reachable from outside. |
| `wordpress` | Runs the WordPress code through php-fpm and generates the pages.                 |
| `mariadb`   | Stores all the site content: posts, pages, users, settings.                      |

Data survives restarts: the database and the website files are kept in two
Docker named volumes stored under `/home/slidriss/data` on the host.

## Starting and stopping the project

All commands are run from the root of the repository, inside the virtual
machine.

```bash
make            # build the images if needed and start the three containers
make down       # stop and remove the containers (data is kept)
make stop       # stop the containers without removing them
make start      # start them again
make re         # full restart
```

The first start takes a few minutes: the images are built, the database is
initialised and WordPress is downloaded and installed automatically.

To remove everything, **including the website and database content**:

```bash
make fclean
```

## Accessing the website

The domain name is resolved locally. If it has not been done yet, add this line
to `/etc/hosts` on the machine running the browser:

```
127.0.0.1   slidriss.42.fr
```

- Website: <https://slidriss.42.fr>
- Administration panel: <https://slidriss.42.fr/wp-admin>

The TLS certificate is self-signed, so the browser shows a security warning on
the first visit. This is expected for a local domain; accept it to continue.

Only HTTPS on port 443 is available. Plain HTTP is not served.

## Credentials

Two WordPress accounts are created automatically on the first start:

- an **administrator**, with full access to the administration panel;
- a **second user** with the `author` role.

Their usernames, passwords and email addresses are defined in `srcs/.env`, along
with the database credentials. Copies of the sensitive values are also kept in
the `secrets/` directory.

Neither `srcs/.env` nor the files in `secrets/` are versioned: they are listed in
`.gitignore` and exist only on the machine running the project. To read the
current values:

```bash
cat srcs/.env
```

To change a password, edit the corresponding variable, then rebuild from a clean
state with `make fclean && make` — the accounts are created during the first
initialisation only.

## Checking that everything works

List the running containers:

```bash
docker ps
```

Three containers named `nginx`, `wordpress` and `mariadb` should be listed, all
with status `Up`.

Follow the logs:

```bash
make logs
```

Check that the database contains the WordPress tables:

```bash
docker exec -it mariadb mariadb -u root -p -e "SHOW TABLES FROM wordpress"
```

Check that the persistent data is really on disk:

```bash
ls /home/slidriss/data/db_data
ls /home/slidriss/data/wp_data
```

Check that persistence works, by stopping everything and starting again — the
site and its content must still be there:

```bash
make down && make
```
