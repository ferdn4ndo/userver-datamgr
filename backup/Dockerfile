FROM alpine:3.11
LABEL maintaner="Fernando Constantino <const.fernando@gmail.com>"

RUN apk update \
    && apk add coreutils \
    && apk add postgresql-client \
    && apk add python py2-pip && pip install awscli && apk del py2-pip \
    && apk add openssl \
    && apk add curl \
    && apk add xz \
    && curl -L --insecure https://github.com/odise/go-cron/releases/download/v0.0.6/go-cron-linux.gz | zcat > /usr/local/bin/go-cron && chmod u+x /usr/local/bin/go-cron \
    && apk del curl \
    && rm -rf /var/cache/apk/*

ADD entrypoint.sh entrypoint.sh

RUN chmod +x entrypoint.sh

ENTRYPOINT ["sh", "entrypoint.sh"]
