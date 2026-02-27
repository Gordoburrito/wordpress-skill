# ACF WordPress Skills

Claude Code skills for managing Advanced Custom Fields on a headless WordPress site. Three skills cover the full lifecycle: **schema editing**, **deployment**, and **content management**.

## Project Structure

```
.
├── .env.example               # Shared env template for all skills
├── CLAUDE.md                  # Claude Code instructions (auto-loaded)
├── skills/                    # Skill definitions
│   ├── workflow.md            # End-to-end workflow (design → live page)
│   ├── acf-schema-edit.md     # Create/modify ACF field group JSON
│   ├── acf-schema-deploy.md   # Pull/push schema JSON via WordPress plugin API
│   ├── wp-acf-content-api.md  # Read/write field values via REST API
│   └── config.md              # Path configuration reference
├── acf-schema-edit/           # Skill package: schema editing
│   ├── SKILL.md               # Skill entrypoint
│   └── references/            # Schema editing references
├── acf-schema-deploy/         # Deployment scripts & server config
│   ├── SKILL.md               # Skill entrypoint
│   ├── scripts/               # pull, push (API flow)
│   └── wp-content/acf-json/   # ACF field group JSON files (11 groups)
└── wp-acf-content-api/        # Skill package: content API
    ├── SKILL.md               # Skill entrypoint
    ├── scripts/               # build-allowlist, pull-content, push-content
    └── runtime/               # Generated allowlists & pulled content
```

## Install in Codex

Install these skills into your global Codex skills directory (`$CODEX_HOME/skills`)
using the built-in `skill-installer` script.

### Install all skills

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo Gordoburrito/wordpress-skill \
  --ref main \
  --path acf-schema-edit acf-schema-deploy wp-acf-content-api \
  --method git
```

### Install one skill

```bash
# Replace <skill-path> with one of:
# acf-schema-edit | acf-schema-deploy | wp-acf-content-api
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo Gordoburrito/wordpress-skill \
  --ref main \
  --path <skill-path> \
  --method git
```

Restart Codex to pick up new skills.

## Quick Start

### 1. Configure credentials

All skill scripts load credentials from the workspace root `.env`.

```bash
cp .env.example .env
# Edit with your WordPress URL, username, Application Password, and HMAC secret
```

Minimum required values:

```bash
cat > .env <<'EOF'
TARGET_BASE_URL="https://api-gordon-acf-demo.roostergrintemplates.com"
WP_API_USER="your-user"
WP_API_APP_PASSWORD="your-app-password"
ACF_SCHEMA_API_HMAC_SECRET="your-hmac-secret"
EOF
```

### 2. Build the field allowlist

```bash
cd wp-acf-content-api
scripts/build-allowlist.sh --schema-repo /path/to/acf-schema-deploy
```

### 3. Pull current page content

```bash
scripts/pull-content.sh --resource-type pages --id 8
```

### 4. Push a content update

```bash
# Always dry-run first
scripts/push-content.sh --resource-type pages --id 8 --payload payload.json --dry-run

# Then push for real
scripts/push-content.sh --resource-type pages --id 8 --payload payload.json
```

## Skills Reference

### Schema Editing (`skills/acf-schema-edit.md`)

Edit ACF field group JSON files locally. Handles new fields, new layouts, new reusable components, and modifications to existing structures.

| Task | What to do |
|------|-----------|
| Add a field to an existing layout | Edit the layout's `sub_fields` in the Page Sections JSON |
| Create a new page section layout | Add a layout entry, clone Tier 1 components |
| Create a new reusable component | New `group_*.json` file prefixed with `_` |
| Modify field options | Edit the field's properties, keep `key` and `name` unchanged |

### Schema Deployment (`skills/acf-schema-deploy.md`)

Pull and push schema JSON through the WordPress ACF Schema API plugin.

| Command | Script |
|---------|--------|
| Pull schema | `scripts/pull.sh --schema-repo .` |
| Push schema dry-run | `scripts/push.sh --schema-repo . --dry-run` |
| Push schema apply | `scripts/push.sh --schema-repo .` |
| Push with intentional key changes | `scripts/push.sh --schema-repo . --allow-field-key-changes` |
| Backward-compatible alias | `scripts/deploy-main.sh --schema-repo .` |

### Content Management (`skills/wp-acf-content-api.md`)

Read and write ACF field values via the WordPress REST API. Uses Application Passwords for authentication.

| Command | Script |
|---------|--------|
| Build field allowlist | `scripts/build-allowlist.sh --schema-repo <path>` |
| Pull page/post content | `scripts/pull-content.sh --resource-type pages --id <id>` |
| Push content update | `scripts/push-content.sh --resource-type pages --id <id> --payload <file>` |
| Run test suite (read-only) | `scripts/run-tests.sh --schema-repo <path> --id <id>` |
| Run test suite (with writes) | `scripts/run-tests.sh --schema-repo <path> --id <id> --live` |

## Common Workflows

### Update text on an existing page

Content API only — no schema changes needed.

```bash
cd wp-acf-content-api
scripts/pull-content.sh --resource-type pages --id 8    # See current values
# Create payload.json with your changes
scripts/push-content.sh --resource-type pages --id 8 --payload payload.json --dry-run
scripts/push-content.sh --resource-type pages --id 8 --payload payload.json
```

### Add a new section type and populate it

Full skill chain: edit → deploy → content.

```bash
# 1. Edit schema JSON
#    (modify acf-schema-deploy/wp-content/acf-json/group_62211673cd81a.json)

# 2. Pull + push schema
cd acf-schema-deploy
scripts/pull.sh --schema-repo .
scripts/push.sh --schema-repo . --dry-run
scripts/push.sh --schema-repo .

# 3. Rebuild allowlist and push content
cd ../wp-acf-content-api
scripts/build-allowlist.sh --schema-repo /path/to/acf-schema-deploy
scripts/push-content.sh --resource-type pages --id 8 --payload payload.json
```

### Build a page from a design

Read `skills/workflow.md` for the full process. In short:

1. Map visual sections to existing ACF layouts (20+ available)
2. Edit schema only if new layouts or fields are needed
3. Deploy schema changes
4. Populate content via REST API
5. Pull content again to verify

## Key Concepts

- **Field names vs field keys**: The REST API uses human-readable names (`seo`, `sections`), not internal keys (`field_abc123`).
- **Three-tier architecture**: Tier 1 = reusable components (`_Content`, `_Image`, etc.), Tier 2 = page builders with flexible content, Tier 3 = global/meta settings.
- **Flexible content**: The entire `sections` array must be sent on every update — no partial updates. Every object needs `acf_fc_layout`.
- **Application Passwords**: Required for REST API writes. Regular WordPress passwords won't work.
- **GET/POST mismatch**: ACF returns `false` for empty fields, but rejects it on POST. Fix before pushing: `false` → `""` for select fields, `false` → `[]` for arrays.

## Prerequisites

- **jq** — used by schema/content JSON tooling
- **curl** — used by content API scripts
- **Schema API plugin + credentials** — required for schema pull/push
- **WordPress Application Password** — required for content writes

## Testing

```bash
# Read-only tests (safe, no writes)
cd wp-acf-content-api
scripts/run-tests.sh --schema-repo /path/to/acf-schema-deploy --id 8

# Full test suite with write + automatic rollback
scripts/run-tests.sh --schema-repo /path/to/acf-schema-deploy --id 8 --live
```

All deploy and content scripts support `--dry-run` and `--help`.
