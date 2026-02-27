#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build-allowlist.sh --schema-repo <abs-path> [--out <path>]

Generate allowlisted ACF field names and field keys from local schema JSON files.

Outputs:
  runtime/allowed-field-names.txt  — human-readable names (used by push-content.sh)
  runtime/allowed-field-keys.txt   — internal field_* keys (reference/audit)
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

SCHEMA_REPO=""
OUT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --schema-repo)
      [[ $# -ge 2 ]] || fail "Missing value for --schema-repo"
      SCHEMA_REPO="$2"
      shift 2
      ;;
    --out)
      [[ $# -ge 2 ]] || fail "Missing value for --out"
      OUT_PATH="$2"
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
require_command jq

load_api_config
if [[ -z "${OUT_PATH}" ]]; then
  OUT_PATH="${ACF_FIELD_ALLOWLIST_FILE}"
fi

acf_dir="${SCHEMA_REPO}/wp-content/acf-json"
[[ -d "${acf_dir}" ]] || fail "Missing directory: ${acf_dir}"

tmp_keys="$(mktemp)"
tmp_names="$(mktemp)"
files_found=0

while IFS= read -r -d '' file; do
  files_found=1
  # Extract field_* keys (internal identifiers)
  jq -r '.. | objects | .key? // empty | select(type=="string" and startswith("field_"))' "${file}" >> "${tmp_keys}"
  # Extract field names (what the REST API uses)
  jq -r '.. | objects | select(.key? // "" | startswith("field_")) | .name // empty | select(type=="string" and length > 0)' "${file}" >> "${tmp_names}"
done < <(find "${acf_dir}" -type f -name '*.json' -print0)

if [[ "${files_found}" -eq 0 ]]; then
  rm -f "${tmp_keys}" "${tmp_names}"
  fail "No JSON files found under ${acf_dir}"
fi

sort -u "${tmp_keys}" > "${tmp_keys}.sorted"
mv "${tmp_keys}.sorted" "${tmp_keys}"
sort -u "${tmp_names}" > "${tmp_names}.sorted"
mv "${tmp_names}.sorted" "${tmp_names}"

if [[ ! -s "${tmp_keys}" ]]; then
  rm -f "${tmp_keys}" "${tmp_names}"
  fail "No field keys detected in schema JSON."
fi
if [[ ! -s "${tmp_names}" ]]; then
  rm -f "${tmp_keys}" "${tmp_names}"
  fail "No field names detected in schema JSON."
fi

mkdir -p "$(dirname -- "${OUT_PATH}")"
mv "${tmp_keys}" "${OUT_PATH}"

# Field names list goes alongside the keys list
NAMES_OUT="${SKILL_ROOT}/runtime/allowed-field-names.txt"
mkdir -p "$(dirname -- "${NAMES_OUT}")"
mv "${tmp_names}" "${NAMES_OUT}"

echo "Field keys allowlist: ${OUT_PATH}"
echo "  Key count: $(wc -l < "${OUT_PATH}" | tr -d ' ')"
echo "Field names allowlist: ${NAMES_OUT}"
echo "  Name count: $(wc -l < "${NAMES_OUT}" | tr -d ' ')"
