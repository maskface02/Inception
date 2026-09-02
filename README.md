# Inception

A small WordPress platform built from scratch with Docker Compose — no ready-made images, no magic. Everything runs inside its own container and talks to the others over a private network.

The stack has three services:

| Service   | What it does                                                          |
|-----------|-----------------------------------------------------------------------|
| **nginx** | The only door to the outside world. Serves the site over HTTPS (TLS 1.2/1.3) and hands PHP requests to WordPress via FastCGI. |
| **wordpress** | WordPress itself, running on `php-fpm 8.3`. Downloads, configures and installs WordPress on first boot. |
| **mariadb** | The database. Stores all WordPress content and user accounts. |

Only port **443** is published. The database and PHP-FPM are reachable only from inside the Docker network, never from your machine.

```
        ┌───────────────────────────── Docker network: inception ─────────────────────────────┐
        │                                                                                      │
you ──► │  nginx :443 (TLS) ──FastCGI──► wordpress :9000 ──SQL──► mariadb :3306                │
        │        │                             │                          │                     │
        │        └─────────── wp_files (shared) ┘                   db_data (volume)           │
        └──────────────────────────────────────────────────────────────────────────────────────┘
```

nginx and WordPress share the `wp_files` volume (bind-mounted to `/home/<you>/data/wordpress`), so the web server can serve the files that PHP writes. MariaDB keeps its data in `/home/<you>/data/mariadb`. Everything you put on the site survives restarts, rebuilds and reboots — because it lives on your disk, not inside the containers.

## Quick start

```sh
git clone https://github.com/maskface02/Inception.git && cd Inception
make
```

That's it. The first run takes a few minutes (Alpine images, packages and WordPress itself are pulled/downloaded). Then open:

**https://zatais.42.fr**

You'll get a browser warning about the certificate — that's normal, it's a self-signed cert generated at startup. Accept it and continue.

> If the domain doesn't resolve, add this line to `/etc/hosts`:
> ```
> 127.0.0.1   zatais.42.fr
> ```

## Makefile

| Command      | What it does                                                        |
|--------------|---------------------------------------------------------------------|
| `make` / `make up` | Creates the data directories, builds the images and starts everything in the background. |
| `make build` | Only builds the images (and prepares `/home/$USER/data/…`).         |
| `make down`  | Stops and removes the containers. Your data stays.                 |
| `make re`    | Full wipe (`fclean`) then a fresh start.                            |
| `make clean` | Same as `down`.                                                     |
| `make fclean`| Stops everything, **removes the containers, images, networks and all data**. Clean slate. |

## Repository layout

```
.
├── Makefile                # entry point for everything
├── secrets/                # passwords, one per file (see USER_DOC.md)
├── srcs/
│   ├── .env                # domain name, database/user names
│   ├── docker-compose.yml  # the whole stack
│   └── requirements/
│       ├── mariadb/        # Dockerfile + init script + my.cnf
│       ├── wordpress/      # Dockerfile + WordPress setup script
│       └── nginx/          # Dockerfile + nginx.conf + TLS setup
└── tools/
```

## Going further

- [USER_DOC.md](USER_DOC.md) — how to use and run the platform day to day.
- [DEV_DOC.md](DEV_DOC.md) — how it's built, where data lives, and how to work on it.
