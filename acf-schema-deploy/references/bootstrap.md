# Bootstrap (Plugin API Flow)

This runbook configures the schema repo for pull/push via the ACF Schema API plugin.

## 1) Install/enable plugin on WordPress

- Plugin file: `acf-schema-api.php`
- Endpoint namespace: `acf-schema/v1`
- Required routes:
  - `POST /wp-json/acf-schema/v1/pull`
  - `POST /wp-json/acf-schema/v1/push`

## 2) Configure server HMAC secret

Set a strong secret in WordPress (for signed push requests):

```php
define('ACF_SCHEMA_API_HMAC_SECRET', 'replace-with-64+-char-random-secret');
```

## 3) Create Application Password user

- Use a WordPress user with capability required by plugin (`manage_options` by default).
- Generate an Application Password for that user.

## 4) Configure local target

```bash
cat > /Users/gordonlewis/wordpress-skill/.env <<'EOF'
TARGET_BASE_URL="https://api-gordon-acf-demo.roostergrintemplates.com"
WP_API_USER="your-user"
WP_API_APP_PASSWORD="your-app-password"
ACF_SCHEMA_API_HMAC_SECRET="your-hmac-secret"
EOF
```

Optional: set endpoint overrides directly in `/Users/gordonlewis/wordpress-skill/.env`:
- `TARGET_API_PULL_PATH`
- `TARGET_API_PUSH_PATH`
- `TARGET_API_PUSH_ROUTE`

## 5) Pull baseline schema

```bash
scripts/pull.sh --schema-repo .
```

## 6) Smoke test push (dry-run)

```bash
scripts/push.sh --schema-repo . --dry-run
```

If dry-run succeeds, plugin auth, signature validation, and schema validation are wired correctly.
