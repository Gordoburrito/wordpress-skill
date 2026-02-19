#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check_duplicates.sh --schema-repo <abs-path>

Fail when duplicate sibling field names exist in ACF JSON files.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

SCHEMA_REPO=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --schema-repo)
      [[ $# -ge 2 ]] || fail "Missing value for --schema-repo"
      SCHEMA_REPO="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "${SCHEMA_REPO}" ]] || fail "--schema-repo is required"
[[ -d "${SCHEMA_REPO}" ]] || fail "Schema repo not found: ${SCHEMA_REPO}"

node - "${SCHEMA_REPO}" <<'JS'
const fs = require("fs");
const path = require("path");

const repo = process.argv[2];
const acfDir = path.join(repo, "wp-content", "acf-json");

if (!fs.existsSync(acfDir) || !fs.statSync(acfDir).isDirectory()) {
  process.stderr.write(`ERROR: Missing directory: ${acfDir}\n`);
  process.exit(1);
}

const files = fs.readdirSync(acfDir).filter(f => f.endsWith(".json")).sort().map(f => path.join(acfDir, f));
if (files.length === 0) {
  process.stderr.write(`ERROR: No JSON files found under ${acfDir}\n`);
  process.exit(1);
}

const issues = [];

function checkFields(fields, context) {
  if (!Array.isArray(fields)) return;
  const seen = {};
  for (const field of fields) {
    if (typeof field !== "object" || field === null) continue;
    const name = field.name;
    if (typeof name === "string" && name) {
      if (seen[name]) issues.push(`${context}: duplicate field name '${name}'`);
      else seen[name] = true;
    }
    let childContext = context;
    if (typeof name === "string" && name) childContext = `${context}/${name}`;
    else if (typeof field.key === "string") childContext = `${context}/${field.key}`;

    checkFields(field.sub_fields, childContext);

    const layouts = field.layouts;
    if (Array.isArray(layouts)) {
      for (const layout of layouts) {
        if (typeof layout !== "object" || layout === null) continue;
        const layoutName = layout.name || layout.key || "layout";
        checkFields(layout.sub_fields, `${childContext}/layout:${layoutName}`);
      }
    }
    // Handle layouts as object (ACF sometimes uses object keyed by layout key)
    if (layouts && typeof layouts === "object" && !Array.isArray(layouts)) {
      for (const [lk, layout] of Object.entries(layouts)) {
        if (typeof layout !== "object" || layout === null) continue;
        const layoutName = layout.name || layout.key || lk;
        checkFields(layout.sub_fields, `${childContext}/layout:${layoutName}`);
      }
    }
  }
}

for (const filePath of files) {
  let payload;
  try {
    payload = JSON.parse(fs.readFileSync(filePath, "utf-8"));
  } catch (exc) {
    process.stderr.write(`ERROR: Failed to parse JSON: ${filePath} (${exc.message})\n`);
    process.exit(1);
  }
  const groups = Array.isArray(payload) ? payload : [payload];
  for (let i = 0; i < groups.length; i++) {
    const group = groups[i];
    if (typeof group !== "object" || group === null) continue;
    const groupLabel = group.title || group.key || `group[${i}]`;
    checkFields(group.fields, `${path.basename(filePath)}:${groupLabel}`);
  }
}

if (issues.length > 0) {
  process.stderr.write("Duplicate field names detected:\n");
  for (const issue of issues) process.stderr.write(`  - ${issue}\n`);
  process.exit(1);
}

console.log("Duplicate-name check passed.");
JS
