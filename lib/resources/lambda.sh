#!/usr/bin/env bash
# Lambda function resource module for aws-diff

fetch_lambda_config() {
  local function_name="$1"
  local profile="${2:-}"
  local region="${3:-}"

  _aws_lambda() {
    local args=()
    [[ -n "$profile" ]] && args+=(--profile "$profile")
    [[ -n "$region" ]] && args+=(--region "$region")
    aws "${args[@]}" "$@"
  }

  local fn_json
  fn_json=$(_aws_lambda lambda get-function --function-name "$function_name" --output json 2>/dev/null) || die "Failed to get function: $function_name"

  # Extract Configuration only (exclude Code.Location which is env-specific)
  echo "$fn_json" | jq -c '{Configuration: .Configuration}'
}

list_lambda_names() {
  local profile="${1:-}"
  local region="${2:-}"
  local args=()
  [[ -n "$profile" ]] && args+=(--profile "$profile")
  [[ -n "$region" ]] && args+=(--region "$region")
  aws "${args[@]}" lambda list-functions --output json 2>/dev/null | jq -r '.Functions[].FunctionName'
}
