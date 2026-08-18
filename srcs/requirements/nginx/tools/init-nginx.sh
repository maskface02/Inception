#!/bin/sh
mkdir -p /etc/nginx/ssl /var/www/html /run/nginx

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/nginx.key \
  -out /etc/nginx/ssl/nginx.crt \
  -subj "/CN=${DOMAIN_NAME}" \
  -addext "subjectAltName=DNS:${DOMAIN_NAME}"

exec nginx -g 'daemon off;'
