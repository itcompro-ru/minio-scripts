#!/usr/bin/env bash

###
# Creates a new bucket and a new user
# User will have access to the new bucket only
# MinIO client (mc) is required https://github.com/minio/mc
###

die()
{
	local _ret=$2
	test -n "$_ret" || _ret=1
	test "$_PRINT_HELP" = yes && print_help >&2
	echo "$1" >&2
	exit ${_ret}
}



if ! [ -x "$(command -v mc)" ]; then
  die 'Error: mc (MinIO client) is not installed (https://github.com/minio/mc)' 
fi

SERVER=$1
USER=$2
POLICY=$USER
USAGE="Usage: $0 server user"
if [[ -z $USER ]]; then
  echo "USER is empty"
  die $USAGE
fi
if [[ -z $SERVER ]]; then
  echo "SERVER is empty"
  die $USAGE
  exit
fi

if [[ $(mc admin user list minio --json | grep $USER | wc -l) != "0" ]]; then
  die "error, user or poilicy allready exists"
fi

PASSWORD=$(head  /dev/urandom | sha1sum | egrep "\w+"  -o)
BUCKET=$(head  /dev/urandom | sha1sum | egrep "\w+" -o)
BUCKET="$USER${BUCKET:0:6}"
TMPFILE="/tmp/$PASSWORD.json"

echo "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:*\"],\"Resource\":[\"arn:aws:s3:::$BUCKET\"]}]}" > $TMPFILE
echo "Create bucket $BUCKET"



mc mb $SERVER/$BUCKET || die "error"

echo "Create policy $USER"
mc admin policy add $SERVER $POLICY $TMPFILE || die "error"

echo "Create user $USER"
mc admin user add $SERVER $USER $PASSWORD $POLICY || die "error"


rm $TMPFILE

echo "Access key: $USER"
echo "Secret key: $PASSWORD"
echo "Bucket: $BUCKET"
