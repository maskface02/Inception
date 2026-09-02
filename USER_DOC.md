# User Documentation

This guide is for whoever needs to run the Inception platform — an end user who just wants the site up, or an administrator taking care of it. No Docker knowledge required beyond copy-pasting a few commands.

## What is this thing?

Inception is a small web platform hosting a WordPress site. It's made of three services, each in its own container:

- **nginx** — the web server. It's the entry point for everything: browsers talk to it, it serves the pages, and it encrypts traffic with HTTPS.
- **WordPress** — the application. It's what you actually see and use: the website, the blog, the admin panel.
- **MariaDB** — the database. It stores every post, page, comment and user account.

You don't need to start these one by one. A single `make` command brings the whole platform up, and everything restarts automatically after a machine reboot (containers are configured with `restart: unless-stopped`).

## Starting and stopping

All commands run from the project root (the folder containing the `Makefile`).

| I want to…            | Command      |
|-----------------------|--------------|
| Start the platform    | `make`       |
| Stop it               | `make down`  |
| Restart from scratch  | `make re`    |
| Wipe everything       | `make fclean`|

Details worth knowing:

- **`make`** builds the images if needed (first launch takes a few minutes) and starts the three containers in the background. You can close your terminal afterwards — the containers keep running.
- **`make down`** stops the platform but keeps your data. The site comes back exactly as you left it on the next `make`.
- **`make re`** deletes images, containers and **all data**, then starts fresh. The site will be brand new (first-launch state).
- **`make fclean`** deletes images, containers **and all data** (site content and database). Nothing survives this.

> ⚠️ `make re` and `make fclean` are destructive. If the site has real content, back it up first (see [DEV_DOC.md](DEV_DOC.md)).

## Accessing the site and the admin panel

The site is served over HTTPS on a fixed domain. Once `make` has finished:

- **Website:** https://zatais.42.fr
- **Admin panel:** https://zatais.42.fr/wp-admin

Your browser will warn you about an untrusted certificate. That's expected: the platform generates its own certificate at startup instead of buying one from an authority. Click "Advanced" → "Proceed", or add an exception — your connection is still encrypted.

If the domain doesn't open, your machine probably doesn't know it yet. Add this line to `/etc/hosts` and reload the page:

```
127.0.0.1   zatais.42.fr
```

## Finding and managing credentials

Passwords never sit in the code. They live in plain text files under `secrets/`, one password per file, and are injected into the containers at startup:

| File in `secrets/`        | What it unlocks                        |
|---------------------------|----------------------------------------|
| `wp_admin_password.txt`   | WordPress admin panel (**administrator**) |
| `wp_user_password.txt`    | WordPress (**editor** account)          |
| `db_password.txt`         | MariaDB WordPress user (`wpuser`)       |
| `db_root_password.txt`    | MariaDB **root** account               |

The matching usernames are defined in `srcs/.env`:

| Account            | Username  | Password file              |
|--------------------|-----------|----------------------------|
| WordPress admin    | `zatais`  | `wp_admin_password.txt`    |
| WordPress editor   | `editor`  | `wp_user_password.txt`     |
| MariaDB user       | `wpuser`  | `db_password.txt`          |
| MariaDB root       | `root`    | `db_root_password.txt`     |

**To change a password:** edit the file in `secrets/` and run `make re`. Keep two things in mind:

1. Changing a secret file alone doesn't update passwords inside a running stack — the database and WordPress already have the old values stored. A full `make re` recreates everything with the new values.
2. `make re` **wipes the site**. If you only want to rotate the WordPress password, the safer way is to change it from the admin panel itself (Users → Profile → New Password).

This repository currently ships its secret files — fine for a school setup, but if you ever publish it for real, remove them from version control and add them to `.gitignore` instead.

## Checking everything is healthy

Quick check — are the three containers up?

```sh
docker ps
```

You want to see `nginx`, `wordpress` and `mariadb` with status `Up`. Something like:

```
CONTAINER ID   IMAGE      STATUS         NAMES
9f1c2a8b7d3e   nginx      Up 2 minutes   nginx
4e5d6f7a8b9c   wordpress  Up 2 minutes   wordpress
1a2b3c4d5e6f   mariadb    Up 2 minutes   mariadb
```

Is the site answering?

```sh
curl -k https://zatais.42.fr
```

Any response with HTML in it means nginx and WordPress are talking. If you get nothing at all, see the troubleshooting table below.

Something looks wrong? Read a service's logs:

```sh
docker logs nginx
docker logs wordpress
docker logs mariadb
```

### Troubleshooting

| Symptom                                      | Likely cause and fix                                                                 |
|----------------------------------------------|--------------------------------------------------------------------------------------|
| `docker ps` shows nothing                    | The stack isn't started — run `make`.                                                 |
| A container keeps restarting (`Up 5 seconds`) | Check `docker logs <container>` for the error. Usually a bad secret file or a missing data directory. |
| Browser can't reach the site                  | `/etc/hosts` entry missing (see above), or the `nginx` container isn't running.       |
| Site says "Error establishing a database connection" | MariaDB isn't ready yet. Give it a minute, then reload. If it persists: `docker logs mariadb`. |
| Permission denied on `/home/.../data`        | The Makefile creates directories under `/home/$USER` — run it as your regular user, not as root. |

If all else fails, `make re` gives you a working platform back — at the cost of the current content.
