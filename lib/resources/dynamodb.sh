#!/usr/bin/env bash
# DynamoDB table resource module for aws-diff

fetch_dynamodb_config() {
  local table_name="$1"
  local profile="${2:-}"
  local region="${3:-}"

  _aws_ddb() {
    local args=()
    [[ -n "$profile" ]] && args+=(--profile "$profile")
    [[ -n "$region" ]] && args+=(--region "$region")
    aws "${args[@]}" dynamodb "$@"
  }

  local table_json
  table_json=$(_aws_ddb describe-table --table-name "$table_name" --output json 2>/dev/null) || die "Failed to get table: $table_name"

  echo "$table_json" | jq -c .
}

list_dynamodb_names() {
  local profile="${1:-}"
  local region="${2:-}"
  local args=()
  [[ -n "$profile" ]] && args+=(--profile "$profile")
  [[ -n "$region" ]] && args+=(--region "$region")
  aws "${args[@]}" dynamodb list-tables --output json 2>/dev/null | jq -r '.TableNames[]?'
}
