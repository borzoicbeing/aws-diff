#!/usr/bin/env bash
# AWS resource config diff - compare configs across environments

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") <resource_type> <from_name> <to_name> [options]

Compare AWS resource configs between two environments.

Arguments:
  resource_type   e.g. iam-role
  from_name       Resource name in from environment
  to_name         Resource name in to environment

Options:
  --from-profile PROFILE   AWS profile for from environment
  --to-profile PROFILE     AWS profile for to environment
  --from-region REGION     AWS region for from (Lambda, SQS, DynamoDB, API Gateway)
  --to-region REGION       AWS region for to
  --env-id PATTERN         Regex to strip env prefix (match -> empty string)
  --replace PAT REPL       Custom replacement (pattern, replacement)
  --replace-file PATH      File with pattern<TAB>replacement lines
  --no-default-exclude     Skip default exclusions (ARN, ID, timestamps)

Example:
  $(basename "$0") iam-role dev-MyRole1 prd-MyRole1 --env-id '(dev-|prd-)'
EOF
  exit 1
}

main() {
  [[ $# -lt 3 ]] && usage

  local resource_type="$1"
  local from_name="$2"
  local to_name="$3"
  shift 3

  local from_profile=""
  local to_profile=""
  local from_region=""
  local to_region=""
  local env_id_pattern=""
  local replace_patterns=()
  local replace_file=""
  local no_default_exclude=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from-profile)
        from_profile="$2"
        shift 2
        ;;
      --to-profile)
        to_profile="$2"
        shift 2
        ;;
      --from-region)
        from_region="$2"
        shift 2
        ;;
      --to-region)
        to_region="$2"
        shift 2
        ;;
      --env-id)
        env_id_pattern="$2"
        shift 2
        ;;
      --replace)
        [[ $# -lt 3 ]] && die "--replace requires pattern and replacement"
        replace_patterns+=("$2"$'\t'"$3")
        shift 3
        ;;
      --replace-file)
        replace_file="$2"
        shift 2
        ;;
      --no-default-exclude)
        no_default_exclude=true
        shift
        ;;
      -h|--help)
        usage
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done

  # Add env-id as pattern -> empty replacement
  [[ -n "$env_id_pattern" ]] && replace_patterns+=("$env_id_pattern"$'\t'"")
  # Load replace-file
  if [[ -n "$replace_file" && -f "$replace_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      replace_patterns+=("$line")
    done < "$replace_file"
  fi

  local fetch_fn needs_region=false
  case "$resource_type" in
    iam-role)
      source "$SCRIPT_DIR/lib/resources/iam-role.sh"
      fetch_fn="fetch_iam_role_config"
      ;;
    lambda)
      source "$SCRIPT_DIR/lib/resources/lambda.sh"
      fetch_fn="fetch_lambda_config"
      needs_region=true
      ;;
    s3-bucket)
      source "$SCRIPT_DIR/lib/resources/s3-bucket.sh"
      fetch_fn="fetch_s3_bucket_config"
      ;;
    api-gateway)
      source "$SCRIPT_DIR/lib/resources/api-gateway.sh"
      fetch_fn="fetch_api_gateway_config"
      needs_region=true
      ;;
    sqs)
      source "$SCRIPT_DIR/lib/resources/sqs.sh"
      fetch_fn="fetch_sqs_config"
      needs_region=true
      ;;
    iam-policy)
      source "$SCRIPT_DIR/lib/resources/iam-policy.sh"
      fetch_fn="fetch_iam_policy_config"
      ;;
    dynamodb)
      source "$SCRIPT_DIR/lib/resources/dynamodb.sh"
      fetch_fn="fetch_dynamodb_config"
      needs_region=true
      ;;
    network-acl)
      source "$SCRIPT_DIR/lib/resources/network-acl.sh"
      fetch_fn="fetch_network_acl_config"
      needs_region=true
      ;;
    eventbridge)
      source "$SCRIPT_DIR/lib/resources/eventbridge.sh"
      fetch_fn="fetch_eventbridge_config"
      needs_region=true
      ;;
    vpc-endpoint)
      source "$SCRIPT_DIR/lib/resources/vpc-endpoint.sh"
      fetch_fn="fetch_vpc_endpoint_config"
      needs_region=true
      ;;
    stepfunctions)
      source "$SCRIPT_DIR/lib/resources/stepfunctions.sh"
      fetch_fn="fetch_stepfunctions_config"
      needs_region=true
      ;;
    security-group)
      source "$SCRIPT_DIR/lib/resources/security-group.sh"
      fetch_fn="fetch_security_group_config"
      needs_region=true
      ;;
    ecr)
      source "$SCRIPT_DIR/lib/resources/ecr.sh"
      fetch_fn="fetch_ecr_config"
      needs_region=true
      ;;
    route-table)
      source "$SCRIPT_DIR/lib/resources/route-table.sh"
      fetch_fn="fetch_route_table_config"
      needs_region=true
      ;;
    *)
      die "Unknown resource type: $resource_type"
      ;;
  esac

  ensure_jq

  local from_json to_json
  if [[ "$needs_region" == "true" ]]; then
    from_json=$($fetch_fn "$from_name" "$from_profile" "$from_region")
    to_json=$($fetch_fn "$to_name" "$to_profile" "$to_region")
  else
    from_json=$($fetch_fn "$from_name" "$from_profile")
    to_json=$($fetch_fn "$to_name" "$to_profile")
  fi

  from_json=$(echo "$from_json" | jq -c .)
  to_json=$(echo "$to_json" | jq -c .)

  from_json=$(normalize_json "$from_json")
  to_json=$(normalize_json "$to_json")

  if [[ "$no_default_exclude" != "true" ]]; then
    from_json=$(apply_default_exclusions "$from_json")
    to_json=$(apply_default_exclusions "$to_json")
  fi

  if [[ ${#replace_patterns[@]} -gt 0 ]]; then
    from_json=$(apply_replacements "$from_json" "${replace_patterns[@]}")
    to_json=$(apply_replacements "$to_json" "${replace_patterns[@]}")
  fi

  run_diff "$from_json" "$to_json"
}

main "$@"
