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

# --- Config ---
: "${DBPort:=3306}"

INPUT_FILE="./tmp/dump-${STAGE}.sql"
if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Snapshot file not found at $INPUT_FILE" >&2
  exit 1
fi

# --- Import ---
echo "Importing to RDS ${DBEndpoint}:${DBPort} from ${INPUT_FILE} ..."

mysql -h "$DBEndpoint" \
  -P "$DBPort" \
  -u admin \
  -p"$PASSWORD" \
  --ssl-mode=VERIFY_CA \
  --ssl-ca=./certs/global-bundle.pem \
  < "$INPUT_FILE"

echo "Done."
