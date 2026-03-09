#!/usr/bin/env bash
# API Gateway REST API resource module for aws-diff

fetch_api_gateway_config() {
  local api_name="$1"
  local profile="${2:-}"
  local region="${3:-}"

  _aws_apigw() {
    local args=()
    [[ -n "$profile" ]] && args+=(--profile "$profile")
    [[ -n "$region" ]] && args+=(--region "$region")
    aws "${args[@]}" apigateway "$@"
  }

  # Resolve name to API ID
  local api_id
  api_id=$(_aws_apigw get-rest-apis --output json 2>/dev/null | jq -r --arg name "$api_name" '.items[] | select(.name == $name) | .id' | head -1)
  [[ -z "$api_id" || "$api_id" == "null" ]] && die "Failed to find API: $api_name"

  local api_json resources stages
  api_json=$(_aws_apigw get-rest-api --rest-api-id "$api_id" --output json 2>/dev/null) || die "Failed to get API: $api_id"
  resources=$(_aws_apigw get-resources --rest-api-id "$api_id" --embed methods --output json 2>/dev/null | jq -c .) || resources='{}'
  stages=$(_aws_apigw get-stages --rest-api-id "$api_id" --output json 2>/dev/null | jq -c .) || stages='{}'

  [[ -z "$resources" ]] && resources='{}'
  [[ -z "$stages" ]] && stages='{}'

  jq -n \
    --argjson api "$(echo "$api_json" | jq -c .)" \
    --argjson resources "$resources" \
    --argjson stages "$stages" \
    '{Api: $api, Resources: $resources, Stages: $stages}'
}

list_api_gateway_names() {
  local profile="${1:-}"
  local region="${2:-}"
  local args=()
  [[ -n "$profile" ]] && args+=(--profile "$profile")
  [[ -n "$region" ]] && args+=(--region "$region")
  aws "${args[@]}" apigateway get-rest-apis --output json 2>/dev/null | jq -r '.items[].name'
}
