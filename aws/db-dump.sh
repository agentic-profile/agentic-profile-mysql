#!/bin/bash
set -e
cd "$(dirname "$0")"

for arg in "$@"; do
  if [[ "$arg" == --stage=* ]]; then
    STAGE="${arg#--stage=}"
  fi
done
: "${STAGE:?Pass --stage=staging or --stage=prod to the script}"

set -a
. cloud.env
: "${StackName:?Set StackName in cloud.env}"
. ~/.aws-stacks/${StackName}-${STAGE}.env
set +a
: "${DBEndpoint:?Set DBEndpoint or run from aws/ with mysql-formation-results-${STAGE}.env}"
: "${DBMasterSecretArn:?Set DBMasterSecretArn or run from aws/ with mysql-formation-results-${STAGE}.env}"

PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$DBMasterSecretArn" --query SecretString --output text | jq -r '.password')

# All user databases (exclude system DBs)
DBS="$(
  mysql -h "$DBEndpoint" \
    -P "${DBPort:-3306}" \
    -u admin \
    -p"$PASSWORD" \
    -N -e "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('mysql','information_schema','performance_schema','sys');" \
    --ssl-mode=VERIFY_CA \
    --ssl-ca=./certs/global-bundle.pem \
)"
if [[ -z "${DBS//[$'\r\n']/}" ]]; then
  echo "No user databases found on Aurora." >&2
  exit 1
fi

mysqldump -h "$DBEndpoint" \
  -P "${DBPort:-3306}" \
  -u admin \
  -p"$PASSWORD" \
  --single-transaction --routines --triggers --set-gtid-purged=OFF --no-tablespaces \
  --ssl-mode=VERIFY_CA \
  --ssl-ca=./certs/global-bundle.pem \
  --databases $DBS \
  > ./tmp/dump-${STAGE}.sql

  echo "Dumped databases: $DBS"
