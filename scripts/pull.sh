#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: pull.sh --schema-repo <abs-path> [--dry-run]

Pull ACF JSON from the remote WordPress target into the local schema repo.
This is the reverse of deploy-main.sh — rsync from server to local.
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
DRY_RUN=0

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

require_command rsync

echo "Loading target config..."
load_target_config

# Verify SSH connectivity.
echo "Testing SSH connection..."
if ! ssh_run "true"; then
  fail "Unable to connect to ${SSH_TARGET} over SSH."
fi

# Verify remote acf-json directory exists.
if ! ssh_run "test -d '${TARGET_REMOTE_ACF_JSON_PATH}'"; then
  fail "Remote ACF JSON directory does not exist: ${TARGET_REMOTE_ACF_JSON_PATH}"
fi

# Create local destination if needed.
local_acf_dir="${SCHEMA_REPO}/wp-content/acf-json"
mkdir -p "${local_acf_dir}"

rsync_args=(-az --itemize-changes)
if [[ "${DRY_RUN}" -eq 1 ]]; then
  rsync_args+=(--dry-run)
  echo "Dry-run mode enabled."
fi

source_dir="${SSH_TARGET}:$(normalize_path "${TARGET_REMOTE_ACF_JSON_PATH}")/"
destination="${local_acf_dir}/"

echo "Pulling ACF JSON from remote target..."
echo "  Source: ${source_dir}"
echo "  Dest:   ${destination}"
rsync "${rsync_args[@]}" -e "$(rsync_ssh_cmd)" "${source_dir}" "${destination}"

file_count="$(find "${local_acf_dir}" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
echo "Pull completed. ${file_count} JSON file(s) in ${local_acf_dir}."
