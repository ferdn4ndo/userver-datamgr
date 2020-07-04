#!/bin/sh

set -e
set -o pipefail

echo "=============================="
echo "== Database Backup Creation =="
echo "=============================="

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

# env vars needed for aws tools
export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION

export PGPASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_EXTRA_OPTS"

# prepare temp folder
mkdir -p ${TEMP_PATH}

########################################################
## Listing backup files for restore section
########################################################

if [ $# -eq 0 ]; then
  echo "No backup file specified, listing possible values"

  aws s3 ls s3://$S3_BUCKET/$S3_PREFIX/ | grep " PRE " -v | while read -r line;
    do
      fileName=`echo $line|awk {'print $4'}`
      created=`echo $line|awk {'print $1" "$2'}`

      echo "${created}: ${fileName}"

    done;

  echo ""
  echo ""
  echo "Run this command again passing the filename as parameter, like:"
  echo ""
  echo "${0##*/} postgres-dump-all_2020-07-04T05:54:33Z.sql.gz.enc"
  echo ""
  exit 0;
fi

########################################################
## Download file
########################################################

REMOTE_FILE="$1"
echo "Trying to download file $file"

LOCAL_FILE="${TEMP_PATH}/${REMOTE_FILE}"
aws s3 cp "s3://$S3_BUCKET/$S3_PREFIX/$REMOTE_FILE" "$LOCAL_FILE"
echo "Downloaded file to ${LOCAL_FILE}"


########################################################
## Decryption
########################################################
FILE_EXT=${LOCAL_FILE##*.}
if [ "${FILE_EXT}" = "enc" ]; then
  echo "Decrypting file..."
  DECRYPTED_FILE=${LOCAL_FILE%.*}
  openssl enc -d -aes-256-cbc -md sha512 -pbkdf2 -iter 100000 -salt -in "${LOCAL_FILE}" -out "${DECRYPTED_FILE}" -k "${ENCRYPTION_PASSWORD}"
  rm $LOCAL_FILE
  LOCAL_FILE="${DECRYPTED_FILE}"
  echo "Decrypted file to ${LOCAL_FILE}"
fi

########################################################
## Decompression
########################################################
FILE_EXT=${LOCAL_FILE##*.}
if [ "${FILE_EXT}" = "xz" ]; then
  echo "Decompressing file..."
  DECOMPRESSED_FILE=${LOCAL_FILE%.*}
  xz --decompress --force "${LOCAL_FILE}"
  LOCAL_FILE="${DECOMPRESSED_FILE}"
  echo "Decompressed file to ${LOCAL_FILE}"
fi

########################################################
## Import
########################################################

if [ ! -f "$LOCAL_FILE" ]; then
    echo "ERROR: File $LOCAL_FILE should exist by now."
    exit 1;
fi
FILE_EXT=${LOCAL_FILE##*.}
if [ "${FILE_EXT}" != "sql" ]; then
  echo "Local file '${FILE_EXT}' should have .sql extension now!"
  exit 1;
fi

echo "Importing dump..."
psql $POSTGRES_HOST_OPTS -f $LOCAL_FILE > /dev/null
echo "Restore complete!"

echo "Removing temp file..."
rm "${LOCAL_FILE}"

########################################################
## END
########################################################

echo "Database restore completed!"
echo "=============================="

