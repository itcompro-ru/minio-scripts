#!/usr/bin/env bash

###
# Creates a new bucket and a new user
# User will have access to the new bucket only
# MinIO client (mc) is required https://github.com/minio/mc
###

if ! [ -x "$(command -v mc)" ]; then
  echo 'Error: mc (MinIO client) is not installed' >&2
  exit 1
fi

SERVER=$1
USER=$2
POLICY=$USER
USAGE="Usage: $0 server user"
if [[ -z $USER ]]; then
  echo "USER is empty"
  echo $USAGE
  exit
fi
if [[ -z $SERVER ]]; then
  echo "SERVER is empty"
  echo $USAGE
  exit
fi

# TODO: check existing user
# TODO: check existing policy

PASSWORD=$(head  /dev/urandom | sha1sum | egrep "\w+"  -o)
BUCKET=$(echo "$USER" | sha1sum | egrep "\w+"  -o)
TMPFILE="/tmp/$PASSWORD.json"
echo "{\"Version\":\"$(date -I)\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:*\"],\"Resource\":[\"arn:aws:s3:::$BUCKET\"]}]}" > $TMPFILE
echo "Create bucket $BUCKET"
mc mb $SERVER/$BUCKET
if [[ $? -ne 0 ]]; then
  exit
fi
echo "Create policy $USER"
mc admin policy add $SERVER $POLICY $TMPFILE
if [[ $? -ne 0 ]]; then
  exit
fi
echo "Create user $USER"
mc admin user add minio $USER $PASSWORD $POLICY
if [[ $? -ne 0 ]]; then
  exit
fi
echo "Access key: $USER"
echo "Secret key: $PASSWORD"
echo "Bucket: $BUCKET"
