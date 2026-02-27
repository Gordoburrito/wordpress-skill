#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: pull.sh --schema-repo <abs-path> [--dry-run] [--prune]

Pull ACF schema from the WordPress plugin API into local wp-content/acf-json/.
This script writes one pretty JSON file per field group (group_*.json).
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./api-common.sh
source "${SCRIPT_DIR}/api-common.sh"

SCHEMA_REPO=""
DRY_RUN=0
PRUNE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --schema-repo)
      [[ $# -ge 2 ]] || fail "Missing value for --schema-repo"
      SCHEMA_REPO="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --prune)
      PRUNE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "${SCHEMA_REPO}" ]] || fail "--schema-repo is required"
[[ -d "${SCHEMA_REPO}" ]] || fail "Schema repo not found: ${SCHEMA_REPO}"

require_command curl
require_command jq

echo "Loading API target config..."
load_target_config

local_acf_dir="${SCHEMA_REPO}/wp-content/acf-json"
runtime_dir="${SCHEMA_REPO}/runtime"
mkdir -p "${local_acf_dir}" "${runtime_dir}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT
payload_file="${tmp_dir}/pull-request.json"
response_raw="${tmp_dir}/pull-response.raw.json"
response_pretty="${runtime_dir}/schema-pull-response.json"

jq -n '{include_groups: true}' > "${payload_file}"
echo "Calling pull endpoint: ${PULL_URL}"
api_post_json "${PULL_URL}" "${payload_file}" "${response_raw}"
json_pretty_write "${response_raw}" "${response_pretty}"

jq -e '.schema_hash and (.field_groups | type == "array")' "${response_raw}" >/dev/null \
  || fail "Pull response missing required fields (schema_hash, field_groups)."

schema_hash="$(jq -r '.schema_hash' "${response_raw}")"
group_count="$(jq -r '.group_count // (.field_groups | length)' "${response_raw}")"

group_keys=()
while IFS= read -r group_key; do
  [[ -n "${group_key}" ]] && group_keys+=("${group_key}")
done < <(jq -r '.field_groups[] | .key // empty' "${response_raw}" | sort)
[[ "${#group_keys[@]}" -gt 0 ]] || fail "No field groups returned by pull endpoint."

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "Dry-run mode: no local files were modified."
  echo "schema_hash=${schema_hash} group_count=${group_count}"
  echo "response=${response_pretty}"
  exit 0
fi

for group_key in "${group_keys[@]}"; do
  [[ -n "${group_key}" ]] || continue
  target_file="${local_acf_dir}/${group_key}.json"
  jq --arg group_key "${group_key}" '.field_groups[] | select(.key == $group_key)' "${response_raw}" > "${target_file}"
done

if [[ "${PRUNE}" -eq 1 ]]; then
  local_files=()
  while IFS= read -r local_file; do
    [[ -n "${local_file}" ]] && local_files+=("${local_file}")
  done < <(find "${local_acf_dir}" -maxdepth 1 -type f -name 'group_*.json' | sort)
  for local_file in "${local_files[@]}"; do
    local_basename="$(basename "${local_file}")"
    local_group_key="${local_basename%.json}"
    if ! jq -e --arg group_key "${local_group_key}" '.field_groups[] | select(.key == $group_key)' "${response_raw}" >/dev/null; then
      rm -f "${local_file}"
    fi
  done
fi

file_count="$(find "${local_acf_dir}" -maxdepth 1 -type f -name 'group_*.json' | wc -l | tr -d ' ')"
echo "Pull completed. schema_hash=${schema_hash} group_count=${group_count} local_files=${file_count}"
echo "response=${response_pretty}"
