#!/bin/sh

set -e

TODAY=$(date +"%Y-%m-%d")
LOG_FILE="${LOGS_PATH}/${TODAY}.log"
echo "Logging output to ${LOG_FILE}"

echo "STARTING BACKUP SERVICE"
NOW=$(date +"%Y-%m-%d %H:%M:%S")
echo "Logging started at ${NOW}" >> "$LOG_FILE"

cd /scripts

if [ "${S3_S3V4}" = "yes" ]; then
  echo "Configuring S3V4 Signature"
  aws configure set default.s3.signature_version s3v4
fi

if [ "${SCHEDULE}" = "**None**" ]; then
  echo "No schedule defined, backing up now!"
  sh backup.sh >> "$LOG_FILE"
else
  if [ "${RUN_AT_STARTUP}" = "1" ]; then
    echo "Waiting ${STARTUP_BKP_DELAY_SECS} seconds as the startup delay"
    sleep "${STARTUP_BKP_DELAY_SECS}"
    sh backup.sh >> "$LOG_FILE"
  fi
  echo "Creating cron..."
  exec go-cron "$SCHEDULE" /bin/sh backup.sh
fi