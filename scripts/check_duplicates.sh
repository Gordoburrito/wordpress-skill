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

_acf_dir="${SCHEMA_REPO}/wp-content/acf-json"
[[ -d "${_acf_dir}" ]] || fail "Missing directory: ${_acf_dir}"

_json_files=()
while IFS= read -r -d '' f; do
  _json_files+=("$f")
done < <(find "${_acf_dir}" -maxdepth 1 -name '*.json' -print0 | sort -z)

[[ ${#_json_files[@]} -gt 0 ]] || fail "No JSON files found under ${_acf_dir}"

# jq filter that recursively checks for duplicate sibling field names.
# Outputs one line per duplicate: "context: duplicate field name 'name'"
# Exit code 0 regardless; we check output length afterward.
read -r -d '' JQ_FILTER <<'JQEOF' || true
# Recursive function: check an array of fields for duplicate sibling names.
# $context is the path string for error messages.
def check_fields(context):
  if type != "array" then empty
  else
    . as $arr |
    # Collect names, find duplicates
    ([ $arr[] | select(type == "object") | .name // empty | select(type == "string" and length > 0) ]
      | group_by(.) | map(select(length > 1) | .[0])) as $dups |
    ($dups[] as $dup | "\(context): duplicate field name '\($dup)'"),
    # Recurse into each field's sub_fields and layouts
    ( $arr[] | select(type == "object") |
      ( (.name // .key // "field") as $child_name |
        "\(context)/\($child_name)" as $child_ctx |

        # sub_fields
        (if .sub_fields then .sub_fields | check_fields($child_ctx) else empty end),

        # layouts as array
        (if (.layouts | type) == "array" then
          .layouts[] | select(type == "object") |
          (.name // .key // "layout") as $layout_name |
          (if .sub_fields then .sub_fields | check_fields("\($child_ctx)/layout:\($layout_name)") else empty end)
        else empty end),

        # layouts as object (ACF sometimes uses object keyed by layout key)
        (if .layouts and ((.layouts | type) == "object") and ((.layouts | type) != "array") then
          .layouts | to_entries[] | .value | select(type == "object") |
          (.name // .key // "layout") as $layout_name |
          (if .sub_fields then .sub_fields | check_fields("\($child_ctx)/layout:\($layout_name)") else empty end)
        else empty end)
      )
    )
  end;

# Main: handle top-level as array or single object
input_filename as $fname |
(if type == "array" then . else [.] end) |
to_entries[] |
.value | select(type == "object") |
(.title // .key // "group") as $group_label |
"\($fname):\($group_label)" as $group_ctx |
(if .fields then .fields | check_fields($group_ctx) else empty end)
JQEOF

_issues=""
for _file in "${_json_files[@]}"; do
  _result=$(jq --raw-output "${JQ_FILTER}" "${_file}" 2>&1) || {
    fail "Failed to process: ${_file}"
  }
  if [[ -n "${_result}" ]]; then
    _issues="${_issues}${_result}"$'\n'
  fi
done

if [[ -n "${_issues}" ]]; then
  echo "Duplicate field names detected:" >&2
  while IFS= read -r _line; do
    [[ -n "${_line}" ]] && echo "  - ${_line}" >&2
  done <<< "${_issues}"
  exit 1
fi

echo "Duplicate-name check passed."
