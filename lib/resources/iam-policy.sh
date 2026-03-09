#!/usr/bin/env bash
# IAM Policy resource module for aws-diff (customer managed policies)

fetch_iam_policy_config() {
  local policy_name="$1"
  local profile="${2:-}"

  _aws_iam() {
    if [[ -n "$profile" ]]; then
      aws --profile "$profile" "$@"
    else
      aws "$@"
    fi
  }

  # Resolve policy name to ARN (customer managed, scope Local)
  local policy_arn
  policy_arn=$(_aws_iam iam list-policies --scope Local --output json 2>/dev/null | jq -r --arg name "$policy_name" '.Policies[] | select(.PolicyName == $name) | .Arn' | head -1)
  [[ -z "$policy_arn" || "$policy_arn" == "null" ]] && die "Failed to find policy: $policy_name"

  local policy_json
  policy_json=$(_aws_iam iam get-policy --policy-arn "$policy_arn" --output json 2>/dev/null) || die "Failed to get policy: $policy_arn"

  local default_version_id
  default_version_id=$(echo "$policy_json" | jq -r '.Policy.DefaultVersionId')
  [[ -z "$default_version_id" || "$default_version_id" == "null" ]] && die "Failed to get default version"

  local policy_version
  policy_version=$(_aws_iam iam get-policy-version --policy-arn "$policy_arn" --version-id "$default_version_id" --output json 2>/dev/null) || die "Failed to get policy version"

  # Decode URL-encoded PolicyDocument (if string) and normalize
  local policy_doc
  policy_doc=$(echo "$policy_version" | jq -r '.PolicyVersion.Document')
  if [[ -n "$policy_doc" && "$policy_doc" != "null" ]]; then
    # Document can be object (CLI) or URL-encoded string
    if [[ "$policy_doc" == "{"* ]]; then
      policy_doc=$(echo "$policy_doc" | jq -c -S . 2>/dev/null || echo "$policy_doc")
    else
      policy_doc=$(echo "$policy_doc" | python3 -c "import urllib.parse,sys; print(urllib.parse.unquote(sys.stdin.read()))" 2>/dev/null || echo "$policy_doc")
      policy_doc=$(echo "$policy_doc" | jq -c -S . 2>/dev/null || echo "$policy_doc")
    fi
    policy_version=$(echo "$policy_version" | jq --arg doc "$policy_doc" '.PolicyVersion.Document = $doc')
  fi

  jq -n \
    --argjson policy "$(echo "$policy_json" | jq -c '.Policy')" \
    --argjson version "$(echo "$policy_version" | jq -c '.PolicyVersion')" \
    '{Policy: $policy, PolicyVersion: $version}'
}

list_iam_policy_names() {
  local profile="${1:-}"
  if [[ -n "$profile" ]]; then
    aws iam list-policies --scope Local --profile "$profile" --output json 2>/dev/null | jq -r '.Policies[].PolicyName'
  else
    aws iam list-policies --scope Local --output json 2>/dev/null | jq -r '.Policies[].PolicyName'
  fi
}
