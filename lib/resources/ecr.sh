#!/usr/bin/env bash
# ECR repository resource module for aws-diff

fetch_ecr_config() {
  local repo_name="$1"
  local profile="${2:-}"
  local region="${3:-}"

  _aws_ecr() {
    local args=()
    [[ -n "$profile" ]] && args+=(--profile "$profile")
    [[ -n "$region" ]] && args+=(--region "$region")
    aws "${args[@]}" ecr "$@"
  }

  local repo_json
  repo_json=$(_aws_ecr describe-repositories --repository-names "$repo_name" --output json 2>/dev/null | jq -c '.repositories[0]') || die "Failed to get repository: $repo_name"
  [[ -z "$repo_json" || "$repo_json" == "null" ]] && die "Repository not found: $repo_name"

  local lifecycle
  lifecycle=$(_aws_ecr get-lifecycle-policy --repository-name "$repo_name" --output json 2>/dev/null | jq -c '.lifecyclePolicyText') || lifecycle='null'
  if [[ -n "$lifecycle" && "$lifecycle" != "null" ]]; then
    lifecycle=$(echo "$lifecycle" | python3 -c "import urllib.parse,sys; print(urllib.parse.unquote(sys.stdin.read()))" 2>/dev/null || echo "$lifecycle")
    lifecycle=$(echo "$lifecycle" | jq -c -S . 2>/dev/null || echo "$lifecycle")
  fi

  jq -n \
    --argjson repo "$repo_json" \
    --argjson lifecycle "$lifecycle" \
    '{Repository: $repo, LifecyclePolicy: $lifecycle}'
}

list_ecr_names() {
  local profile="${1:-}"
  local region="${2:-}"
  local args=()
  [[ -n "$profile" ]] && args+=(--profile "$profile")
  [[ -n "$region" ]] && args+=(--region "$region")
  aws "${args[@]}" ecr describe-repositories --output json 2>/dev/null | jq -r '.repositories[].repositoryName' || true
}
