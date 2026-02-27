# ACF WordPress — Path Configuration

Update these paths for your environment. All skill files reference these locations.

| Variable | Description | Default |
|----------|-------------|---------|
| `SCHEMA_REPO` | Local clone of the ACF schema deploy repo | `./acf-schema-deploy` |
| `ACF_JSON_DIR` | ACF field group JSON files | `$SCHEMA_REPO/wp-content/acf-json` |
| `CONTENT_API_REPO` | Local clone of the WP ACF content API repo | `./wp-acf-content-api` |

For shell scripts, paths are configured in:
- `/Users/gordonlewis/wordpress-skill/.env` — shared API base URL, credentials, and HMAC secret for all skills
- `/Users/gordonlewis/wordpress-skill/.env.example` — template for required/optional variables
