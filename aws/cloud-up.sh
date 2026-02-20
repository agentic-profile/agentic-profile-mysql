#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

set -a
. ~/.aws-stacks/foundation-results.env
unset StackName
. cloud.env
set +a
: "${StackName:?Set StackName in cloud.env}"

for arg in "$@"; do
  if [[ "$arg" == --stage=* ]]; then
    STAGE="${arg#--stage=}"
  fi
done
: "${STAGE:?Pass --stage=staging or --stage=prod to the script}"

EXTRA_PARAMS=()
[[ -n "${AllowedExternalCidrBlock:-}" ]] && EXTRA_PARAMS+=(AllowedExternalCidrBlock="${AllowedExternalCidrBlock}")

aws cloudformation deploy \
  --template-file cloud-formation.yaml \
  --stack-name "${StackName}-${STAGE}" \
  --parameter-overrides \
    StackName="${StackName}-${STAGE}" \
    FoundationVpcId="${FoundationVpcId}" \
    PublicSubnet1Id="${PublicSubnet1Id}" \
    PublicSubnet2Id="${PublicSubnet2Id}" \
    "${EXTRA_PARAMS[@]}" \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
