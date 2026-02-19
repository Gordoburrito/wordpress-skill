#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
TARGET_CONFIG="${SKILL_ROOT}/config/target-main.sh"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || fail "Required command not found: ${cmd}"
}

normalize_path() {
  local path="$1"
  path="${path%/}"
  if [[ -z "${path}" ]]; then
    path="/"
  fi
  printf '%s' "${path}"
}

load_target_config() {
  [[ -f "${TARGET_CONFIG}" ]] || fail "Missing target config: ${TARGET_CONFIG}"
  # shellcheck disable=SC1090
  source "${TARGET_CONFIG}"

  : "${TARGET_SSH_HOST:?TARGET_SSH_HOST must be set in config/target-main.sh}"
  : "${TARGET_WP_ROOT:?TARGET_WP_ROOT must be set in config/target-main.sh}"
  : "${TARGET_REMOTE_ACF_JSON_PATH:?TARGET_REMOTE_ACF_JSON_PATH must be set in config/target-main.sh}"

  TARGET_SSH_PORT="${TARGET_SSH_PORT:-22}"
  if [[ -n "${TARGET_SSH_USER:-}" ]]; then
    SSH_TARGET="${TARGET_SSH_USER}@${TARGET_SSH_HOST}"
  else
    SSH_TARGET="${TARGET_SSH_HOST}"
  fi
  SSH_OPTS=(-p "${TARGET_SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=yes)
  if [[ -n "${TARGET_SSH_KEY:-}" ]]; then
    [[ -f "${TARGET_SSH_KEY}" ]] || fail "SSH key not found: ${TARGET_SSH_KEY}"
    SSH_OPTS+=(-i "${TARGET_SSH_KEY}")
  fi

  # Build a prefix for remote commands that puts PHP in PATH.
  REMOTE_ENV_PREFIX=""
  if [[ -n "${TARGET_REMOTE_PHP_DIR:-}" ]]; then
    REMOTE_ENV_PREFIX="export PATH=${TARGET_REMOTE_PHP_DIR}:\$PATH && "
  fi
}

ssh_run() {
  ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" "$@"
}

# Run a command on the remote with PHP in PATH.
ssh_run_env() {
  ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" "${REMOTE_ENV_PREFIX}$*"
}

# rsync SSH command string (for use with rsync -e).
rsync_ssh_cmd() {
  local cmd="ssh -p ${TARGET_SSH_PORT}"
  if [[ -n "${TARGET_SSH_KEY:-}" ]]; then
    cmd+=" -i ${TARGET_SSH_KEY}"
  fi
  cmd+=" -o BatchMode=yes -o StrictHostKeyChecking=yes"
  printf '%s' "${cmd}"
}

verify_remote_prereqs() {
  local remote_home
  local remote_save_json
  local normalized_expected
  local normalized_remote

  require_command ssh

  if ! ssh_run "true"; then
    fail "Unable to connect to ${SSH_TARGET} over SSH."
  fi

  if ! ssh_run_env "command -v wp >/dev/null 2>&1"; then
    fail "WP-CLI is required but not available on ${SSH_TARGET}."
  fi

  if ! ssh_run "test -d '${TARGET_WP_ROOT}'"; then
    fail "Configured TARGET_WP_ROOT does not exist on remote host: ${TARGET_WP_ROOT}"
  fi

  if ! ssh_run "test -d '${TARGET_REMOTE_ACF_JSON_PATH}'"; then
    fail "Configured TARGET_REMOTE_ACF_JSON_PATH does not exist on remote host: ${TARGET_REMOTE_ACF_JSON_PATH}"
  fi

  remote_home="$(ssh_run_env "wp --path='${TARGET_WP_ROOT}' option get home" 2>/dev/null | tr -d '\r')"
  if [[ -z "${remote_home}" ]]; then
    fail "WP-CLI sanity check failed: 'wp option get home' returned an empty value."
  fi

  # Use eval-file via a temp script to avoid nested-quoting issues.
  ssh_run_env "cat > /tmp/_acf_check.php << 'ACFEOF'
<?php
if (!function_exists('acf_get_setting')) { fwrite(STDERR, \"ACF is unavailable in WP-CLI context.\n\"); exit(8); }
\$save = acf_get_setting('save_json');
if (is_array(\$save)) { \$save = reset(\$save); }
if (!is_string(\$save) || \$save === '') { fwrite(STDERR, \"ACF save_json is empty.\n\"); exit(9); }
echo \$save;
ACFEOF"
  remote_save_json="$(ssh_run_env "wp --path='${TARGET_WP_ROOT}' eval-file /tmp/_acf_check.php" 2>/dev/null | tr -d '\r')"
  ssh_run "rm -f /tmp/_acf_check.php"
  remote_save_json="$(printf '%s' "${remote_save_json}" | tr -d '\r')"

  normalized_expected="$(normalize_path "${TARGET_REMOTE_ACF_JSON_PATH}")"
  normalized_remote="$(normalize_path "${remote_save_json}")"
  if [[ "${normalized_expected}" != "${normalized_remote}" ]]; then
    fail "Remote ACF save_json path mismatch. Config=${normalized_expected} Remote=${normalized_remote}"
  fi
}
