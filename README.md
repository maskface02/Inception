*This project has been created as part of the 42 curriculum by zatais.*

# Inception

## Description

Inception is a small WordPress platform built from scratch using Docker Compose. The goal is to set up a fully functional WordPress site running in containers without using any ready-made images — each service is built from a base Alpine image with its own Dockerfile.

The stack consists of three services:

| Service      | Role                                                                                                                                    |
|--------------|----------------------------------------------------------------------------------------------------------------------------------------|
| **nginx**        | The only entry point to the outside world. Serves the site over HTTPS (TLS 1.2/1.3) and proxies PHP requests to WordPress via FastCGI. |
| **wordpress**    | WordPress running on `php-fpm 8.3`. Downloads, configures and installs WordPress on first boot.                                          |
| **mariadb**      | The database. Stores all WordPress content and user accounts.                                                                          |

Only port **443** is published. The database and PHP-FPM are reachable only from inside the Docker network, never from the host machine.

```
        ┌───────────────────────────── Docker network: inception ─────────────────────────────┐
        │                                                                                     │
you ──► │  nginx :443 (TLS) ──FastCGI──► wordpress :9000 ──SQL──► mariadb :3306               │
        │        │                             │                     │                        │
        │        └─────────── wp_files (shared)┘                db_data (volume)              │
        └─────────────────────────────────────────────────────────────────────────────────────┘
```

nginx and WordPress share the `wp_files` volume (bind-mounted to `/home/<you>/data/wordpress`), so the web server can serve the files that PHP writes. MariaDB keeps its data in `/home/<you>/data/mariadb`. Everything you put on the site survives restarts, rebuilds and reboots — because it lives on your disk, not inside the containers.

## Instructions

### Prerequisites

- **Docker Engine** with the Compose plugin (`docker compose version` should answer).
- **make**.
- **sudo** rights for the developer account — `make fclean` needs it to delete the data directories.
- A user account under `/home/zatais` — the volumes bind-mount there (this is a 42-school constraint).

### Installation and execution

Clone the repository and run `make`:

```sh
git clone https://github.com/maskface02/Inception.git && cd Inception
make
```

The first run takes a few minutes (Alpine images, packages and WordPress itself are pulled/downloaded). Then open:

**https://zatais.42.fr**

You'll get a browser warning about the certificate — that's normal, it's a self-signed cert generated at startup. Accept it and continue.

> If the domain doesn't resolve, add this line to `/etc/hosts`:
> ```
> 127.0.0.1   zatais.42.fr
> ```

### Makefile commands

| Command            | What it does                                                                             |
|--------------------|------------------------------------------------------------------------------------------|
| `make` / `make up`     | Creates the data directories, builds the images and starts everything in the background. |
| `make build`         | Only builds the images (and prepares `/home/$USER/data/…`).                                |
| `make down`          | Stops and removes the containers. Your data stays.                                       |
| `make re`            | Full wipe (`fclean`) then a fresh start.                                                   |
| `make clean`         | Same as `down`.                                                                            |
| `make fclean`        | Stops everything, **removes the containers, images, networks and all data**. Clean slate.    |

### Repository layout

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

### Further documentation

- [USER_DOC.md](USER_DOC.md) — how to use and run the platform day to day.
- [DEV_DOC.md](DEV_DOC.md) — how it's built, where data lives, and how to work on it.

## Resources

- [Docker Documentation](https://docs.docker.com/) — official docs for Docker Engine and Docker Compose.
- [Docker Compose File Reference](https://docs.docker.com/compose/compose-file/) — specification for `docker-compose.yml`.
- [WordPress Getting Started](https://wordpress.org/support/article/getting-started-with-wordpress/) — official WordPress installation and setup guide.
- [MariaDB Knowledge Base](https://mariadb.com/kb/) — documentation for MariaDB, the database used in this project.
- [Nginx Documentation](https://nginx.org/en/docs/) — official Nginx web server documentation.
- [Alpine Linux Wiki](https://wiki.alpinelinux.org/) — reference for the base image used in all Dockerfiles.
- [OpenSSL Documentation](https://www.openssl.org/docs/) — used for self-signed TLS certificate generation.
