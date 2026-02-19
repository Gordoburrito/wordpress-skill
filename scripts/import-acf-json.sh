#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: import-acf-json.sh [--dry-run]

Import ACF JSON files from the remote save_json directory into the WordPress
database. This is the post-deploy sync step that makes the WP admin UI
reflect changes pushed via deploy-main.sh.

The script:
  1. Reads all group_*.json / *.json files in TARGET_REMOTE_ACF_JSON_PATH
  2. For each file, compares the modified timestamp against the DB version
  3. Imports newer JSON into the database (creates or updates field groups)
  4. Reports what was synced

Options:
  --dry-run   Show what would be synced without writing to the database
  -h, --help  Show this help
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

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

load_target_config

info "Uploading import script to remote..."
ssh_run "cat > /tmp/_acf_import.php" << 'PHPEOF'
<?php
/**
 * Import ACF JSON files from the save_json directory into the WordPress database.
 * Handles both new field groups and updates to existing ones.
 * Run via: wp eval-file /tmp/_acf_import.php [--dry-run]
 */

if ( ! function_exists( 'acf_get_field_groups' ) ) {
    WP_CLI::error( 'ACF is not active.' );
}

$dry_run = ! empty( getenv( 'ACF_DRY_RUN' ) );
if ( $dry_run ) {
    WP_CLI::log( '[dry-run] No changes will be written to the database.' );
}

$save_path = acf_get_setting( 'save_json' );
if ( is_array( $save_path ) ) {
    $save_path = reset( $save_path );
}
if ( empty( $save_path ) || ! is_dir( $save_path ) ) {
    WP_CLI::error( "ACF save_json directory not found: {$save_path}" );
}

// Gather all JSON files.
$files = glob( $save_path . '/*.json' );
if ( empty( $files ) ) {
    WP_CLI::warning( "No JSON files found in {$save_path}" );
    exit( 0 );
}

// Get existing field groups from the database keyed by their ACF key.
$db_groups = acf_get_field_groups();
$db_map = [];
foreach ( $db_groups as $g ) {
    $db_map[ $g['key'] ] = $g;
}

$synced   = 0;
$skipped  = 0;
$created  = 0;

foreach ( $files as $file ) {
    $json = file_get_contents( $file );
    if ( ! $json ) {
        WP_CLI::warning( "Cannot read: {$file}" );
        continue;
    }

    $group = json_decode( $json, true );
    if ( ! is_array( $group ) || empty( $group['key'] ) ) {
        WP_CLI::warning( "Invalid ACF JSON (no key): {$file}" );
        continue;
    }

    $key   = $group['key'];
    $title = $group['title'] ?? $key;

    // Check if this group exists in the DB.
    if ( isset( $db_map[ $key ] ) ) {
        $db_modified   = (int) ( $db_map[ $key ]['modified'] ?? 0 );
        $json_modified = (int) ( $group['modified'] ?? 0 );

        if ( $json_modified <= $db_modified ) {
            WP_CLI::log( "  Skip (DB is current): {$title} ({$key})" );
            $skipped++;
            continue;
        }

        // Update existing group.
        if ( $dry_run ) {
            WP_CLI::log( "  [dry-run] Would sync: {$title} ({$key})" );
            $synced++;
            continue;
        }

        // Merge the DB post ID so ACF updates rather than creates.
        $group['ID'] = $db_map[ $key ]['ID'];
    } else {
        // New group not in DB yet.
        if ( $dry_run ) {
            WP_CLI::log( "  [dry-run] Would create: {$title} ({$key})" );
            $created++;
            continue;
        }

        // Remove any ID so ACF creates a new post.
        unset( $group['ID'] );
    }

    // Extract fields before saving the group.
    $fields = $group['fields'] ?? [];
    unset( $group['fields'] );

    // Import the field group.
    $group = acf_import_field_group( $group );
    if ( empty( $group ) ) {
        WP_CLI::warning( "Failed to import group: {$title} ({$key})" );
        continue;
    }

    // Import fields.
    if ( ! empty( $fields ) ) {
        foreach ( $fields as $field ) {
            $field['parent'] = $group['key'];
            acf_import_field( $field );
        }
    }

    if ( isset( $db_map[ $key ] ) ) {
        WP_CLI::log( "  Synced: {$title} ({$key})" );
        $synced++;
    } else {
        WP_CLI::log( "  Created: {$title} ({$key})" );
        $created++;
    }
}

$total = $synced + $created;
$verb  = $dry_run ? 'Would sync' : 'Synced';
WP_CLI::success( "{$verb} {$total} field group(s) ({$synced} updated, {$created} new, {$skipped} skipped)." );
PHPEOF

if [[ "${DRY_RUN}" -eq 1 ]]; then
  info "Running ACF import (dry-run)..."
  ssh_run_env "ACF_DRY_RUN=1 wp --path='${TARGET_WP_ROOT}' eval-file /tmp/_acf_import.php"
else
  info "Running ACF import..."
  ssh_run_env "wp --path='${TARGET_WP_ROOT}' eval-file /tmp/_acf_import.php"
fi

info "Cleaning up remote temp file..."
ssh_run "rm -f /tmp/_acf_import.php"

echo ""
echo "Done. Field groups in the WP admin now reflect the deployed JSON."
