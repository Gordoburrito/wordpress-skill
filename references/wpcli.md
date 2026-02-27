# WP-CLI Role in API Flow

WP-CLI is not required for normal schema pull/push once the plugin API is installed.

## Required for day-to-day workflow

- `scripts/pull.sh`: No WP-CLI required.
- `scripts/push.sh`: No WP-CLI required.

## Optional WP-CLI use cases

- Plugin deployment/activation from shell
- Server diagnostics (`wp option get home`, plugin status checks)
- Emergency export/import outside the API flow

## Recommendation

Keep WP-CLI installed on Plesk for operational recovery, but treat it as an admin tool, not the schema transport path.
