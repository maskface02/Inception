FROM alpine:3.23

RUN apk add --no-cache nginx openssl

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY tools/init-nginx.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/init-nginx.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/init-nginx.sh"]
