#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

link_one() {
  local name="$1"
  local source_path="${SCRIPT_DIR}/${name}"
  local target_path="${TOOLS_DIR}/${name}"

  [[ -f "${source_path}" ]] || fail "missing source file: ${source_path}"

  if [[ -e "${target_path}" || -L "${target_path}" ]]; then
    printf 'exists, skip: %s\n' "${target_path}"
    return
  fi

  ln -s "${source_path}" "${target_path}"
  printf 'linked: %s -> %s\n' "${target_path}" "${source_path}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${HOME}/tools"
TOOLS=(git-auto-merge gt git-merge git-mr git-compare)

mkdir -p "${TOOLS_DIR}"

for tool in "${TOOLS[@]}"; do
  link_one "${tool}"
done

printf 'done: tool links under %s are ready\n' "${TOOLS_DIR}"
