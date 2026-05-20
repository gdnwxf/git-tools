# merge

## 作用

`merge` 用于基于远端基线分支创建或重建一个本地目标分支，并把另一个远端分支的最新内容合并进来。传 2 个参数时，会按最新 `origin/a` 重建本地 `a`，再把最新 `origin/b` 合并到本地 `a`。

## 原理描述

这个脚本的核心原理是把远端分支当成可信输入源，而不是依赖当前本地分支状态。它会先同步远端引用，再以最新 `origin/a` 作为基线创建或重建本地目标分支，最后把指定来源远端分支合并进目标分支。这样可以避免“当前本地分支不干净、落后，或者已经偏离远端”导致的基线不一致问题。

执行：

```bash
./merge a c
./merge a b c
```

2 参数等价语义是：

- 以最新 `origin/a` 作为基线
- 创建或重建本地分支 `a`
- 将最新 `origin/c` 合并到本地分支 `a`

3 参数等价语义是：

- 以最新 `origin/a` 作为基线
- 创建或重建本地分支 `b`
- 将最新 `origin/c` 合并到本地分支 `b`

## 用法

```bash
./merge <远端基线分支a> <远端来源分支b>
./merge <远端基线分支a> <本地目标分支b> <远端来源分支c>
./gt merge <远端基线分支a> <远端来源分支b>
./gt merge <远端基线分支a> <本地目标分支b> <远端来源分支c>
```

### 示例

```bash
./merge local release
./merge local feature/test release
./gt merge local release
./gt merge local feature/test release
```

第一条命令表示：

- 从最新 `origin/local` 出发
- 创建或重建本地 `local`
- 把最新 `origin/release` 合并到 `local`

第二条命令表示：

- 从最新 `origin/local` 出发
- 创建或重建本地 `feature/test`
- 把最新 `origin/release` 合并到 `feature/test`

## 执行流程

1. 校验参数是否完整，只允许 2 个或 3 个业务参数。
2. 如果传 2 个参数，则本地目标分支使用远端基线分支 `a`；如果传 3 个参数，则本地目标分支使用第二个参数 `b`。
3. 传 3 个参数时，校验本地目标分支名 `b` 不与远端基线分支 `a`、远端来源分支 `c` 同名。
4. 校验当前目录是否为 Git 仓库。
5. 校验已跟踪文件没有未提交改动。
6. 执行 `git fetch --all --prune`，同步远端引用。
7. 校验远端基线分支和远端来源分支都存在。
8. 如果本地目标分支已存在，校验它没有仅本地可见、尚未同步到远端基线分支的提交，避免被重建覆盖。
9. 执行 `git checkout --detach origin/a`。
10. 执行 `git checkout -B <本地目标分支>`，基于最新 `origin/a` 创建或重建本地目标分支。
11. 执行 `git merge --no-edit <远端来源分支>`，把远端来源分支合并到本地目标分支。

## 当前分支影响

当前本地分支是否为 `a`，不影响最终结果。

### 如果当前分支正好是 `a`

脚本不会直接基于本地 `a` 创建目标分支，而是仍然以远端最新 `origin/a` 为准：

```bash
git fetch --all --prune
git checkout --detach origin/a
git checkout -B b
git merge --no-edit origin/c
```

这意味着：

- 本地 `a` 不会被删除
- 本地 `a` 上未 push 的提交不会自动进入 `b`
- 目标分支只基于远端最新 `origin/a`

### 如果当前分支不是 `a`

处理逻辑和上面一致，脚本不会先切到本地 `a`，而是直接从远端 `origin/a` 创建目标分支：

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
用法:
  ./merge <远端基线分支a> <远端来源分支b>
  ./merge <远端基线分支a> <本地目标分支b> <远端来源分支c>
  ./gt merge <远端基线分支a> <远端来源分支b>
  ./gt merge <远端基线分支a> <本地目标分支b> <远端来源分支c>
```

- 本地已跟踪文件有未提交改动时，脚本会直接失败。
- 如果远端基线分支或远端来源分支不存在，脚本会直接失败。
- 如果本地目标分支存在未同步到远端基线分支的提交，脚本会直接失败，避免提交丢失。
- 合并 `origin/c` 时如果出现冲突，脚本会停止，需要手工解决冲突。
- 创建后的本地 `b` 不跟踪 `origin/a`；如果后续需要建立 `origin/b` 跟踪关系，需要在合适时机手工执行：

```bash
git push -u origin b
```
