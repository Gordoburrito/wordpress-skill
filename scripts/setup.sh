#!/usr/bin/env bash
set -euo pipefail

# Automated discovery and bootstrap for a new ACF Schema Deploy target.
# Walks through SSH connection, WP-CLI discovery, and writes target-main.sh.

usage() {
  cat <<'EOF'
Usage: setup.sh [options]

Options:
  --host <ip-or-hostname>    SSH host (required)
  --user <ssh-user>          SSH user (required)
  --port <port>              SSH port (default: 22)
  --key  <path>              SSH private key path (optional)
  --domain <domain>          Domain to match (e.g. api-gordon-acf-demo.roostergrintemplates.com)
  --dry-run                  Show what would be written without writing
  -h, --help                 Show this help
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
SKILL_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${SKILL_ROOT}/config/target-main.sh"

HOST=""
USER=""
PORT="22"
KEY=""
DOMAIN=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)  HOST="$2"; shift 2 ;;
    --user)  USER="$2"; shift 2 ;;
    --port)  PORT="$2"; shift 2 ;;
    --key)   KEY="$2";  shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

[[ -n "${HOST}" ]] || fail "--host is required"
[[ -n "${USER}" ]] || fail "--user is required"

SSH_OPTS=(-p "${PORT}" -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)
if [[ -n "${KEY}" ]]; then
  [[ -f "${KEY}" ]] || fail "SSH key not found: ${KEY}"
  SSH_OPTS+=(-i "${KEY}")
fi
SSH_TARGET="${USER}@${HOST}"

run_remote() {
  ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" "$@"
}

# ── Step 1: Test SSH ──────────────────────────────────────────────
info "Testing SSH connection to ${SSH_TARGET}:${PORT}..."
if ! run_remote "echo ok" >/dev/null 2>&1; then
  fail "Cannot SSH into ${SSH_TARGET}. Check host, user, key, and that the shell is not /bin/false."
fi
echo "  SSH connection: OK"

# ── Step 2: Find PHP ─────────────────────────────────────────────
info "Detecting PHP on remote..."
PHP_DIR=""
for candidate in /opt/plesk/php/8.3/bin /opt/plesk/php/8.2/bin /opt/plesk/php/8.1/bin /opt/plesk/php/8.0/bin /usr/bin; do
  if run_remote "test -x ${candidate}/php" 2>/dev/null; then
    PHP_DIR="${candidate}"
    php_ver="$(run_remote "${candidate}/php -r 'echo PHP_VERSION;'" 2>/dev/null)"
    echo "  Found PHP ${php_ver} at ${candidate}"
    break
  fi
done
[[ -n "${PHP_DIR}" ]] || fail "No PHP binary found on remote server."

# ── Step 3: Check WP-CLI ─────────────────────────────────────────
info "Checking WP-CLI..."
if ! run_remote "export PATH=${PHP_DIR}:\$PATH && command -v wp >/dev/null 2>&1"; then
  fail "WP-CLI not found on remote. See references/wpcli.md for install instructions."
fi
echo "  WP-CLI: OK"

# ── Step 4: Find WordPress roots ─────────────────────────────────
info "Scanning for WordPress installations..."
wp_configs="$(run_remote "find /var/www/vhosts -maxdepth 6 -name wp-config.php 2>/dev/null" || true)"
if [[ -z "${wp_configs}" ]]; then
  fail "No wp-config.php found under /var/www/vhosts."
fi

# Filter by domain if provided.
WP_ROOT=""
if [[ -n "${DOMAIN}" ]]; then
  matched="$(echo "${wp_configs}" | grep "${DOMAIN}" | head -1 || true)"
  if [[ -n "${matched}" ]]; then
    WP_ROOT="$(dirname "${matched}")"
    echo "  Matched domain: ${WP_ROOT}"
  else
    echo "  Available WordPress sites:"
    echo "${wp_configs}" | while read -r line; do echo "    $(dirname "${line}")"; done
    fail "No wp-config.php matched domain '${DOMAIN}'."
  fi
else
  echo "  Found $(echo "${wp_configs}" | wc -l | tr -d ' ') WordPress installations."
  echo "  Provide --domain to auto-select, or choose from:"
  echo "${wp_configs}" | while read -r line; do echo "    $(dirname "${line}")"; done
  fail "Use --domain <subdomain> to select a site."
fi

