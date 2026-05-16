# git-merge.sh

## 作用

`git-merge.sh` 用于基于远端基线分支创建或重建一个本地目标分支，并把另一个远端分支的最新内容合并进来。

## 原理描述

这个脚本的核心原理是把远端分支当成可信输入源，而不是依赖当前本地分支状态。它会先同步远端引用，再以最新 `origin/a` 作为基线创建或重建本地 `b`，最后把最新 `origin/c` 合并进 `b`。这样可以避免“当前本地分支不干净、落后，或者已经偏离远端”导致的基线不一致问题。

执行：

```bash
./git-merge.sh a b c
```

等价语义是：

- 以最新 `origin/a` 作为基线
- 创建或重建本地分支 `b`
- 将最新 `origin/c` 合并到本地分支 `b`

## 用法

```bash
./git-merge.sh <远端基线分支a> <本地目标分支b> <远端来源分支c>
```

### 示例

```bash
./git-merge.sh local feature/test release
```

上面这条命令表示：

- 从最新 `origin/local` 出发
- 创建或重建本地 `feature/test`
- 把最新 `origin/release` 合并到 `feature/test`

## 执行流程

1. 校验参数是否完整；如果没有输入完整参数，直接输出使用方式。
2. 校验本地目标分支名 `b` 不与远端基线分支 `a`、远端来源分支 `c` 同名。
3. 校验当前目录是否为 Git 仓库。
4. 校验已跟踪文件没有未提交改动。
5. 执行 `git fetch --all --prune`，同步远端引用。
6. 校验 `origin/a` 和 `origin/c` 都存在。
7. 如果本地 `b` 已存在，校验它没有仅本地可见、尚未同步到 `origin/a` 的提交，避免被重建覆盖。
8. 执行 `git checkout --detach origin/a`。
9. 执行 `git checkout -B b`，基于最新 `origin/a` 创建或重建本地 `b`。
10. 执行 `git merge --no-edit origin/c`，把远端 `origin/c` 合并到本地 `b`。

## 当前分支影响

当前本地分支是否为 `a`，不影响最终结果。

### 如果当前分支正好是 `a`

脚本不会直接基于本地 `a` 创建 `b`，而是仍然以远端最新 `origin/a` 为准：

```bash
git fetch --all --prune
git checkout --detach origin/a
git checkout -B b
git merge --no-edit origin/c
```

这意味着：

- 本地 `a` 不会被删除
- 本地 `a` 上未 push 的提交不会自动进入 `b`
- `b` 只基于远端最新 `origin/a`

### 如果当前分支不是 `a`

处理逻辑和上面一致，脚本不会先切到本地 `a`，而是直接从远端 `origin/a` 创建 `b`：

```bash
git fetch --all --prune
git checkout --detach origin/a
git checkout -B b
git merge --no-edit origin/c
```

## 注意事项

- 需要在 Git 仓库目录内执行。
- 需要使用 `bash` 执行脚本。
- 参数不能为空，否则会提示：

```bash
用法: ./git-merge.sh <远端基线分支a> <本地目标分支b> <远端来源分支c>
```

- 本地已跟踪文件有未提交改动时，脚本会直接失败。
- 如果远端 `origin/a` 或 `origin/c` 不存在，脚本会直接失败。
- 如果本地 `b` 存在未同步到 `origin/a` 的提交，脚本会直接失败，避免提交丢失。
- 合并 `origin/c` 时如果出现冲突，脚本会停止，需要手工解决冲突。
- 创建后的本地 `b` 不跟踪 `origin/a`；如果后续需要建立 `origin/b` 跟踪关系，需要在合适时机手工执行：

```bash
git push -u origin b
```
