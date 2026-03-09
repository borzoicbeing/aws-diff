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
  local config
  config=$(echo "$fn_json" | jq -c '.Configuration')

  # Event source mappings (Kinesis, DynamoDB Streams, SQS, etc.)
  local event_sources
  event_sources=$(_aws_lambda lambda list-event-source-mappings --function-name "$function_name" --output json 2>/dev/null | jq -c '.EventSourceMappings | sort_by(.EventSourceArn // "", .UUID)') || event_sources='[]'
  [[ -z "$event_sources" ]] && event_sources='[]'

  # Resource-based policy (API Gateway, S3, EventBridge, etc.)
  local policy_doc='null'
  local policy_raw
  policy_raw=$(_aws_lambda lambda get-policy --function-name "$function_name" --output json 2>/dev/null) || true
  if [[ -n "$policy_raw" ]]; then
    policy_doc=$(echo "$policy_raw" | jq -r '.Policy')
    if [[ -n "$policy_doc" && "$policy_doc" != "null" ]]; then
      policy_doc=$(echo "$policy_doc" | python3 -c "import urllib.parse,sys; print(urllib.parse.unquote(sys.stdin.read()))" 2>/dev/null || echo "$policy_doc")
      policy_doc=$(echo "$policy_doc" | jq -c -S . 2>/dev/null || echo "$policy_doc")
    fi
  fi

  jq -n \
    --argjson config "$config" \
    --argjson event_sources "$event_sources" \
    --argjson policy "$policy_doc" \
    '{Configuration: $config, EventSourceMappings: $event_sources, ResourcePolicy: $policy}'
}

list_lambda_names() {
  local profile="${1:-}"
  local region="${2:-}"
  local args=()
  [[ -n "$profile" ]] && args+=(--profile "$profile")
  [[ -n "$region" ]] && args+=(--region "$region")
  aws "${args[@]}" lambda list-functions --output json 2>/dev/null | jq -r '.Functions[].FunctionName'
}
