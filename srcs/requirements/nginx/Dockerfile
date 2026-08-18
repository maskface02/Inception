FROM alpine:3.24

RUN apk add --no-cache nginx openssl \
    && rm -rf /var/cache/apk/*

COPY tools/nginx.crt /etc/nginx/ssl/nginx.crt
COPY tools/nginx.key /etc/nginx/ssl/nginx.key

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY tools/init-nginx.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-nginx.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/init-nginx.sh"]
