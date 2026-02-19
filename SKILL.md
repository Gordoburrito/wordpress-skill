---
name: acf-schema-deploy
description: Safely manage ACF schema-as-code for headless WordPress on a single Plesk-hosted main environment using local JSON edits, validation, diff review, and SSH/rsync deployment with required WP-CLI verification. Use when requests involve wp-content/acf-json updates, schema validation, or main-environment schema deployment.
---

# ACF Schema Deploy

## Purpose
Use this skill to edit and deploy ACF field-group JSON with strict scope control.
Treat schema as code: local Git repo is canonical, WordPress is runtime.

## Required Inputs
- Local schema repo absolute path
- Schema change request
- Confirmation that deployment to `main` should occur (deploy is push-triggered in CI)

## Hard Guardrails
- Edit only `wp-content/acf-json/**` inside the schema repo.
- Never edit frontend repositories.
- Never read secrets (`.env`, `wp-config.php`, SSH private keys).
- Never run arbitrary shell commands outside the declared scripts.
- Always run validation before deployment.
- Require WP-CLI on the remote Plesk server.

## Quick Start (Round-Trip)
```bash
cd /Users/gordonlewis/wordpress-skill/acf-schema-deploy

# Export from WP database → JSON → pull to local
scripts/export-acf-json.sh --schema-repo .

# Edit JSON files locally in wp-content/acf-json/

# Push JSON back to server
scripts/deploy-main.sh --schema-repo .

# Import JSON into WP database (admin UI reflects changes)
scripts/import-acf-json.sh
```

## First-Time Setup
```bash
scripts/setup.sh \
  --host 52.24.217.50 \
  --user roostergrintemp \
  --key ~/.ssh/acf_schema_deploy \
  --domain api-gordon-acf-demo.roostergrintemplates.com
```

## Scripts
| Script | Purpose |
|--------|---------|
| `scripts/setup.sh` | Auto-discover server config (PHP, WP root, ACF path), write `config/target-main.sh` |
| `scripts/export-acf-json.sh` | Export ACF field groups from WP database to JSON on server, then pull to local |
| `scripts/pull.sh` | Fetch JSON files from server to local `wp-content/acf-json/` |
| `scripts/deploy-main.sh` | Validate + rsync local JSON to server |
| `scripts/import-acf-json.sh` | Sync JSON files on server into WP database (makes admin UI reflect changes) |
| `scripts/wp-remote.sh` | Run any WP-CLI command on the remote server |
| `scripts/wpcli-sync.sh` | Run configured post-deploy WP-CLI command |
| `scripts/validate.sh` | Scope check, JSON parse, duplicate fields, key stability |
| `scripts/check_scope.sh` | Fail if changes are outside `wp-content/acf-json/**` |
| `scripts/check_duplicates.sh` | Fail on duplicate field names in sibling arrays |
| `scripts/check_field_keys.sh` | Fail on key changes unless explicitly allowed |
| `config/target-main.sh` | SSH, WP root, ACF path, PHP path config |

## Workflow Detail
1. Apply schema edits in `wp-content/acf-json/**`.
2. Run validation: `scripts/validate.sh --schema-repo .`
3. Present a concise diff summary of changed JSON files.
4. Deploy: `scripts/deploy-main.sh --schema-repo .`
5. Import into DB: `scripts/import-acf-json.sh`

All scripts support `--dry-run`. All scripts support `--help`.

## Deployment Model
- One target only: `main`.
- Trigger: push to `main` branch in the schema repo.
- CI order:
1. Checkout schema repo
2. `scripts/validate.sh --schema-repo <repo>`
3. `scripts/deploy-main.sh --schema-repo <repo>`
4. `scripts/wpcli-sync.sh`

## References
- `references/bootstrap.md`: one-time setup and bootstrap from Plesk.
- `references/wpcli.md`: WP-CLI requirement and server setup guidance.
- `references/github-actions-main.yml`: push-to-main CI workflow template.

## Expected Response Pattern
1. State changed files under `wp-content/acf-json/**`.
2. State validation result.
3. Provide concise diff summary.
4. If requested, provide exact deploy command invocation and expected CI behavior.
