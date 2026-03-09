#!/usr/bin/env bash
# Step Functions state machine resource module for aws-diff

fetch_stepfunctions_config() {
  local name="$1"
  local profile="${2:-}"
  local region="${3:-}"

  _aws_sfn() {
    local args=()
    [[ -n "$profile" ]] && args+=(--profile "$profile")
    [[ -n "$region" ]] && args+=(--region "$region")
    aws "${args[@]}" stepfunctions "$@"
  }

  local arn
  arn=$(_aws_sfn list-state-machines --output json 2>/dev/null | jq -r --arg name "$name" '.stateMachines[] | select(.name == $name) | .stateMachineArn' | head -1)
  [[ -z "$arn" || "$arn" == "null" ]] && die "Failed to find state machine: $name"

  local sm_json
  sm_json=$(_aws_sfn describe-state-machine --state-machine-arn "$arn" --output json 2>/dev/null) || die "Failed to get state machine: $name"

  echo "$sm_json" | jq -c 'del(.creationDate, .status) | .definition = (.definition | fromjson | tostring)'
}

list_stepfunctions_names() {
  local profile="${1:-}"
  local region="${2:-}"
  local args=()
  [[ -n "$profile" ]] && args+=(--profile "$profile")
  [[ -n "$region" ]] && args+=(--region "$region")
  aws "${args[@]}" stepfunctions list-state-machines --output json 2>/dev/null | jq -r '.stateMachines[].name' || true
}
