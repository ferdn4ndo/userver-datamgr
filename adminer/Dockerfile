FROM adminer:4-standalone

USER root

RUN apt-get update && apt-get install -y \
    curl

USER adminer

EXPOSE 8080
