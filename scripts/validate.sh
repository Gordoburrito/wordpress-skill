#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: validate.sh --schema-repo <abs-path> [--allow-field-key-changes]

Validation checks:
1. Scope check (local working tree limited to wp-content/acf-json/**)
2. JSON parse check
3. Duplicate field-name check
4. Field key stability check (unless explicitly allowed)
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

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

echo "Running JSON parse check..."
_acf_dir="${SCHEMA_REPO}/wp-content/acf-json"
[[ -d "${_acf_dir}" ]] || fail "Missing directory: ${_acf_dir}"

_json_files=()
while IFS= read -r -d '' f; do
  _json_files+=("$f")
done < <(find "${_acf_dir}" -name '*.json' -print0 | sort -z)

[[ ${#_json_files[@]} -gt 0 ]] || fail "No JSON files found under ${_acf_dir}"

_parse_errors=()
for f in "${_json_files[@]}"; do
  if ! jq empty < "$f" 2>/dev/null; then
    _parse_errors+=("$f")
  fi
done

if [[ ${#_parse_errors[@]} -gt 0 ]]; then
  echo "JSON parse check failed:" >&2
  for e in "${_parse_errors[@]}"; do
    echo "  - $e" >&2
  done
  exit 1
fi

echo "JSON parse check passed (${#_json_files[@]} file(s))."

echo "Running duplicate-name check..."
"${SCRIPT_DIR}/check_duplicates.sh" --schema-repo "${SCHEMA_REPO}"

echo "Running field-key check..."
if [[ "${ALLOW_FIELD_KEY_CHANGES}" -eq 1 ]]; then
  "${SCRIPT_DIR}/check_field_keys.sh" --schema-repo "${SCHEMA_REPO}" --allow-field-key-changes
else
  "${SCRIPT_DIR}/check_field_keys.sh" --schema-repo "${SCHEMA_REPO}"
fi

echo "Validation completed successfully."
