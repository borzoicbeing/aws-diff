#!/usr/bin/env bash
# SQS queue resource module for aws-diff

fetch_sqs_config() {
  local queue_name="$1"
  local profile="${2:-}"
  local region="${3:-}"

  _aws_sqs() {
    local args=()
    [[ -n "$profile" ]] && args+=(--profile "$profile")
    [[ -n "$region" ]] && args+=(--region "$region")
    aws "${args[@]}" sqs "$@"
  }

  local queue_url
  queue_url=$(_aws_sqs get-queue-url --queue-name "$queue_name" --output json 2>/dev/null | jq -r '.QueueUrl') || die "Failed to get queue URL: $queue_name"
  [[ -z "$queue_url" || "$queue_url" == "null" ]] && die "Failed to get queue URL: $queue_name"

  local attrs
  attrs=$(_aws_sqs get-queue-attributes --queue-url "$queue_url" --attribute-names All --output json 2>/dev/null | jq -c '.Attributes') || attrs='{}'
  [[ -z "$attrs" ]] && attrs='{}'

  jq -n --argjson attrs "$attrs" '{Attributes: $attrs}'
}

list_sqs_names() {
  local profile="${1:-}"
  local region="${2:-}"
  local args=()
  [[ -n "$profile" ]] && args+=(--profile "$profile")
  [[ -n "$region" ]] && args+=(--region "$region")
  aws "${args[@]}" sqs list-queues --output json 2>/dev/null | jq -r '.QueueUrls[]? | split("/") | last' || true
}
