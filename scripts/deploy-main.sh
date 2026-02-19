#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: deploy-main.sh --schema-repo <abs-path> [--dry-run]

Deploy wp-content/acf-json from local schema repo to the locked main Plesk target.
Always runs validation first.
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
[[ -d "${SCHEMA_REPO}/wp-content/acf-json" ]] || fail "Missing directory: ${SCHEMA_REPO}/wp-content/acf-json"

require_command rsync

echo "Running validation before deploy..."
"${SCRIPT_DIR}/validate.sh" --schema-repo "${SCHEMA_REPO}"

echo "Loading target config..."
load_target_config

echo "Verifying remote prerequisites..."
verify_remote_prereqs

rsync_args=(-az --delete --itemize-changes)
if [[ "${DRY_RUN}" -eq 1 ]]; then
  rsync_args+=(--dry-run)
  echo "Dry-run mode enabled."
fi

source_dir="${SCHEMA_REPO}/wp-content/acf-json/"
destination="${SSH_TARGET}:$(normalize_path "${TARGET_REMOTE_ACF_JSON_PATH}")/"

echo "Deploying ACF JSON to main target..."
echo "  Source: ${source_dir}"
echo "  Dest:   ${destination}"
rsync "${rsync_args[@]}" -e "$(rsync_ssh_cmd)" "${source_dir}" "${destination}"

echo "Deploy step completed."
echo "Run scripts/wpcli-sync.sh to execute post-deploy WP-CLI sync/verify."