# ── Step 5: Verify WP root with wp option get home ───────────────
info "Verifying WordPress root..."
wp_home="$(run_remote "export PATH=${PHP_DIR}:\$PATH && wp --path='${WP_ROOT}' option get home" 2>/dev/null | tr -d '\r')"
if [[ -z "${wp_home}" ]]; then
  fail "wp option get home returned empty for ${WP_ROOT}."
fi
echo "  Home URL: ${wp_home}"

# ── Step 6: Get ACF save_json path ───────────────────────────────
info "Detecting ACF save_json path..."
run_remote "cat > /tmp/_acf_setup_check.php << 'ACFEOF'
<?php
if (!function_exists('acf_get_setting')) { echo 'ACF_MISSING'; exit(0); }
\$s = acf_get_setting('save_json');
if (is_array(\$s)) { \$s = reset(\$s); }
echo \$s;
ACFEOF"
acf_path="$(run_remote "export PATH=${PHP_DIR}:\$PATH && wp --path='${WP_ROOT}' eval-file /tmp/_acf_setup_check.php" 2>/dev/null | tr -d '\r')"
run_remote "rm -f /tmp/_acf_setup_check.php"

if [[ "${acf_path}" == "ACF_MISSING" ]] || [[ -z "${acf_path}" ]]; then
  # Fall back to theme-based default.
  theme_name="$(run_remote "export PATH=${PHP_DIR}:\$PATH && wp --path='${WP_ROOT}' theme list --status=active --field=name" 2>/dev/null | tr -d '\r')"
  acf_path="${WP_ROOT}/wp-content/themes/${theme_name}/acf-json"
  echo "  ACF not active or save_json not set. Using theme default: ${acf_path}"
else
  echo "  ACF save_json: ${acf_path}"
fi

# ── Step 7: Ensure acf-json directory exists on remote ────────────
if ! run_remote "test -d '${acf_path}'" 2>/dev/null; then
  info "Creating acf-json directory on remote..."
  run_remote "mkdir -p '${acf_path}'"
  echo "  Created: ${acf_path}"
else
  echo "  Directory exists: ${acf_path}"
fi

# ── Step 8: Write config ─────────────────────────────────────────
info "Discovery complete. Results:"
echo ""
echo "  TARGET_SSH_HOST=\"${HOST}\""
echo "  TARGET_SSH_USER=\"${USER}\""
echo "  TARGET_SSH_PORT=\"${PORT}\""
[[ -n "${KEY}" ]] && echo "  TARGET_SSH_KEY=\"${KEY}\""
echo "  TARGET_REMOTE_PHP_DIR=\"${PHP_DIR}\""
echo "  TARGET_WP_ROOT=\"${WP_ROOT}\""
echo "  TARGET_REMOTE_ACF_JSON_PATH=\"${acf_path}\""
echo "  WPCLI_SYNC_COMMAND=\"wp option get home\""
echo ""

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[dry-run] Would write to: ${CONFIG_FILE}"
  exit 0
fi

cat > "${CONFIG_FILE}" << CFGEOF
#!/usr/bin/env bash

# Single main WordPress target (Plesk over SSH).
# Auto-generated by setup.sh on $(date -u +"%Y-%m-%dT%H:%M:%SZ").

TARGET_SSH_HOST="${HOST}"
TARGET_SSH_USER="${USER}"
TARGET_SSH_PORT="${PORT}"

# SSH private key path (leave empty to use default agent/key).
TARGET_SSH_KEY="\${HOME}/.ssh/acf_schema_deploy"

# Plesk PHP path for remote WP-CLI calls.
TARGET_REMOTE_PHP_DIR="${PHP_DIR}"

# Absolute WordPress root for the target install.
TARGET_WP_ROOT="${WP_ROOT}"

# Locked remote path that stores ACF JSON.
TARGET_REMOTE_ACF_JSON_PATH="${acf_path}"

# Site-specific post-deploy WP-CLI command.
# Safe smoke-test command; switch to "wp acf sync --all" once confirmed.
WPCLI_SYNC_COMMAND="wp option get home"
CFGEOF

echo "Config written to: ${CONFIG_FILE}"
echo ""
echo "Next steps:"
echo "  1. Pull current ACF JSON:  scripts/pull.sh --schema-repo ."
echo "  2. Commit the baseline:    git add wp-content/acf-json && git commit"
echo "  3. Deploy changes:         scripts/deploy-main.sh --schema-repo ."
echo "  4. Post-deploy verify:     scripts/wpcli-sync.sh"
