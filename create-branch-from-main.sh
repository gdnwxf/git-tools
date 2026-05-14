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

# @description 校验已跟踪文件是否干净，忽略未跟踪文件，避免切换分支时夹带未提交改动
# @param 无
# @returns 校验失败时直接退出
ensure_clean_worktree() {
  if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    fail "检测到已跟踪文件存在未提交改动，请先提交或 stash 后再执行"
  fi
}

# @description 判断远端分支是否存在
# @param $1 远端分支引用
# @returns 存在时返回 0，不存在时返回 1
remote_branch_exists() {
  local remote_branch_ref="$1"
  git show-ref --verify --quiet "refs/remotes/${remote_branch_ref}"
}

# @description 解析可用的远端基线分支，优先 main，其次 master
# @param $1 远端名
# @returns 输出解析出的基线分支名；若都不存在则直接退出
resolve_base_branch() {
  local remote_name="$1"

  if remote_branch_exists "${remote_name}/main"; then
    printf 'main\n'
    return
  fi

  if remote_branch_exists "${remote_name}/master"; then
    printf 'master\n'
    return
  fi

  fail "远端分支 ${remote_name}/main 和 ${remote_name}/master 都不存在，请先执行 git fetch --all --prune 检查远端状态"
}

# @description 校验目标分支在本地和远端都不存在，避免覆盖已有分支
# @param $1 目标分支名
# @returns 校验失败时直接退出
ensure_target_branch_available() {
  local branch_name="$1"

  if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
    fail "本地分支 ${branch_name} 已存在，请更换参数"
  fi

  if git show-ref --verify --quiet "refs/remotes/origin/${branch_name}"; then
    fail "远端分支 origin/${branch_name} 已存在，请更换参数"
  fi
}

# @description 校验本地基线分支不存在仅本地可见的提交，避免删除后丢失提交
# @param $1 本地基线分支名
# @param $2 远端基线分支引用
# @returns 校验失败时直接退出
ensure_base_branch_has_no_local_only_commits() {
  local base_branch="$1"
  local remote_base_ref="$2"

  if ! git show-ref --verify --quiet "refs/heads/${base_branch}"; then
    return
  fi

  # 这里显式阻断本地基线分支超前于远端基线分支的场景，避免删除后丢失仅存在于本地的提交。
  if [[ "$(git rev-list --count "${remote_base_ref}..${base_branch}")" -gt 0 ]]; then
    fail "本地分支 ${base_branch} 存在未同步到 ${remote_base_ref} 的提交，已停止执行以避免提交丢失"
  fi
}

target_branch="${1:-}"
remote_name="origin"
base_branch=""
remote_base_ref=""

ensure_git_repo

if [[ -z "${target_branch}" ]]; then
  fail "用法: ./create-branch-from-main.sh <新分支名>"
fi

current_branch="$(git branch --show-current)"
if [[ -z "${current_branch}" ]]; then
  fail "当前处于 detached HEAD，无法安全执行，请先切回一个本地分支"
fi

step 1 "校验仓库状态与输入参数"
ensure_clean_worktree

step 2 "同步所有远端分支引用"
git fetch --all --prune
base_branch="$(resolve_base_branch "${remote_name}")"
remote_base_ref="${remote_name}/${base_branch}"
printf '步骤2结果: 选用远端基线分支 %s\n' "${remote_base_ref}"
ensure_target_branch_available "${target_branch}"
ensure_base_branch_has_no_local_only_commits "${base_branch}" "${remote_base_ref}"

step 3 "必要时脱离本地 ${base_branch}，避免删除当前分支失败"
if [[ "${current_branch}" == "${base_branch}" ]]; then
  git checkout --detach "${remote_base_ref}"
fi

step 4 "删除并重建本地 ${base_branch}"
if git show-ref --verify --quiet "refs/heads/${base_branch}"; then
  git branch -D "${base_branch}"
fi
git checkout -b "${base_branch}" "${remote_base_ref}"
git pull --ff-only "${remote_name}" "${base_branch}"

step 5 "基于最新 ${base_branch} 创建目标分支 ${target_branch}"
git checkout -b "${target_branch}"

printf '\n完成: 已基于 %s 创建本地分支 %s\n' "${base_branch}" "${target_branch}"
