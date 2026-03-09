#!/usr/bin/env bash
# VPC Endpoint resource module for aws-diff

fetch_vpc_endpoint_config() {
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
  if [[ "$name" == vpce-* ]]; then
    result=$(_aws_ec2 describe-vpc-endpoints --vpc-endpoint-ids "$name" --output json 2>/dev/null) || die "Failed to get VPC endpoint: $name"
  else
    result=$(_aws_ec2 describe-vpc-endpoints --filters "Name=tag:Name,Values=$name" --output json 2>/dev/null) || die "Failed to get VPC endpoint: $name"
  fi

  local ep
  ep=$(echo "$result" | jq -c '.VpcEndpoints[0]')
  [[ -z "$ep" || "$ep" == "null" ]] && die "VPC endpoint not found: $name"

  echo "$ep" | jq -c .
}

list_vpc_endpoint_names() {
  local profile="${1:-}"
  local region="${2:-}"
  local args=()
  [[ -n "$profile" ]] && args+=(--profile "$profile")
  [[ -n "$region" ]] && args+=(--region "$region")
  aws "${args[@]}" ec2 describe-vpc-endpoints --output json 2>/dev/null | jq -r '.VpcEndpoints[] | (.Tags[]? | select(.Key=="Name") | .Value) // .VpcEndpointId' | sort -u
}
