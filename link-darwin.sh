#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '错误: %s\n' "$1" >&2
  exit 1
}

link_one() {
  local name="$1"
  local source_path="${SCRIPT_DIR}/${name}"
  local target_path="${TOOLS_DIR}/${name}"

  [[ -f "${source_path}" ]] || fail "未找到源文件: ${source_path}"

  if [[ -e "${target_path}" || -L "${target_path}" ]]; then
    printf '已存在，跳过: %s\n' "${target_path}"
    return
  fi

  ln -s "${source_path}" "${target_path}"
  printf '已链接: %s -> %s\n' "${target_path}" "${source_path}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${HOME}/tools"
TOOLS=(gam gt merge mr cmpr)

mkdir -p "${TOOLS_DIR}"

for tool in "${TOOLS[@]}"; do
  link_one "${tool}"
done

printf '完成: 已更新 %s 下的工具链接\n' "${TOOLS_DIR}"
