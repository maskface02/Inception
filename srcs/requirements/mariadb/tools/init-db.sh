#!/bin/sh

if [ ! -d "/var/lib/mysql/mysql" ]; then
  echo "Initializing MariaDB database..."

  mysql_install_db --user=mysql --datadir=/var/lib/mysql

  DB_PASSWORD=$(cat "$MYSQL_PASSWORD_FILE")
  ROOT_PASSWORD=$(cat "$MYSQL_ROOT_PASSWORD_FILE")

  mysqld --user=mysql --datadir=/var/lib/mysql &
  pid=$!

  until mariadb-admin ping --silent 2>/dev/null; do
    sleep 1
  done

  mariadb -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASSWORD}';
EOF

  mariadb-admin -u root -p"${ROOT_PASSWORD}" shutdown
  wait $pid

  echo "MariaDB initialized successfully."
fi

exec mysqld --user=mysql
