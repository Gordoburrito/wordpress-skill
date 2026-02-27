# ACF WordPress — Path Configuration

Update these paths for your environment. All skill files reference these locations.

| Variable | Description | Default |
|----------|-------------|---------|
| `SCHEMA_REPO` | Local clone of the ACF schema deploy repo | `./acf-schema-deploy` |
| `ACF_JSON_DIR` | ACF field group JSON files | `$SCHEMA_REPO/wp-content/acf-json` |
| `CONTENT_API_REPO` | Local clone of the WP ACF content API repo | `./wp-acf-content-api` |

For shell scripts, paths are configured in:
- `/Users/gordonlewis/wordpress-skill/.env` — WordPress schema API base URL, API credentials, HMAC secret (preferred)
- `$SCHEMA_REPO/config/target-main.sh` — optional endpoint/config overrides
- `$CONTENT_API_REPO/config/target-api.sh` — WordPress REST API base URL, credentials (gitignored)
