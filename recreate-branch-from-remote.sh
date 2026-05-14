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

# @description 校验当前目录是否位于 Git 仓库内
# @param 无
# @returns 校验失败时直接退出
ensure_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "当前目录不是 Git 仓库"
}

# @description 校验已跟踪文件是否干净，忽略未跟踪文件，避免切换分支和删分支时夹带未提交改动
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

target_branch="${1:-}"
remote_name="origin"
temp_branch="date_$(date +%Y%m%d_%H%M%S)"

ensure_git_repo

if [[ -z "${target_branch}" ]]; then
  fail "用法: ./recreate-branch-from-remote.sh <分支名>"
fi

current_branch="$(git branch --show-current)"
if [[ -z "${current_branch}" ]]; then
  fail "当前处于 detached HEAD，无法安全执行，请先切回一个本地分支"
fi

step 1 "校验仓库状态与输入参数"
ensure_clean_worktree

step 2 "同步远端分支引用"
git fetch --all --prune
ensure_remote_branch_exists "${remote_name}/${target_branch}"

step 3 "必要时切换到临时分支，避免删除当前分支失败"
if [[ "${current_branch}" == "${target_branch}" ]]; then
  if git show-ref --verify --quiet "refs/heads/${temp_branch}"; then
    fail "临时分支 ${temp_branch} 已存在，请稍后重试"
  fi
  git checkout -b "${temp_branch}"
fi

step 4 "删除本地分支 ${target_branch}"
if git show-ref --verify --quiet "refs/heads/${target_branch}"; then
  git branch -D "${target_branch}"
fi

step 5 "从远端重新拉取并切换到 ${target_branch}"
git checkout -b "${target_branch}" "${remote_name}/${target_branch}"

printf '\n完成: 已从 %s/%s 重新拉取本地分支 %s\n' "${remote_name}" "${target_branch}" "${target_branch}"
