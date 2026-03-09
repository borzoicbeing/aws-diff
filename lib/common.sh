#!/usr/bin/env bash
# Common functions for aws-diff

set -euo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() {
  echo "Error: $*" >&2
  exit 1
}

ensure_jq() {
  if ! command -v jq &>/dev/null; then
    die "jq is required but not installed. Install with: brew install jq"
  fi
}

normalize_json() {
  local json="$1"
  ensure_jq
  echo "$json" | jq -S .
}

apply_default_exclusions() {
  local json="$1"
  # Use perl for reliable regex (macOS sed has quirks)
  if command -v perl &>/dev/null; then
    echo "$json" | perl -pe '
      s/arn:aws:[^"]+/ARN_PLACEHOLDER/g;
      s/A(ROA|IDA|NPA)[A-Z0-9]+/ID_PLACEHOLDER/g;
      s/\d{4}-\d{2}-\d{2}T[\d:.]+(Z|\+\d{2}:\d{2})/TIMESTAMP_PLACEHOLDER/g;
      s/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/UUID_PLACEHOLDER/gi;
      s/acl-[a-z0-9]+/ID_PLACEHOLDER/g;
      s/vpce-[a-z0-9]+/ID_PLACEHOLDER/g;
      s/sg-[a-z0-9]+/ID_PLACEHOLDER/g;
      s/rtb-[a-z0-9]+/ID_PLACEHOLDER/g;
      s/vpc-[a-z0-9]+/ID_PLACEHOLDER/g;
      s/subnet-[a-z0-9]+/ID_PLACEHOLDER/g;
    '
  else
    # Fallback to sed -E
    echo "$json" | sed -E \
      -e 's/arn:aws:[^"]+/ARN_PLACEHOLDER/g' \
      -e 's/A(ROA|IDA|NPA)[A-Z0-9]+/ID_PLACEHOLDER/g' \
      -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+(Z|\+[0-9]{2}:[0-9]{2})/TIMESTAMP_PLACEHOLDER/g' \
      -e 's/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/UUID_PLACEHOLDER/gi' \
      -e 's/acl-[a-z0-9]+/ID_PLACEHOLDER/g' \
      -e 's/vpce-[a-z0-9]+/ID_PLACEHOLDER/g' \
      -e 's/sg-[a-z0-9]+/ID_PLACEHOLDER/g' \
      -e 's/rtb-[a-z0-9]+/ID_PLACEHOLDER/g' \
      -e 's/vpc-[a-z0-9]+/ID_PLACEHOLDER/g' \
      -e 's/subnet-[a-z0-9]+/ID_PLACEHOLDER/g'
  fi
}

apply_replacements() {
  local json="$1"
  shift
  local patterns=("$@")

  local result="$json"
  for entry in "${patterns[@]}"; do
    [[ -z "$entry" ]] && continue
    local pattern replacement
    pattern="${entry%%$'\t'*}"
    replacement="${entry#*$'\t'}"
    [[ "$entry" == *$'\t'* ]] || replacement=""
    [[ -z "$pattern" ]] && continue

    if command -v perl &>/dev/null; then
      result=$(echo "$result" | PATTERN="$pattern" REPLACEMENT="$replacement" perl -pe 's/$ENV{PATTERN}/$ENV{REPLACEMENT}/g')
    else
      result=$(echo "$result" | sed -E "s|$pattern|$replacement|g")
    fi
  done
  echo "$result"
}

run_diff() {
  local from="$1"
  local to="$2"
  if command -v colordiff &>/dev/null; then
    diff -u <(echo "$from") <(echo "$to") | colordiff
  elif diff --color &>/dev/null 2>&1; then
    diff -u <(echo "$from") <(echo "$to") --color
  else
    diff -u <(echo "$from") <(echo "$to")
  fi
}
