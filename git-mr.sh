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
  ./git-mr.sh <目标分支>

说明:
  输出当前分支到目标分支的 GitLab Merge Request 新建链接。

原理:
  读取 origin 远端地址并转换成仓库页面地址，
  再拼接当前分支和目标分支生成 MR 创建链接。
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

# @description 拼接 GitLab 新建 MR 链接
# @param $1 仓库页面地址
# @param $2 源分支
# @param $3 目标分支
# @returns 输出拼接后的 MR 链接
build_merge_request_url() {
  local repo_web_url="$1"
  local source_branch="$2"
  local target_branch="$3"
  local raw_url=""

  printf -v raw_url '%s/-/merge_requests/new?merge_request[source_branch]=%s&merge_request[target_branch]=%s' \
    "${repo_web_url}" \
    "${source_branch}" \
    "${target_branch}"

  printf '%s\n' "${raw_url}"
}

target_branch="${1:-}"

if [[ "${target_branch}" == "-h" || "${target_branch}" == "--help" || "${target_branch}" == "help" ]]; then
  print_help
  exit 0
fi

if [[ -z "${target_branch}" ]]; then
  print_help >&2
  exit 1
fi

ensure_git_repo

current_branch="$(git branch --show-current)"
if [[ -z "${current_branch}" ]]; then
  fail "当前处于 detached HEAD，无法识别源分支"
fi

origin_url="$(get_origin_url)"
repo_web_url="$(resolve_repo_web_url "${origin_url}")"
build_merge_request_url "${repo_web_url}" "${current_branch}" "${target_branch}"
