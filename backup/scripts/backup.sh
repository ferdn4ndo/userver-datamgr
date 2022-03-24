#!/bin/sh

set -e
set -o pipefail

echo "=== Database Backup Creation ==="

########################################################
## Environment check section
########################################################
if [ "${S3_ACCESS_KEY_ID}" = "" ]; then
  echo "You need to set the S3_ACCESS_KEY_ID environment variable."
  exit 1
fi

if [ "${S3_SECRET_ACCESS_KEY}" = "" ]; then
  echo "You need to set the S3_SECRET_ACCESS_KEY environment variable."
  exit 1
fi

if [ "${S3_BUCKET}" = "" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ "${POSTGRES_HOST}" = "" ]; then
  if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
    POSTGRES_HOST=$POSTGRES_PORT_5432_TCP_ADDR
    POSTGRES_PORT=$POSTGRES_PORT_5432_TCP_PORT
  else
    echo "You need to set the POSTGRES_HOST environment variable."
    exit 1
  fi
fi

if [ "${POSTGRES_USER}" = "" ]; then
  echo "You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [ "${POSTGRES_PASSWORD}" = "" ]; then
  echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
  exit 1
fi

if [ "${S3_ENDPOINT}" = "" ]; then
  AWS_ARGS=""
else
  AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
fi

########################################################
## Environment setup section
########################################################
export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION

export PGPASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_EXTRA_OPTS"

# prepare temp folder
mkdir -p "${TEMP_PATH}"

########################################################
## Temp folder cleanup
########################################################
echo "Removing previous temp files..."
rm -rf "${TEMP_PATH}"/*.*

########################################################
## Dump section
########################################################
DEST_FILE=${BACKUP_PREFIX}_$(date +"%Y-%m-%dT%H-%M-%SZ").sql
LOCAL_FILE="${TEMP_PATH}/${DEST_FILE}"
if [ "${POSTGRES_DATABASE}" != "" ]; then
  echo "Creating dump of ${POSTGRES_DATABASE} database from ${POSTGRES_HOST}..."
  # shellcheck disable=SC2086
  pg_dump $POSTGRES_HOST_OPTS "$POSTGRES_DATABASE" > "$LOCAL_FILE"
else
  echo "Creating dump of all databases from ${POSTGRES_HOST}..."
  # shellcheck disable=SC2086
  pg_dumpall $POSTGRES_HOST_OPTS > "$LOCAL_FILE"
fi
echo "Created dump file ${LOCAL_FILE}"

########################################################
## Compression section
########################################################
if [ "${XZ_COMPRESSION_LEVEL}" = "0" ] || [ "${SKIP_COMPRESSION}" = "1" ]; then
  echo "Skipping compression"
else
  echo "Compressing file..."
  if [ "${XZ_COMPRESSION_LEVEL}" = "" ]; then
    XZ_COMPRESSION_LEVEL=6
  fi
  xz --compress -${XZ_COMPRESSION_LEVEL} "${LOCAL_FILE}"
  ZIP_FILE="${LOCAL_FILE}.xz"
  DEST_FILE="${DEST_FILE}.xz"
  if [ ! -f "$ZIP_FILE" ]; then
      echo "ERROR: File $ZIP_FILE should exist by now."
      exit 1;
  fi
  LOCAL_FILE="$ZIP_FILE"
  echo "Created compressed file ${LOCAL_FILE}"
fi

########################################################
## Encryption section
########################################################
if [ "${ENCRYPTION_PASSWORD}" != "" ]; then
  echo "Encrypting..."
  ENC_FILE="${LOCAL_FILE}.enc"
  openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 100000 -salt -in "${LOCAL_FILE}" -out "${ENC_FILE}" -k "${ENCRYPTION_PASSWORD}"
  if [ $? != 0 ]; then
    >&2 echo "Error encrypting ${ENC_FILE}"
  fi
  rm "${LOCAL_FILE}"
  LOCAL_FILE="${ENC_FILE}"
  DEST_FILE="${DEST_FILE}.enc"
  echo "Created encrypted file ${DEST_FILE}"
fi

########################################################
## Upload section
########################################################
echo "Uploading dump to $S3_BUCKET"
# shellcheck disable=SC2086
UPLOAD_RESULT=$(aws $AWS_ARGS s3 cp - "s3://$S3_BUCKET/$S3_PREFIX/$DEST_FILE" < "$LOCAL_FILE")
echo "Upload result: ${UPLOAD_RESULT}"
echo "Upload complete! File was uploaded to: $S3_PREFIX/$DEST_FILE"
echo "Removing temp file..."
rm "$LOCAL_FILE"

########################################################
## Legacy backup cleanup section
########################################################
if [ "${DELETE_OLDER_THAN}" != "" ]; then
  >&2 echo "Checking for files older than ${DELETE_OLDER_THAN}"
  # shellcheck disable=SC2086
  aws $AWS_ARGS s3 ls "s3://$S3_BUCKET/$S3_PREFIX/" | grep " PRE " -v | while read -r line;
    do
      # shellcheck disable=SC1083
      fileName=$(echo "$line"|awk {'print $4'})
      # shellcheck disable=SC1083
      created=$(echo "$line"|awk {'print $1" "$2'})
      created=$(date -d "$created" +%s)
      older_than=$(date -d "$DELETE_OLDER_THAN" +%s)
      if [ "$created" -lt "$older_than" ]
        then
          if [ "$fileName" != "" ]
            then
              >&2 echo "DELETING ${fileName}"
              aws $AWS_ARGS s3 rm "s3://$S3_BUCKET/$S3_PREFIX/$fileName"
          fi
      else
          >&2 echo "${fileName} not older than ${DELETE_OLDER_THAN}"
      fi
    done;
fi

########################################################
## END
########################################################
echo "Database backup completed!"
echo ""
