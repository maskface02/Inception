# Developer Documentation

Everything a developer needs to understand, build, break and fix this stack.

## Prerequisites

- **Docker Engine** with the Compose plugin (`docker compose version` should answer).
- **make**.
- **sudo** rights for the developer account — `make fclean` needs it to delete the data directories.
- A user account under `/home/<user>` — the volumes bind-mount there (this is a 42-school constraint; root's `/root` home is not used).

Optionally `openssl` on the host to inspect the generated certificate, and `curl` for health checks.

## What the stack is made of

Three containers, one bridge network (`inception`), one shared volume plus one per-service volume. Only nginx is exposed to the host, on **443/TCP (HTTPS)**.

```
internet ──► nginx (443, TLS) ──FastCGI──► wordpress (php-fpm :9000) ──SQL──► mariadb (:3306)
                 │                              │                                │
                 └────────── wp_files ─────────┘                                │
                        (shared, bind: /home/$USER/data/wordpress)      db_data
                                                     (bind: /home/$USER/data/mariadb)
```

| Container    | Base image   | Role | Entrypoint (in `srcs/requirements/<svc>/tools/`) |
|--------------|--------------|------|---------------------------------------------------|
| `nginx`      | `alpine:3.23`| TLS termination, static files, FastCGI proxy to `wordpress:9000` | `init-nginx.sh` — generates a self-signed cert for `$DOMAIN_NAME`, then execs `nginx -g 'daemon off;'` |
| `wordpress`  | `alpine:3.23` + php 8.3 | WordPress + php-fpm. Downloads WP core, writes `wp-config.php` from env + secrets, runs `wp core install`, creates the editor user, then execs `php-fpm83 -F` | `setup-wp.sh` |
| `mariadb`    | `alpine:3.23` + MariaDB | Database for WordPress, listening on 3306 **inside the Docker network only** | `init-db.sh` — first boot: `mysql_install_db`, creates DB + `wpuser`, sets root password, then execs `mysqld` |

Design choices worth knowing before you touch anything:

- **No custom images are pulled.** All three images are built from `alpine:3.23` in `srcs/requirements/*/Dockerfile`. The `image:` names in the compose file are just tags for the locally built images.
- **No passwords in the image or compose file.** They come from Docker secrets (files in `secrets/`), mounted at `/run/secrets/<name>` inside the containers. Scripts read them via `*_FILE` env vars (`.env`).
- **Idempotent entrypoints.** Both init scripts check for a marker (`/var/lib/mysql/mysql` directory for MariaDB, `/var/www/html/wp-config.php` + `/var/www/html/.installed` for WordPress) before doing work, so restarting a container doesn't re-install anything.
- **Restart policy.** `restart: unless-stopped` on all services: everything survives a host reboot unless you explicitly stopped it with `make down`.

## Environment, configuration and secrets

Three places carry configuration. In order of "how secret":

| File | Purpose | Contains |
|------|---------|----------|
| `srcs/docker-compose.yml` | topology | services, network, volume **bind devices** (`/home/$USER/data/...`), secret file paths |
| `srcs/.env` | non-secret configuration | `DOMAIN_NAME`, DB/user names, `*_FILE` paths pointing at `/run/secrets/...` |
| `secrets/*.txt` | the actual passwords | one password per file, no trailing newline issues — see `init-db.sh` reading them with `$(cat ...)`. Changing a password here only takes effect after a **full rebuild + re-init** (`make re`), because MariaDB and WordPress already hold their stored values.

To change the domain: edit `DOMAIN_NAME` in `srcs/.env` **and** `server_name` in `srcs/requirements/nginx/conf/nginx.conf`, then `make re`.

> Note: in this repo, `secrets/` and `srcs/.env` are currently **committed** (the matching `.gitignore` lines are commented out). That's convenient for a 42 evaluation, but before pushing this anywhere public, untrack them (`git rm --cached secrets/*.txt srcs/.env`) and re-enable the ignore rules.

## Build & run with the Makefile

The Makefile is a thin layer over `docker compose -f srcs/docker-compose.yml`:

```makefile
COMPOSE = docker compose -f $(COMPOSE_FILE)
```

| Target   | What it actually runs |
|----------|------------------------|
| `make` / `make all` | `up` → which depends on `build` |
| `make build` | `mkdir -p /home/$USER/data/{wordpress,mariadb}` + `docker compose build` — needed because the volumes use bind mounts; Compose won't create the host directories itself |
| `make up` | `build` then `docker compose up -d` |
| `make down` / `make clean` | `docker compose down` |
| `make re` | `fclean` then `all` — wipe and rebuild from zero |
| `make fclean` | `compose down` + `docker system prune -af` + `sudo rm -rf /home/$USER/data/{wordpress,mariadb}` + `docker network prune -f` |

Build order (`docker-compose.yml`, `depends_on`) guarantees: MariaDB container starts before WordPress, WordPress before nginx. Note `depends_on` only orders **container start**, not service readiness — that's why `setup-wp.sh` has its own `mysqladmin ping` wait loop before installing WordPress.

## Working with containers and volumes

```sh
# list the running stack
docker ps

# logs (follow, live)
docker logs -f nginx
docker logs -f wordpress
docker logs -f mariadb

# get a shell inside a running container
docker exec -it nginx sh
docker exec -it wordpress sh
docker exec -it mariadb sh

# one-off SQL against the database (root)
docker exec -it mariadb mariadb -u root -p
# then: SHOW DATABASES; USE wordpress; SHOW TABLES; SELECT COUNT(*) FROM wp_users;

# inspect what the volumes really are on the host
docker volume ls
docker volume inspect inception_wp_files
docker volume inspect inception_db_data
```

To re-run only one service after editing its Dockerfile/config:

```sh
make build && docker compose -f srcs/docker-compose.yml up -d <service>
```

For example after changing `nginx.conf`: `docker compose -f srcs/docker-compose.yml up -d --force-recreate nginx`.

## Where the data lives, and how it persists

Two named volumes, both **bind-mounted** into the host filesystem (42 requirement: data must survive `docker compose down`, reboot, and even image deletion):

| Volume (project-prefixed name) | Mounted at (container) | Bind device (host) | Holds |
|---|---|---|---|
| `inception_wp_files` | `/var/www/html` (nginx **and** wordpress) | `/home/$USER/data/wordpress` | WordPress core, themes, plugins, uploads, `wp-config.php`, `.installed` marker |
| `inception_db_data` | `/var/lib/mysql` (mariadb) | `/home/$USER/data/mariadb` | the actual database files |

Because both `wp_files` mount points are the **same** volume, nginx serves exactly what php-fpm writes — there's no file copying between containers.

What survives what:

| Action | Containers | Images | Data in `/home/$USER/data` |
|---|---|---|---|
| `make down` | removed | kept | kept |
| host reboot | restarted automatically (`unless-stopped`) | kept | kept |
| `make fclean` / `make re` | removed | **deleted** (`system prune -af`) | **deleted** (`sudo rm -rf`) |

### Backing up / restoring

```sh
# database
docker exec mariadb mariadb-dump -u root -p"$(cat secrets/db_root_password.txt)" wordpress > backup.sql
# restore: docker exec -i mariadb mariadb -u root -p"$(cat secrets/db_root_password.txt)" wordpress < backup.sql

# site files
cp -r /home/$USER/data/wordpress ~/wp-backup
```

Do this before any `make re` / `make fclean`.

## How first boot works (the interesting part)

1. `make` → host directories `/home/$USER/data/{wordpress,mariadb}` are created, images build, containers start.
2. **mariadb** `init-db.sh` sees no `/var/lib/mysql/mysql` → runs `mysql_install_db`, boots a temporary `mysqld`, creates `wordpress` DB + `wpuser` with the DB password from `/run/secrets/db_password`, sets root's password from `/run/secrets/db_root_password`, shuts down cleanly, then `exec mysqld` as PID 1.
3. **wordpress** `setup-wp.sh` sees no `wp-config.php` → downloads WordPress core into `/var/www/html` (the bind mount), writes `wp-config.php` using env vars + the DB password read from `/run/secrets/db_password` (salt keys fetched from api.wordpress.org). Then loops on `mysqladmin ping` until MariaDB answers, downloads wp-cli, runs `wp core install` (admin user `zatais` + password from `/run/secrets/wp_admin_password`), creates the `editor` user (password from `/run/secrets/wp_user_password`), touches `.installed`, then `exec php-fpm83 -F`.
4. **nginx** `init-nginx.sh` generates a self-signed 2048-bit RSA cert for `$DOMAIN_NAME` into `/etc/nginx/ssl/`, then `exec nginx -g 'daemon off;'`. nginx proxies `.php` requests over FastCGI to `wordpress:9000` (container name resolution via the shared `inception` network).

Everything after that hits the marker checks and skips straight to `exec`, so restarts are fast and non-destructive.

## Common development tasks

- **Change a password** → edit `secrets/*.txt`, run `make re` (destroys data — see USER_DOC.md for the non-destructive WordPress-only path).
- **Change the domain** → `srcs/.env` `DOMAIN_NAME` + `nginx/conf/nginx.conf` `server_name` (+ `/etc/hosts` on the host), then `make re`.
- **Rebuild just nginx** after a conf change → `make build && docker compose -f srcs/docker-compose.yml up -d --force-recreate nginx`.
- **Inspect generated `wp-config.php`** → `docker exec wordpress cat /var/www/html/wp-config.php` or open `/home/$USER/data/wordpress/wp-config.php` on the host.
- **Check TLS** → `curl -kv https://$DOMAIN_NAME` from the host.

## Gotchas

- The bind devices in `docker-compose.yml` use `$USER` — **run make as your own user**. Running as root points the volumes at `/root/data/...`, which works but isn't the 42-expected layout, and `make build`'s `mkdir` would create root-owned dirs your user can't manage later.
- `make fclean` needs **sudo** (the `rm -rf` of data dirs); expect a password prompt mid-target.
- The TLS certificate is regenerated each time the `nginx` container is recreated — browsers will re-warn after `make re`.
- `docker system prune -af` in `fclean` deletes **all** unused Docker data on the host, not just this project's. On a shared machine, be sure that's what you want.
- WordPress salts and core are fetched from the network on **first boot** only — an offline `make re` after `fclean` will fail at the download step.
