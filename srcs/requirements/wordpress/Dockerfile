FROM alpine:3.23

RUN apk add --no-cache \
    php83 php83-fpm php83-mysqli php83-json \
    php83-curl php83-dom php83-mbstring \
    php83-openssl php83-xml php83-zip \
    php83-gd php83-iconv php83-intl php83-phar \
    wget tar mariadb-client \
    && sed -i 's/127.0.0.1:9000/0.0.0.0:9000/' /etc/php83/php-fpm.d/www.conf

COPY tools/setup-wp.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/setup-wp.sh

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/setup-wp.sh"]
