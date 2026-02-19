# WP-CLI Requirement (Plesk)

This skill requires WP-CLI on the Plesk server.
WP-CLI runs on the server and targets each domain via `--path=<wp_root>`.

## Install WP-CLI on server
If WP-CLI is missing:

```bash
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
php wp-cli.phar --info
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
```

Verify:

```bash
wp --info
wp --path='/var/www/vhosts/example.com/httpdocs' core version
```

## Why WP-CLI is required in this workflow
- Remote sanity check: `wp option get home`
- Locked path enforcement: compare `acf_get_setting("save_json")` with configured deploy path
- Post-deploy action: run `WPCLI_SYNC_COMMAND`

## Sync command configuration
Set `WPCLI_SYNC_COMMAND` in `config/target-main.sh`.

Example placeholder patterns:

```bash
WPCLI_SYNC_COMMAND="wp acf sync --all"
```

```bash
WPCLI_SYNC_COMMAND="wp eval 'do_action(\"acf_schema_sync\");'"
```

Use the command supported by your site.
If command behavior changes by plugin/version, keep it site-specific in config.
