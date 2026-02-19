#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check_scope.sh --schema-repo <abs-path>

Fail when local working-tree changes include files outside wp-content/acf-json/**.
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

if ! git -C "${SCHEMA_REPO}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "Schema repo must be a git repository: ${SCHEMA_REPO}"
fi

ALLOWED_PREFIX="wp-content/acf-json/"
disallowed=()
all_paths_tmp="$(mktemp)"
trap 'rm -f "${all_paths_tmp}"' EXIT

STATUS_OUTPUT="$(git -C "${SCHEMA_REPO}" status --porcelain --untracked-files=all)"
if [[ -n "${STATUS_OUTPUT}" ]]; then
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    path="${line:3}"
    if [[ "${path}" == *" -> "* ]]; then
      path="${path##* -> }"
    fi
    printf '%s\n' "${path}" >> "${all_paths_tmp}"
  done <<< "${STATUS_OUTPUT}"
fi

# When the working tree is clean (typical in CI), validate the last commit scope.
if [[ ! -s "${all_paths_tmp}" ]] && git -C "${SCHEMA_REPO}" rev-parse --verify HEAD^ >/dev/null 2>&1; then
  git -C "${SCHEMA_REPO}" diff --name-only --diff-filter=ACMR HEAD^..HEAD >> "${all_paths_tmp}"
fi

if [[ ! -s "${all_paths_tmp}" ]]; then
  echo "Scope check passed: no candidate changes found in working tree or previous commit."
  exit 0
fi

while IFS= read -r path; do
  [[ -n "${path}" ]] || continue
  if [[ "${path}" != "${ALLOWED_PREFIX}"* ]]; then
    disallowed+=("${path}")
  fi
done < <(sort -u "${all_paths_tmp}")

if [[ ${#disallowed[@]} -gt 0 ]]; then
  echo "Scope check failed. Files outside ${ALLOWED_PREFIX} were modified:" >&2
  for p in "${disallowed[@]}"; do
    echo "  - ${p}" >&2
  done
  exit 1
fi

echo "Scope check passed: all candidate changes are within ${ALLOWED_PREFIX}."
