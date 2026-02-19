#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: wp-remote.sh <wp-cli-command...>

Run a WP-CLI command on the remote target defined in config/target-main.sh.
The --path flag is automatically set to TARGET_WP_ROOT.

Examples:
  scripts/wp-remote.sh acf --help
  scripts/wp-remote.sh acf field-group list
  scripts/wp-remote.sh option get home
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  usage
  exit 0
fi

load_target_config

ssh_run_env "wp --path='${TARGET_WP_ROOT}' $*"
