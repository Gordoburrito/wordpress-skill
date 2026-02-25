#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check_field_keys.sh --schema-repo <abs-path> [--allow-field-key-changes]

Fail when existing ACF field keys are changed compared to HEAD.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

SCHEMA_REPO=""
ALLOW_FIELD_KEY_CHANGES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --schema-repo)
      [[ $# -ge 2 ]] || fail "Missing value for --schema-repo"
      SCHEMA_REPO="$2"
      shift 2
      ;;
    --allow-field-key-changes)
      ALLOW_FIELD_KEY_CHANGES=1
      shift
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

if [[ "${ALLOW_FIELD_KEY_CHANGES}" -eq 1 ]]; then
  echo "Field-key check skipped (--allow-field-key-changes provided)."
  exit 0
fi

if ! command -v node >/dev/null 2>&1; then
  echo "WARNING: 'node' not found — skipping field-key stability check." >&2
  echo "Install Node.js to enable this check, or use --allow-field-key-changes to silence." >&2
  exit 0
fi

if ! git -C "${SCHEMA_REPO}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "Schema repo must be a git repository: ${SCHEMA_REPO}"
fi

compare_key_sets() {
  local old_file="$1"
  local new_file="$2"
  local rel_path="$3"

  node - "${old_file}" "${new_file}" "${rel_path}" <<'JS'
const fs = require("fs");
const oldFile = process.argv[2];
const newFile = process.argv[3];
const relPath = process.argv[4];

function collectKeys(node, out) {
  if (Array.isArray(node)) {
    for (const item of node) collectKeys(item, out);
  } else if (node && typeof node === "object") {
    for (const [k, v] of Object.entries(node)) {
      if (k === "key" && typeof v === "string") out.add(v);
      collectKeys(v, out);
    }
  }
}

let oldJson, newJson;
try {
  oldJson = JSON.parse(fs.readFileSync(oldFile, "utf-8"));
  newJson = JSON.parse(fs.readFileSync(newFile, "utf-8"));
} catch (exc) {
  process.stderr.write(`ERROR: Unable to parse JSON while checking keys in ${relPath}: ${exc.message}\n`);
  process.exit(1);
}

const oldKeys = new Set();
const newKeys = new Set();
collectKeys(oldJson, oldKeys);
collectKeys(newJson, newKeys);

const removed = [...oldKeys].filter(k => !newKeys.has(k)).sort();
const added = [...newKeys].filter(k => !oldKeys.has(k)).sort();

if (removed.length > 0 || added.length > 0) {
  process.stderr.write(`Field key changes detected in ${relPath}\n`);
  if (removed.length > 0) {
    const preview = removed.slice(0, 10).join(", ");
    const suffix = removed.length > 10 ? " ..." : "";
    process.stderr.write(`  Removed: ${preview}${suffix}\n`);
  }
  if (added.length > 0) {
    const preview = added.slice(0, 10).join(", ");
    const suffix = added.length > 10 ? " ..." : "";
    process.stderr.write(`  Added: ${preview}${suffix}\n`);
  }
  process.exit(2);
}
JS
}

WORKTREE_OUTPUT="$(
  {
    git -C "${SCHEMA_REPO}" diff --name-only --diff-filter=ACMR HEAD -- "wp-content/acf-json"
    git -C "${SCHEMA_REPO}" ls-files --others --exclude-standard -- "wp-content/acf-json"
  } | sort -u | grep '\.json$' || true
)"

violations=0
files_checked=0

if [[ -n "${WORKTREE_OUTPUT}" ]]; then
  while IFS= read -r rel_path; do
    [[ -n "${rel_path}" ]] || continue
    full_path="${SCHEMA_REPO}/${rel_path}"
    if [[ ! -f "${full_path}" ]]; then
      continue
    fi

    if ! git -C "${SCHEMA_REPO}" cat-file -e "HEAD:${rel_path}" >/dev/null 2>&1; then
      echo "Field-key check: skipping new file ${rel_path}"
      continue
    fi

    files_checked=1
    tmp_old="$(mktemp)"
    git -C "${SCHEMA_REPO}" show "HEAD:${rel_path}" > "${tmp_old}"
    if ! compare_key_sets "${tmp_old}" "${full_path}" "${rel_path}"; then
      violations=1
    fi
    rm -f "${tmp_old}"
  done <<< "${WORKTREE_OUTPUT}"
elif git -C "${SCHEMA_REPO}" rev-parse --verify HEAD^ >/dev/null 2>&1; then
  COMMIT_OUTPUT="$(
    git -C "${SCHEMA_REPO}" diff --name-only --diff-filter=ACMR HEAD^..HEAD -- "wp-content/acf-json" | grep '\.json$' || true
  )"

  while IFS= read -r rel_path; do
    [[ -n "${rel_path}" ]] || continue

    if ! git -C "${SCHEMA_REPO}" cat-file -e "HEAD^:${rel_path}" >/dev/null 2>&1; then
      echo "Field-key check: skipping new file ${rel_path}"
      continue
    fi
    if ! git -C "${SCHEMA_REPO}" cat-file -e "HEAD:${rel_path}" >/dev/null 2>&1; then
      continue
    fi

    files_checked=1
    tmp_old="$(mktemp)"
    tmp_new="$(mktemp)"
    git -C "${SCHEMA_REPO}" show "HEAD^:${rel_path}" > "${tmp_old}"
    git -C "${SCHEMA_REPO}" show "HEAD:${rel_path}" > "${tmp_new}"
    if ! compare_key_sets "${tmp_old}" "${tmp_new}" "${rel_path}"; then
      violations=1
    fi
    rm -f "${tmp_old}" "${tmp_new}"
  done <<< "${COMMIT_OUTPUT}"
fi

if [[ "${files_checked}" -eq 0 ]]; then
  echo "Field-key check passed: no changed baseline JSON files detected."
  exit 0
fi

if [[ "${violations}" -ne 0 ]]; then
  fail "Field-key check failed."
fi

echo "Field-key check passed."
