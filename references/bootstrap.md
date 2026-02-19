# Bootstrap (One-Time Setup)

## Automated Setup

The `setup.sh` script handles all discovery and configuration automatically:

```bash
scripts/setup.sh \
  --host 52.24.217.50 \
  --user roostergrintemp \
  --port 22 \
  --key ~/.ssh/acf_schema_deploy \
  --domain api-gordon-acf-demo.roostergrintemplates.com
```

This will:
1. Test SSH connectivity
2. Find PHP on the Plesk server (checks `/opt/plesk/php/*/bin`)
3. Verify WP-CLI is installed
4. Scan for WordPress installations and match your domain
5. Verify the WP root with `wp option get home`
6. Detect the ACF `save_json` path via `wp eval-file`
7. Create the `acf-json` directory on the server if needed
8. Write `config/target-main.sh` with all discovered values

Use `--dry-run` to preview without writing.

## After Setup

### Pull the initial baseline
```bash
scripts/export-acf-json.sh --schema-repo .
```
This exports all ACF field groups from the database to JSON and pulls them locally.

### Commit the baseline
```bash
git add wp-content/acf-json && git commit -m "Initial ACF schema baseline"
```

### Wire CI push trigger (optional)
Use `references/github-actions-main.yml` as a starter workflow.
Copy it to `.github/workflows/deploy-acf-schema-main.yml`.

Required CI secrets:
- SSH private key for deploy user
- Known hosts entry for strict host verification

Do not store secrets in repo files.

## Manual Setup (if needed)

If `setup.sh` can't reach the server, you can configure manually:

### 1) SSH prerequisites
- The SSH user needs shell access (`/bin/bash`, not `/bin/false`)
- Your public key must be in `~/.ssh/authorized_keys` on the server
- On Plesk, the group is typically `psacln`, not the username

### 2) Find PHP
Plesk PHP is not in the default PATH for system users. Check:
```bash
ls /opt/plesk/php/*/bin/php
```

### 3) Discover WP root and ACF path
```bash
# Find WordPress installs
find /var/www/vhosts -maxdepth 6 -name wp-config.php

# Test WP root
export PATH=/opt/plesk/php/8.3/bin:$PATH
wp --path='/var/www/vhosts/.../site-dir' option get home

# Get ACF save_json (use eval-file to avoid quoting hell)
cat > /tmp/acf_check.php << 'EOF'
<?php
$s = acf_get_setting('save_json');
if (is_array($s)) $s = reset($s);
echo $s;
EOF
wp --path='/var/www/vhosts/.../site-dir' eval-file /tmp/acf_check.php
rm /tmp/acf_check.php
```

### 4) Edit config/target-main.sh
```bash
TARGET_SSH_HOST="52.24.217.50"
TARGET_SSH_USER="roostergrintemp"
TARGET_SSH_PORT="22"
TARGET_SSH_KEY="${HOME}/.ssh/acf_schema_deploy"
TARGET_REMOTE_PHP_DIR="/opt/plesk/php/8.3/bin"
TARGET_WP_ROOT="/var/www/vhosts/.../site-dir"
TARGET_REMOTE_ACF_JSON_PATH="/var/www/vhosts/.../wp-content/themes/dist/acf-json"
WPCLI_SYNC_COMMAND="wp option get home"
```

## Current Target: api-gordon-acf-demo

| Setting | Value |
|---------|-------|
| Host | `52.24.217.50` |
| SSH User | `roostergrintemp` |
| SSH Key | `~/.ssh/acf_schema_deploy` |
| PHP | `/opt/plesk/php/8.3/bin` |
| WP Root | `/var/www/vhosts/roostergrintemplates.com/api-gordon-acf-demo.roostergrintemplates.com` |
| ACF JSON | `.../wp-content/themes/dist/acf-json` |
| ACF Pro | v6.7.0.2 (no `wp acf` CLI — uses `wp eval-file`) |
| Theme | `dist` |
| Field Groups | 11 (Global Data, SEO, Page Sections, Button, Content, Image, Form-Inputs, Component-Options, Form Input Fields, Video, Blog Post) |
