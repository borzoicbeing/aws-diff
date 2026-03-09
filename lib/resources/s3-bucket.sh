#!/usr/bin/env bash
# S3 bucket resource module for aws-diff

fetch_s3_bucket_config() {
  local bucket_name="$1"
  local profile="${2:-}"

  _aws_s3() {
    if [[ -n "$profile" ]]; then
      aws --profile "$profile" "$@"
    else
      aws "$@"
    fi
  }

  local acl policy versioning public_access encryption
  acl=$(_aws_s3 s3api get-bucket-acl --bucket "$bucket_name" --output json 2>/dev/null) || acl='{}'
  policy=$(_aws_s3 s3api get-bucket-policy --bucket "$bucket_name" --output json 2>/dev/null) || policy='{}'
  versioning=$(_aws_s3 s3api get-bucket-versioning --bucket "$bucket_name" --output json 2>/dev/null) || versioning='{}'
  public_access=$(_aws_s3 s3api get-public-access-block --bucket "$bucket_name" --output json 2>/dev/null) || public_access='{}'
  encryption=$(_aws_s3 s3api get-bucket-encryption --bucket "$bucket_name" --output json 2>/dev/null) || encryption='{}'

  # Ensure valid JSON for each (AWS errors or empty output may return non-JSON)
  acl=$(echo "$acl" | jq -c . 2>/dev/null); [[ -z "$acl" ]] && acl='{}'
  policy=$(echo "$policy" | jq -c . 2>/dev/null); [[ -z "$policy" ]] && policy='{}'
  versioning=$(echo "$versioning" | jq -c . 2>/dev/null); [[ -z "$versioning" ]] && versioning='{}'
  public_access=$(echo "$public_access" | jq -c . 2>/dev/null); [[ -z "$public_access" ]] && public_access='{}'
  encryption=$(echo "$encryption" | jq -c . 2>/dev/null); [[ -z "$encryption" ]] && encryption='{}'

  jq -n \
    --argjson acl "$acl" \
    --argjson policy "$policy" \
    --argjson versioning "$versioning" \
    --argjson public_access "$public_access" \
    --argjson encryption "$encryption" \
    '{Acl: $acl, Policy: $policy, Versioning: $versioning, PublicAccessBlock: $public_access, Encryption: $encryption}'
}

list_s3_bucket_names() {
  local profile="${1:-}"
  if [[ -n "$profile" ]]; then
    aws s3api list-buckets --profile "$profile" --output json 2>/dev/null | jq -r '.Buckets[].Name'
  else
    aws s3api list-buckets --output json 2>/dev/null | jq -r '.Buckets[].Name'
  fi
}
