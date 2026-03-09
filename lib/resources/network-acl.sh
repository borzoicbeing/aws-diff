#!/usr/bin/env bash
# Network ACL resource module for aws-diff

fetch_network_acl_config() {
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
  if [[ "$name" == acl-* ]]; then
    result=$(_aws_ec2 describe-network-acls --network-acl-ids "$name" --output json 2>/dev/null) || die "Failed to get NACL: $name"
  else
    result=$(_aws_ec2 describe-network-acls --filters "Name=tag:Name,Values=$name" --output json 2>/dev/null) || die "Failed to get NACL: $name"
  fi

  local nacl
  nacl=$(echo "$result" | jq -c '.NetworkAcls[0]')
  [[ -z "$nacl" || "$nacl" == "null" ]] && die "NACL not found: $name"

  echo "$nacl" | jq -c '.Entries |= sort_by(.Egress, .RuleNumber)'
}

list_network_acl_names() {
  local profile="${1:-}"
  local region="${2:-}"
  local args=()
  [[ -n "$profile" ]] && args+=(--profile "$profile")
  [[ -n "$region" ]] && args+=(--region "$region")
  aws "${args[@]}" ec2 describe-network-acls --output json 2>/dev/null | jq -r '.NetworkAcls[] | (.Tags[]? | select(.Key=="Name") | .Value) // .NetworkAclId' | sort -u
}
