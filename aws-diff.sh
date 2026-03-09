#!/usr/bin/env bash
# AWS resource config diff - compare configs across environments

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") <resource_type> <from_name> <to_name> [options]

Compare AWS resource configs between two environments.

Arguments:
  resource_type   e.g. iam-role
  from_name       Resource name in from environment
  to_name         Resource name in to environment

Options:
  --from-profile PROFILE   AWS profile for from environment
  --to-profile PROFILE     AWS profile for to environment
  --env-id PATTERN         Regex to strip env prefix (match -> empty string)
  --replace PAT REPL       Custom replacement (pattern, replacement)
  --replace-file PATH      File with pattern<TAB>replacement lines
  --no-default-exclude     Skip default exclusions (ARN, ID, timestamps)

Example:
  $(basename "$0") iam-role Dev-MyRole1 Com-MyRole1 --env-id '(Dev-|Com-)'
EOF
  exit 1
}

main() {
  [[ $# -lt 3 ]] && usage

  local resource_type="$1"
  local from_name="$2"
  local to_name="$3"
  shift 3

  local from_profile=""
  local to_profile=""
  local env_id_pattern=""
  local replace_patterns=()
  local replace_file=""
  local no_default_exclude=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from-profile)
        from_profile="$2"
        shift 2
        ;;
      --to-profile)
        to_profile="$2"
        shift 2
        ;;
      --env-id)
        env_id_pattern="$2"
        shift 2
        ;;
      --replace)
        [[ $# -lt 3 ]] && die "--replace requires pattern and replacement"
        replace_patterns+=("$2"$'\t'"$3")
        shift 3
        ;;
      --replace-file)
        replace_file="$2"
        shift 2
        ;;
      --no-default-exclude)
        no_default_exclude=true
        shift
        ;;
      -h|--help)
        usage
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done

  # Add env-id as pattern -> empty replacement
  [[ -n "$env_id_pattern" ]] && replace_patterns+=("$env_id_pattern"$'\t'"")
  # Load replace-file
  if [[ -n "$replace_file" && -f "$replace_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      replace_patterns+=("$line")
    done < "$replace_file"
  fi

  local fetch_fn
  case "$resource_type" in
    iam-role)
      source "$SCRIPT_DIR/lib/resources/iam-role.sh"
      fetch_fn="fetch_iam_role_config"
      ;;
    *)
      die "Unknown resource type: $resource_type"
      ;;
  esac

  ensure_jq

  local from_json to_json
  from_json=$($fetch_fn "$from_name" "$from_profile")
  to_json=$($fetch_fn "$to_name" "$to_profile")

  from_json=$(echo "$from_json" | jq -c .)
  to_json=$(echo "$to_json" | jq -c .)

  from_json=$(normalize_json "$from_json")
  to_json=$(normalize_json "$to_json")

  if [[ "$no_default_exclude" != "true" ]]; then
    from_json=$(apply_default_exclusions "$from_json")
    to_json=$(apply_default_exclusions "$to_json")
  fi

  if [[ ${#replace_patterns[@]} -gt 0 ]]; then
    from_json=$(apply_replacements "$from_json" "${replace_patterns[@]}")
    to_json=$(apply_replacements "$to_json" "${replace_patterns[@]}")
  fi

  run_diff "$from_json" "$to_json"
}

main "$@"
