#!/usr/bin/env bash
# IAM Role resource module for aws-diff

fetch_iam_role_config() {
  local role_name="$1"
  local profile="${2:-}"

  _aws_iam() {
    if [[ -n "$profile" ]]; then
      aws --profile "$profile" "$@"
    else
      aws "$@"
    fi
  }

  local role_json
  role_json=$(_aws_iam iam get-role --role-name "$role_name" --output json 2>/dev/null) || die "Failed to get role: $role_name"

  # Decode URL-encoded AssumeRolePolicyDocument and normalize key order
  local policy_doc
  policy_doc=$(echo "$role_json" | jq -r '.Role.AssumeRolePolicyDocument')
  if [[ -n "$policy_doc" && "$policy_doc" != "null" ]]; then
    # URL-decode if needed, then parse and canonicalize JSON for consistent diff
    policy_doc=$(echo "$policy_doc" | python3 -c "import urllib.parse,sys; print(urllib.parse.unquote(sys.stdin.read()))" 2>/dev/null || echo "$policy_doc")
    policy_doc=$(echo "$policy_doc" | jq -c -S . 2>/dev/null || echo "$policy_doc")
    role_json=$(echo "$role_json" | jq --arg doc "$policy_doc" '.Role.AssumeRolePolicyDocument = $doc')
  fi

  # Get attached managed policies (sort by PolicyName for order-independent diff)
  local attached
  attached=$(_aws_iam iam list-attached-role-policies --role-name "$role_name" --output json 2>/dev/null | jq -c '.AttachedPolicies | sort_by(.PolicyName)')

  # Get inline policies (sort by PolicyName for order-independent diff)
  local inline_names
  inline_names=$(_aws_iam iam list-role-policies --role-name "$role_name" --output json 2>/dev/null | jq -r '.PolicyNames[]? // empty')
  local inline_policies='[]'
  if [[ -n "$inline_names" ]]; then
    inline_policies=$(echo "$inline_names" | while read -r pname; do
      _aws_iam iam get-role-policy --role-name "$role_name" --policy-name "$pname" --output json 2>/dev/null | jq -c '{PolicyName: .PolicyName, PolicyDocument: .PolicyDocument}'
    done | jq -s 'sort_by(.PolicyName)')
  fi

  # Combine into single JSON
  jq -n \
    --argjson role "$(echo "$role_json" | jq -c '.Role')" \
    --argjson attached "$attached" \
    --argjson inline "$inline_policies" \
    '{Role: $role, AttachedPolicies: $attached, InlinePolicies: $inline}'
}

list_iam_role_names() {
  local profile="${1:-}"
  if [[ -n "$profile" ]]; then
    aws iam list-roles --profile "$profile" --output json 2>/dev/null | jq -r '.Roles[].RoleName'
  else
    aws iam list-roles --output json 2>/dev/null | jq -r '.Roles[].RoleName'
  fi
}
