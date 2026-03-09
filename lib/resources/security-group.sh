#!/usr/bin/env bash
# Security Group resource module for aws-diff

fetch_security_group_config() {
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
  if [[ "$name" == sg-* ]]; then
    result=$(_aws_ec2 describe-security-groups --group-ids "$name" --output json 2>/dev/null) || die "Failed to get security group: $name"
  else
    result=$(_aws_ec2 describe-security-groups --filters "Name=group-name,Values=$name" --output json 2>/dev/null) || die "Failed to get security group: $name"
  fi

  local sg
  sg=$(echo "$result" | jq -c '.SecurityGroups[0]')
  [[ -z "$sg" || "$sg" == "null" ]] && die "Security group not found: $name"

  echo "$sg" | jq -c '.IpPermissions |= sort_by(.FromPort // 0, .ToPort // 0) | .IpPermissionsEgress |= sort_by(.FromPort // 0, .ToPort // 0)'
}

list_security_group_names() {
  local profile="${1:-}"
  local region="${2:-}"
  local args=()
  [[ -n "$profile" ]] && args+=(--profile "$profile")
  [[ -n "$region" ]] && args+=(--region "$region")
  aws "${args[@]}" ec2 describe-security-groups --output json 2>/dev/null | jq -r '.SecurityGroups[].GroupName' | sort -u
}
