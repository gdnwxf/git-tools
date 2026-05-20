#!/usr/bin/env bash
set -euo pipefail

# @description 输出步骤日志，便于定位执行进度
# @param $1 步骤编号
# @param $2 步骤说明
# @returns 无
step() {
  printf '\n步骤%s: %s\n' "$1" "$2"
}

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
  ./create-branch-from-remote.sh <本地分支名a> [远端分支名b]

说明:
  基于最新远端分支创建新的本地分支 a。
  如果传了 b，则按最新 origin/b 创建；
  如果只传 a，则按最新 origin/a 创建。

原理:
  先同步远端引用，确认目标远端分支存在，
  再基于这个远端基线创建新的本地分支 a，
  避免依赖当前本地分支状态。
EOF
}

# @description 校验当前目录是否位于 Git 仓库内
# @param 无
# @returns 校验失败时直接退出
ensure_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "当前目录不是 Git 仓库"
}

# @description 校验已跟踪文件是否干净，忽略未跟踪文件，避免切换分支时夹带未提交改动
# @param 无
# @returns 校验失败时直接退出
ensure_clean_worktree() {
  if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    fail "检测到已跟踪文件存在未提交改动，请先提交或 stash 后再执行"
  fi
}

# @description 校验远端目标分支是否存在
# @param $1 远端分支引用
# @returns 校验失败时直接退出
ensure_remote_branch_exists() {
  local remote_branch_ref="$1"
  git show-ref --verify --quiet "refs/remotes/${remote_branch_ref}" || fail "远端分支 ${remote_branch_ref} 不存在"
}

# @description 校验目标分支在本地不存在，避免覆盖已有分支
# @param $1 目标分支名
# @returns 校验失败时直接退出
ensure_target_branch_available() {
  local branch_name="$1"

  if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
    fail "本地分支 ${branch_name} 已存在，请更换参数"
  fi
}

target_branch="${1:-}"
remote_branch="${2:-}"
remote_name="origin"

if [[ "${target_branch}" == "-h" || "${target_branch}" == "--help" || "${target_branch}" == "help" ]]; then
  print_help
  exit 0
fi

if [[ -z "${target_branch}" ]]; then
  print_help >&2
  exit 1
fi

if [[ -z "${remote_branch}" ]]; then
  remote_branch="${target_branch}"
fi

ensure_git_repo

step 1 "校验仓库状态与输入参数"
ensure_clean_worktree

step 2 "同步远端分支引用"
git fetch --all --prune
ensure_remote_branch_exists "${remote_name}/${remote_branch}"
ensure_target_branch_available "${target_branch}"

step 3 "基于最新 ${remote_name}/${remote_branch} 创建本地分支 ${target_branch}"
git checkout --detach "${remote_name}/${remote_branch}"
git checkout -b "${target_branch}"

printf '\n完成: 已基于 %s/%s 创建本地分支 %s\n' "${remote_name}" "${remote_branch}" "${target_branch}"
