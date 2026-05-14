# git-tools

当前仓库包含 2 个 Git 辅助脚本：

- `create-branch-from-main.sh`：基于最新 `origin/main` 快速创建一个新的本地分支。
- `recreate-branch-from-remote.sh`：删除并重新拉取指定的本地分支，使其与远端 `origin/<branch>` 对齐。

## 使用前提

- 需要在 Git 仓库目录内执行。
- 需要使用 `bash` 执行脚本。
- 执行前已跟踪文件必须是干净状态；脚本会阻止存在未提交已跟踪改动的场景。
- 未跟踪文件不会阻止脚本执行，因为脚本只检查已跟踪文件的工作区状态。

## create-branch-from-main.sh

### 作用

`create-branch-from-main.sh` 用于从最新的 `origin/main` 创建一个新的本地分支，并确保本地 `main` 先与远端 `main` 对齐。

### 用法

```bash
./create-branch-from-main.sh <新分支名>
```

### 示例

```bash
./create-branch-from-main.sh feature/order-refactor
```

### 执行流程

1. 校验当前目录是否为 Git 仓库。
2. 校验已跟踪文件没有未提交改动。
3. 执行 `git fetch --all --prune` 同步远端引用。
4. 校验 `origin/main` 存在。
5. 校验目标分支名既不在本地存在，也不在远端 `origin` 存在。
6. 如果本地 `main` 存在仅本地可见、尚未同步到 `origin/main` 的提交，脚本会直接失败，避免删除本地 `main` 后丢失提交。
7. 如果当前正停留在本地 `main`，脚本会先切到 `origin/main` 的 detached HEAD。
8. 删除本地 `main`，再基于 `origin/main` 重建本地 `main`。
9. 基于最新本地 `main` 创建目标分支。

### 注意事项

- 参数不能为空。
- 目标分支名不能是 `main`。
- 该脚本会删除并重建本地 `main`，但会先校验本地 `main` 是否存在未同步提交。
- 如果远端不存在 `origin/main`，脚本会直接失败。

## recreate-branch-from-remote.sh

### 作用

`recreate-branch-from-remote.sh` 用于重新拉取指定分支：如果本地已存在同名分支，会先删除本地分支，再从远端 `origin/<branch>` 重新创建。

### 用法

```bash
./recreate-branch-from-remote.sh <分支名>
```

### 示例

```bash
./recreate-branch-from-remote.sh feature/order-refactor
```

### 执行流程

1. 校验当前目录是否为 Git 仓库。
2. 校验已跟踪文件没有未提交改动。
3. 执行 `git fetch --all --prune` 同步远端引用。
4. 校验远端 `origin/<分支名>` 存在。
5. 如果当前正位于目标分支，脚本会先创建一个形如 `date_YYYYMMDD_HHMMSS` 的临时分支，避免删除当前分支失败。
6. 如果本地存在目标分支，则强制删除该本地分支。
7. 基于远端 `origin/<分支名>` 重新创建并切换到本地目标分支。

### 注意事项

- 参数不能为空。
- 当前不能处于 detached HEAD。
- 该脚本会删除本地目标分支后重新创建，因此如果本地目标分支存在未推送提交，这些提交会丢失。
- 如果远端不存在 `origin/<分支名>`，脚本会直接失败。

## 建议使用场景

- `create-branch-from-main.sh`：从最新主线快速拉出一个新的开发分支。
- `recreate-branch-from-remote.sh`：本地分支状态混乱，想直接丢弃本地同名分支并以远端状态为准重新拉取。
