# ACF Schema Deploy

Safely manage ACF schema-as-code for a single main WordPress backend using a plugin API pull/push flow.

**Use when:** requests involve pulling schema to local JSON or pushing updated schema JSON to WordPress.

**Paths:** see `/Users/gordonlewis/wordpress-skill/skills/config.md`. Scripts live in `$SCHEMA_REPO/scripts/`.

## Required Inputs
- Schema change to deploy, or request to pull latest schema.
- Confirmation this is for the single `main` backend.

## Hard Guardrails
- Edit only `wp-content/acf-json/**` inside the schema repo.
- Never edit frontend repositories.
- Never print or expose secrets (`.env`, `wp-config.php`, private keys).
- Never run arbitrary shell outside declared scripts.
- Use only `pull.sh` and `push.sh` for schema transport.
- Signed push is required.

## Quick Start
```bash
cd $SCHEMA_REPO

# Pull from WordPress
scripts/pull.sh --schema-repo .

# Edit JSON files locally (see skills/acf-schema-edit.md)

# Push dry-run then apply
scripts/push.sh --schema-repo . --dry-run
scripts/push.sh --schema-repo .

# For intentional field-key set changes
scripts/push.sh --schema-repo . --allow-field-key-changes
```

## Scripts
| Script | Purpose |
|--------|---------|
| `scripts/pull.sh` | Pull schema from WordPress API into local `wp-content/acf-json/` |
| `scripts/push.sh` | Push local `group_*.json` to WordPress API (signed) |
| `scripts/deploy-main.sh` | Backward-compatible alias to `push.sh` |

Validation now runs in the plugin API:
- payload structure checks
- duplicate sibling field-name checks
- field-key stability checks (unless explicitly allowed)
- HMAC signature + nonce + timestamp checks

## Workflow Detail
1. Pull: `scripts/pull.sh --schema-repo .`
2. Edit JSON locally.
3. Review diff.
4. Push dry-run: `scripts/push.sh --schema-repo . --dry-run`
5. Push apply: `scripts/push.sh --schema-repo .`

## References
- `/Users/gordonlewis/wordpress-skill/acf-schema-deploy/references/bootstrap.md`
- `/Users/gordonlewis/wordpress-skill/acf-schema-deploy/references/github-actions-main.yml`
