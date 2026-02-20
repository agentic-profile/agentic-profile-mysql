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

mysql -h "$DBEndpoint" \
  -P "${DBPort:-3306}" \
  -u admin \
  -p"$PASSWORD" \
  --ssl-mode=VERIFY_CA \
  --ssl-ca=./certs/global-bundle.pem \
  mysql
