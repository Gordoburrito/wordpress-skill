#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: push.sh --schema-repo <abs-path> [--dry-run] [--allow-field-key-changes] [--expected-hash <hash>]

Push local wp-content/acf-json/group_*.json to the WordPress plugin API.
Validation is enforced server-side by the plugin.
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
ALLOW_FIELD_KEY_CHANGES=0
EXPECTED_HASH=""

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
    --allow-field-key-changes)
      ALLOW_FIELD_KEY_CHANGES=1
      shift
      ;;
    --expected-hash)
      [[ $# -ge 2 ]] || fail "Missing value for --expected-hash"
      EXPECTED_HASH="$2"
      shift 2
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

local_acf_dir="${SCHEMA_REPO}/wp-content/acf-json"
[[ -d "${local_acf_dir}" ]] || fail "Missing directory: ${local_acf_dir}"

require_command curl
require_command jq
require_command openssl

echo "Loading workspace environment..."
load_target_config

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

group_files=()
while IFS= read -r file; do
  [[ -n "${file}" ]] && group_files+=("${file}")
done < <(find "${local_acf_dir}" -maxdepth 1 -type f -name 'group_*.json' | sort)
[[ "${#group_files[@]}" -gt 0 ]] || fail "No group_*.json files found in ${local_acf_dir}"

for file in "${group_files[@]}"; do
  jq -e 'type == "object" and (.key | strings | startswith("group_"))' "${file}" >/dev/null \
    || fail "Invalid field group JSON file: ${file}"
done

field_groups_file="${tmp_dir}/field-groups.json"
jq -s '.' "${group_files[@]}" > "${field_groups_file}"

if [[ -z "${EXPECTED_HASH}" ]]; then
  pull_payload="${tmp_dir}/pull-hash-request.json"
  pull_response="${tmp_dir}/pull-hash-response.raw.json"
  jq -n '{include_groups: false}' > "${pull_payload}"
  api_post_json "${PULL_URL}" "${pull_payload}" "${pull_response}"
  EXPECTED_HASH="$(jq -r '.schema_hash // empty' "${pull_response}")"
  [[ -n "${EXPECTED_HASH}" ]] || fail "Unable to resolve expected_hash from pull endpoint."
fi

payload_file="${tmp_dir}/push-request.json"
response_raw="${tmp_dir}/push-response.raw.json"
runtime_dir="${SCHEMA_REPO}/runtime"
response_pretty="${runtime_dir}/schema-push-response.json"
mkdir -p "${runtime_dir}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  dry_run_json=true
else
  dry_run_json=false
fi

if [[ "${ALLOW_FIELD_KEY_CHANGES}" -eq 1 ]]; then
  allow_keys_json=true
else
  allow_keys_json=false
fi

jq -n \
  --arg expected_hash "${EXPECTED_HASH}" \
  --argjson dry_run "${dry_run_json}" \
  --argjson allow_field_key_changes "${allow_keys_json}" \
  --slurpfile groups "${field_groups_file}" \
  '{
    expected_hash: $expected_hash,
    dry_run: $dry_run,
    allow_field_key_changes: $allow_field_key_changes,
    field_groups: $groups[0]
  }' > "${payload_file}"

build_push_signature_headers "${payload_file}"
echo "Calling push endpoint: ${PUSH_URL}"
api_post_json "${PUSH_URL}" "${payload_file}" "${response_raw}" "${PUSH_SIGNATURE_HEADERS[@]}"
json_pretty_write "${response_raw}" "${response_pretty}"

jq -e '.plan and .current_hash and .incoming_hash' "${response_raw}" >/dev/null \
  || fail "Push response missing required fields."

plan_create="$(jq -r '.plan.create_count // 0' "${response_raw}")"
plan_update="$(jq -r '.plan.update_count // 0' "${response_raw}")"
plan_unchanged="$(jq -r '.plan.unchanged_count // 0' "${response_raw}")"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "Push dry-run completed."
  echo "Plan: create=${plan_create} update=${plan_update} unchanged=${plan_unchanged}"
  echo "response=${response_pretty}"
  exit 0
fi

jq -e '.applied == true and .schema_hash_after' "${response_raw}" >/dev/null \
  || fail "Push apply response missing required fields (applied/schema_hash_after)."

schema_hash_after="$(jq -r '.schema_hash_after' "${response_raw}")"
echo "Push applied."
echo "Plan: create=${plan_create} update=${plan_update} unchanged=${plan_unchanged}"
echo "schema_hash_after=${schema_hash_after}"
echo "response=${response_pretty}"
