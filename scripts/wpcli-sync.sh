#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: wpcli-sync.sh [--dry-run]

Run post-deploy WP-CLI sync command on the locked main target after verification.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
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

load_target_config
verify_remote_prereqs

if [[ -z "${WPCLI_SYNC_COMMAND:-}" ]]; then
  fail "WPCLI_SYNC_COMMAND is required in config/target-main.sh"
fi

echo "Using WP-CLI sync command: ${WPCLI_SYNC_COMMAND}"
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "Dry-run mode enabled. Skipping remote execution."
  exit 0
fi

echo "Running WP-CLI sync command on remote target..."
ssh_run_env "cd '${TARGET_WP_ROOT}' && ${WPCLI_SYNC_COMMAND}"

echo "WP-CLI sync completed."
