#!/usr/bin/env bash
# EventBridge rule resource module for aws-diff

fetch_eventbridge_config() {
  local rule_name="$1"
  local profile="${2:-}"
  local region="${3:-}"
  local event_bus="default"

  _aws_events() {
    local args=()
    [[ -n "$profile" ]] && args+=(--profile "$profile")
    [[ -n "$region" ]] && args+=(--region "$region")
    aws "${args[@]}" events "$@"
  }

  local rule_json
  rule_json=$(_aws_events describe-rule --name "$rule_name" --event-bus-name "$event_bus" --output json 2>/dev/null) || die "Failed to get rule: $rule_name"

  local targets
  targets=$(_aws_events list-targets-by-rule --rule "$rule_name" --event-bus-name "$event_bus" --output json 2>/dev/null | jq -c '.Targets | sort_by(.Id)') || targets='[]'
  [[ -z "$targets" ]] && targets='[]'

  jq -n \
    --argjson rule "$(echo "$rule_json" | jq -c .)" \
    --argjson targets "$targets" \
    '{Rule: $rule, Targets: $targets}'
}

list_eventbridge_names() {
  local profile="${1:-}"
  local region="${2:-}"
  local event_bus="${3:-default}"
  local args=()
  [[ -n "$profile" ]] && args+=(--profile "$profile")
  [[ -n "$region" ]] && args+=(--region "$region")
  aws "${args[@]}" events list-rules --event-bus-name "$event_bus" --output json 2>/dev/null | jq -r '.Rules[].Name' || true
}
