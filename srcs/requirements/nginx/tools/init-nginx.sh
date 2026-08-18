#!/bin/sh

mkdir -p /var/www/html /run/nginx

exec nginx -g 'daemon off;'
