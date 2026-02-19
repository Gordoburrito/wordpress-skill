#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: export-acf-json.sh

Export all ACF field groups from the WordPress database to JSON files
on the remote server (into the ACF save_json directory).
Then pull the exported files to the local schema repo.

Options:
  --schema-repo <path>   Local schema repo path (required for auto-pull)
  --no-pull              Export on server only, skip pulling to local
  -h, --help             Show this help
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "=> $*"
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

SCHEMA_REPO=""
NO_PULL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --schema-repo) SCHEMA_REPO="$2"; shift 2 ;;
    --no-pull) NO_PULL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

load_target_config

info "Uploading export script to remote..."
ssh_run "cat > /tmp/_acf_export.php" << 'PHPEOF'
<?php
/**
 * Export all ACF field groups to JSON files in the save_json directory.
 * Run via: wp eval-file /tmp/_acf_export.php
 */

if ( ! function_exists( 'acf_get_field_groups' ) ) {
    WP_CLI::error( 'ACF is not active.' );
}

$groups = acf_get_field_groups();
if ( empty( $groups ) ) {
    WP_CLI::warning( 'No ACF field groups found in the database.' );
    exit( 0 );
}

$save_path = acf_get_setting( 'save_json' );
if ( is_array( $save_path ) ) {
    $save_path = reset( $save_path );
}
if ( empty( $save_path ) ) {
    WP_CLI::error( 'ACF save_json path is not configured.' );
}

if ( ! is_dir( $save_path ) ) {
    if ( ! mkdir( $save_path, 0755, true ) ) {
        WP_CLI::error( "Cannot create directory: {$save_path}" );
    }
}

$exported = 0;
foreach ( $groups as $group ) {
    $group['fields'] = acf_get_fields( $group['key'] );

    // Include the full field group data that ACF expects.
    $json = wp_json_encode( $group, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE );
    if ( ! $json ) {
        WP_CLI::warning( "Failed to encode group: {$group['key']}" );
        continue;
    }

    $filename = $save_path . '/' . $group['key'] . '.json';
    if ( file_put_contents( $filename, $json ) !== false ) {
        WP_CLI::log( "Exported: {$group['key']} -> {$filename}" );
        $exported++;
    } else {
        WP_CLI::warning( "Failed to write: {$filename}" );
    }
}

WP_CLI::success( "Exported {$exported} field group(s) to {$save_path}" );
PHPEOF

info "Running ACF export on remote..."
ssh_run_env "wp --path='${TARGET_WP_ROOT}' eval-file /tmp/_acf_export.php"

info "Cleaning up remote temp file..."
ssh_run "rm -f /tmp/_acf_export.php"

if [[ "${NO_PULL}" -eq 0 ]] && [[ -n "${SCHEMA_REPO}" ]]; then
  info "Pulling exported JSON to local repo..."
  "${SCRIPT_DIR}/pull.sh" --schema-repo "${SCHEMA_REPO}"
else
  echo ""
  echo "Export complete on server. Run pull.sh to fetch locally:"
  echo "  scripts/pull.sh --schema-repo <path>"
fi
