#!/bin/bash

set -e
set -o pipefail

echo "Starting E2E tests!"

totalErrors=0

echo "Getting uServer-Adminer container output using cURL"
adminerOutput=$(curl -s "http://adminer.userver.lan/" || true)

echo "Checking for the uServer-Adminer 'title' HTML element"
heartbeatBoxLine=$(echo "$adminerOutput" | grep "<title>Login - Adminer</title>" || true)
if [ "$heartbeatBoxLine" == "" ]; then
    echo "Failed finding the HTML title 'Login - Adminer' in the uServer-Adminer cURL response!"
    ((totalErrors+=1))
else
    echo "Successfully found the HTML title 'Login - Adminer' in the uServer-Adminer cURL response!"
fi

# TODO: test Postgres connection

# TODO: test if the S3 backup file was upload successfully

# TODO: test Redis connection

echo "E2E Tests successfully executed!"
