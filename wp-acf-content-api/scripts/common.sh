#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
TARGET_CONFIG="${SKILL_ROOT}/config/target-api.sh"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || fail "Required command not found: ${cmd}"
}

normalize_base_url() {
  local value="$1"
  value="${value%/}"
  printf '%s' "${value}"
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

is_allowed_resource_type() {
  local requested="$1"
  local allowed_csv="$2"
  local normalized
  normalized=",${allowed_csv//[[:space:]]/},"
  [[ "${normalized}" == *",${requested},"* ]]
}

load_api_config() {
  [[ -f "${TARGET_CONFIG}" ]] || fail "Missing config file: ${TARGET_CONFIG}"
  # shellcheck disable=SC1090
  source "${TARGET_CONFIG}"

  : "${WP_API_BASE_URL:?WP_API_BASE_URL must be set in config/target-api.sh}"
  : "${WP_API_USERNAME:?WP_API_USERNAME must be set in config/target-api.sh}"

  WP_API_TIMEOUT_SECONDS="${WP_API_TIMEOUT_SECONDS:-30}"
  DEFAULT_RESOURCE_TYPE="${DEFAULT_RESOURCE_TYPE:-pages}"
  ALLOWED_RESOURCE_TYPES="${ALLOWED_RESOURCE_TYPES:-pages,posts}"
  ACF_FIELD_ALLOWLIST_FILE="${ACF_FIELD_ALLOWLIST_FILE:-${SKILL_ROOT}/runtime/allowed-field-keys.txt}"

  WP_API_BASE_URL="$(normalize_base_url "${WP_API_BASE_URL}")"
}

require_api_auth() {
  # WP_API_APP_PASSWORD can come from config/target-api.sh or environment.
  # Environment variable overrides the config value if both are set.
  [[ -n "${WP_API_APP_PASSWORD:-}" ]] || fail "WP_API_APP_PASSWORD is required (set in config/target-api.sh or environment)."
  CURL_AUTH_ARGS=(--user "${WP_API_USERNAME}:${WP_API_APP_PASSWORD}")
}

build_resource_url() {
  local resource_type="$1"
  local resource_id="$2"
  printf '%s/wp-json/wp/v2/%s/%s' "${WP_API_BASE_URL}" "${resource_type}" "${resource_id}"
}
