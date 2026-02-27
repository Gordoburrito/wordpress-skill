---
name: acf-schema-deploy
description: Safely manage ACF schema-as-code for headless WordPress through a pull/push API workflow. Use when requests involve wp-content/acf-json updates, schema pull, or schema push to the single main WordPress backend.
---

# ACF Schema Deploy

## Purpose
Use this skill for a strict two-command schema workflow:
1. Pull schema from WordPress plugin API to local JSON.
2. Push local JSON back through the plugin API.

Schema remains canonical in local Git under `wp-content/acf-json/**`.
Validation, duplicate checks, and field-key stability checks are enforced server-side by the plugin.

## Required Inputs
- Local schema repo absolute path.
- Schema change request.
- Target is always single `main` backend.

## Hard Guardrails
- Edit only `wp-content/acf-json/**` inside the schema repo.
- Never edit frontend repositories.
- Never read secrets (`.env`, `wp-config.php`, SSH private keys).
- Never run arbitrary shell commands outside declared scripts.
- Use only `pull.sh` and `push.sh` for schema transport.
- Push uses signed requests (HMAC) and optimistic lock (`expected_hash`).

## Quick Start
```bash
cd /Users/gordonlewis/wordpress-skill/acf-schema-deploy

# 1) Pull latest schema from WordPress
scripts/pull.sh --schema-repo .

# 2) Edit local JSON files in wp-content/acf-json/

# 3) Push schema back (dry-run first, then apply)
scripts/push.sh --schema-repo . --dry-run
scripts/push.sh --schema-repo .

# If intentionally adding/removing/changing field keys:
scripts/push.sh --schema-repo . --allow-field-key-changes
```

## Configuration
Copy and edit:
```bash
cp config/target-main.sh.example config/target-main.sh
```

Required config values in `config/target-main.sh`:
- `TARGET_BASE_URL`
- `TARGET_API_USER`
- `TARGET_API_APP_PASSWORD`
- `TARGET_API_HMAC_SECRET` (or env `ACF_SCHEMA_API_HMAC_SECRET`)

## Scripts
| Script | Purpose |
|--------|---------|
| `scripts/pull.sh` | Pull schema from `/wp-json/acf-schema/v1/pull` and write local `group_*.json` files |
| `scripts/push.sh` | Push local schema to `/wp-json/acf-schema/v1/push` (signed) |
| `scripts/deploy-main.sh` | Backward-compatible alias to `scripts/push.sh` |

Legacy SSH/WP-CLI scripts remain in the repo for reference but are not part of this v1 API flow.

## Workflow Detail
1. Pull latest schema: `scripts/pull.sh --schema-repo .`
2. Apply local edits under `wp-content/acf-json/**`.
3. Review diff in Git.
4. Run push dry-run: `scripts/push.sh --schema-repo . --dry-run`
5. Apply push: `scripts/push.sh --schema-repo .`

## References
- `references/bootstrap.md`: plugin/API bootstrap and config.
- `references/wpcli.md`: WP-CLI is optional and only for server diagnostics/plugin ops.
- `references/github-actions-main.yml`: push-to-main CI workflow template.

## Expected Response Pattern
1. State changed files under `wp-content/acf-json/**`.
2. State pull/push result (dry-run vs apply).
3. Provide concise diff summary.
4. If requested, provide exact command invocations.
