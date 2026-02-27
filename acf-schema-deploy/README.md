# ACF Schema Deploy (API Pull/Push)

This skill manages ACF schema JSON through the WordPress plugin API:

- Pull from `POST /wp-json/acf-schema/v1/pull`
- Push to `POST /wp-json/acf-schema/v1/push` (signed)

Local schema remains canonical in `wp-content/acf-json/group_*.json`.
Skill entrypoint for Codex is this directory's `SKILL.md`.

## Commands

```bash
cd /Users/gordonlewis/wordpress-skill/acf-schema-deploy

# Pull latest schema from WordPress
scripts/pull.sh --schema-repo .

# Push dry-run (recommended first)
scripts/push.sh --schema-repo . --dry-run

# Push apply
scripts/push.sh --schema-repo .

# Intentionally changing field keys
scripts/push.sh --schema-repo . --allow-field-key-changes
```

`scripts/deploy-main.sh` is a backward-compatible alias to `scripts/push.sh`.

## Configure Target

Set root-level env (preferred):
```bash
cat > /Users/gordonlewis/wordpress-skill/.env <<'EOF'
TARGET_BASE_URL="https://api-gordon-acf-demo.roostergrintemplates.com"
WP_API_USER="your-user"
WP_API_APP_PASSWORD="your-app-password"
ACF_SCHEMA_API_HMAC_SECRET="your-hmac-secret"
EOF
```

Optional static config file:
```bash
cp config/target-main.sh.example config/target-main.sh
```

Set in `config/target-main.sh`:

- `TARGET_BASE_URL`
- `TARGET_API_USER`
- `TARGET_API_APP_PASSWORD`
- `TARGET_API_HMAC_SECRET` (or export `ACF_SCHEMA_API_HMAC_SECRET`)

## Validation Model

Validation is server-side in the plugin:

- JSON payload structure checks
- Duplicate sibling field name checks
- Field-key stability checks (unless `allow_field_key_changes=true`)
- Signed push verification (HMAC + nonce + timestamp)
- Optional schema hash lock (`expected_hash`)

## Notes

- This flow does not require SSH for day-to-day schema updates.
- WP-CLI is optional and only needed for server diagnostics or plugin operations.
