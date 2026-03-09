#!/usr/bin/env bash
# Route Table resource module for aws-diff

fetch_route_table_config() {
  local name="$1"
  local profile="${2:-}"
  local region="${3:-}"

  _aws_ec2() {
    local args=()
    [[ -n "$profile" ]] && args+=(--profile "$profile")
    [[ -n "$region" ]] && args+=(--region "$region")
    aws "${args[@]}" ec2 "$@"
  }

  local result
  if [[ "$name" == rtb-* ]]; then
    result=$(_aws_ec2 describe-route-tables --route-table-ids "$name" --output json 2>/dev/null) || die "Failed to get route table: $name"
  else
    result=$(_aws_ec2 describe-route-tables --filters "Name=tag:Name,Values=$name" --output json 2>/dev/null) || die "Failed to get route table: $name"
  fi

  local rt
  rt=$(echo "$result" | jq -c '.RouteTables[0]')
  [[ -z "$rt" || "$rt" == "null" ]] && die "Route table not found: $name"

  echo "$rt" | jq -c '.Routes |= sort_by(.DestinationCidrBlock // .DestinationPrefixListId // "")'
}

list_route_table_names() {
  local profile="${1:-}"
  local region="${2:-}"
  local args=()
  [[ -n "$profile" ]] && args+=(--profile "$profile")
  [[ -n "$region" ]] && args+=(--region "$region")
  aws "${args[@]}" ec2 describe-route-tables --output json 2>/dev/null | jq -r '.RouteTables[] | (.Tags[]? | select(.Key=="Name") | .Value) // .RouteTableId' | sort -u
}
