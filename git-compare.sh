#!/usr/bin/env bash
set -euo pipefail

# @description 输出错误信息并退出
# @param $1 错误描述
# @returns 无
fail() {
  printf '错误: %s\n' "$1" >&2
  exit 1
}

# @description 输出脚本帮助信息
# @param 无
# @returns 无
print_help() {
  cat <<'EOF'
用法:
  ./git-compare.sh <目标分支> [对比分支]

说明:
  输出 GitLab Compare 链接，格式为：
  https://<host>/<group>/<repo>/-/compare/<目标分支>..<对比分支>

  如果省略对比分支，则默认使用当前本地分支。

原理:
  读取 origin 远端地址并转换成仓库页面地址，
  再拼接目标分支和对比分支生成 Compare 链接。
EOF
}

# @description 校验当前目录是否位于 Git 仓库内
# @param 无
# @returns 校验失败时直接退出
ensure_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "当前目录不是 Git 仓库"
}

# @description 读取当前仓库的 origin 地址
# @param 无
# @returns 输出 origin 地址；读取失败时直接退出
get_origin_url() {
  git remote get-url origin 2>/dev/null || fail "未找到 origin 远端地址"
}

# @description 将 Git 远端地址转换为可访问的仓库页面地址
# @param $1 Git 远端地址
# @returns 输出转换后的仓库页面地址；无法解析时直接退出
resolve_repo_web_url() {
  local remote_url="$1"
  local host=""
  local repo_path=""

  if [[ "${remote_url}" =~ ^git@([^:]+):(.+)$ ]]; then
    host="${BASH_REMATCH[1]}"
    repo_path="${BASH_REMATCH[2]}"
  elif [[ "${remote_url}" =~ ^https?://([^/]+)/(.+)$ ]]; then
    host="${BASH_REMATCH[1]}"
    repo_path="${BASH_REMATCH[2]}"
  elif [[ "${remote_url}" =~ ^ssh://git@([^/]+)/(.+)$ ]]; then
    host="${BASH_REMATCH[1]}"
    repo_path="${BASH_REMATCH[2]}"
  else
    fail "无法解析 origin 地址: ${remote_url}"
  fi

  repo_path="${repo_path%.git}"
  printf 'https://%s/%s\n' "${host}" "${repo_path}"
}

# @description 拼接 GitLab Compare 链接
# @param $1 仓库页面地址
# @param $2 目标分支
# @param $3 对比分支
# @returns 输出拼接后的 Compare 链接
build_compare_url() {
  local repo_web_url="$1"
  local target_branch="$2"
  local compare_branch="$3"
  local raw_url=""

  printf -v raw_url '%s/-/compare/%s..%s' \
    "${repo_web_url}" \
    "${target_branch}" \
    "${compare_branch}"

  printf '%s\n' "${raw_url}"
}

target_branch="${1:-}"
compare_branch="${2:-}"

if [[ "${target_branch}" == "-h" || "${target_branch}" == "--help" || "${target_branch}" == "help" ]]; then
  print_help
  exit 0
fi

if [[ -z "${target_branch}" ]]; then
  print_help >&2
  exit 1
fi

ensure_git_repo

if [[ -z "${compare_branch}" ]]; then
  compare_branch="$(git branch --show-current)"
  if [[ -z "${compare_branch}" ]]; then
    fail "当前处于 detached HEAD，无法识别默认对比分支，请显式传入对比分支"
  fi
fi

origin_url="$(get_origin_url)"
repo_web_url="$(resolve_repo_web_url "${origin_url}")"
build_compare_url "${repo_web_url}" "${target_branch}" "${compare_branch}"
