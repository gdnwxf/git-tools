# git-tools

当前仓库包含 2 个 Git 辅助脚本：

- `create-branch-from-remote.sh`：基于指定远端分支创建新的本地分支；如果只传一个参数，则默认按同名远端分支创建。
- `git-sync.sh`：支持 `new` 和 `sync` 两种模式；既能基于远端创建新分支，也能按远端重建本地分支。

## 使用前提

- 需要在 Git 仓库目录内执行。
- 需要使用 `bash` 执行脚本。
- 执行前已跟踪文件必须是干净状态；脚本会阻止存在未提交已跟踪改动的场景。
- 未跟踪文件不会阻止脚本执行，因为脚本只检查已跟踪文件的工作区状态。

## create-branch-from-remote.sh

### 作用

`create-branch-from-remote.sh` 用于基于指定远端分支创建一个新的本地分支。如果只传本地分支名 `a`，则默认从最新 `origin/a` 创建；如果传入 `a b`，则从最新 `origin/b` 创建本地 `a`。

### 原理描述

这个脚本的核心原理是先用 `git fetch --all --prune` 把远端引用同步到本地，再确认目标远端分支存在，最后直接基于这个远端基线创建新的本地分支。这样可以避免依赖当前本地分支状态，也能保证创建动作始终以远端为准。

### 用法

```bash
./create-branch-from-remote.sh <本地分支名a> [远端分支名b]
```

### 示例

```bash
./create-branch-from-remote.sh feature/order-refactor
./create-branch-from-remote.sh feature/order-refactor release
```

第一条命令表示本地 `feature/order-refactor` 按最新 `origin/feature/order-refactor` 创建。  
第二条命令表示本地 `feature/order-refactor` 按最新 `origin/release` 创建。

### 执行流程

1. 校验当前目录是否为 Git 仓库。
2. 校验已跟踪文件没有未提交改动。
3. 执行 `git fetch --all --prune` 同步远端引用。
4. 解析远端基线分支：如果传了 `b`，使用 `origin/b`；如果只传了 `a`，使用 `origin/a`。
5. 校验目标远端分支存在。
6. 校验目标本地分支名在本地不存在。
7. 基于目标远端分支创建并切换到本地目标分支。

### 注意事项

- 参数不能为空。
- 该脚本只负责创建新分支，不会覆盖已存在的本地目标分支。
- 如果本地已存在同名目标分支 `a`，脚本会直接失败。
- 如果目标远端分支不存在，脚本会直接失败。

## git-sync.sh

### 作用

`git-sync.sh` 用于统一处理两类场景：

- `new`：基于指定远端分支创建新的本地分支
- `sync`：按指定远端分支重建本地分支；如果本地目标分支已存在，会先删除再重建

为了兼容旧用法，如果省略模式，默认按 `sync` 处理。

### 原理描述

这个脚本的核心原理是把远端 `origin/<branch>` 作为统一可信基线。执行时先同步远端引用，然后根据模式决定是“新建”还是“重建”：`new` 模式直接创建本地分支，`sync` 模式先清理旧本地分支再按远端重建。

### 用法

```bash
./git-sync.sh new <本地分支名a> [远端分支名b]
./git-sync.sh sync <本地分支名a> [远端分支名b]
./git-sync.sh <本地分支名a> [远端分支名b]
```

### 示例

```bash
./git-sync.sh new feature/order-refactor
./git-sync.sh new feature/order-refactor release
./git-sync.sh sync feature/order-refactor
./git-sync.sh sync feature/order-refactor release
```

第一条命令表示新建本地 `feature/order-refactor`，基线是最新 `origin/feature/order-refactor`。  
第二条命令表示新建本地 `feature/order-refactor`，基线是最新 `origin/release`。  
第三条命令表示本地 `feature/order-refactor` 直接按最新 `origin/feature/order-refactor` 重建。  
第四条命令表示本地 `feature/order-refactor` 按最新 `origin/release` 重建。  
如果省略 `sync` 模式名，则保持旧行为，默认按重建处理。

### 执行流程

1. 校验当前目录是否为 Git 仓库。
2. 校验已跟踪文件没有未提交改动。
3. 执行 `git fetch --all --prune` 同步远端引用。
4. 解析远端基线分支：如果传了 `b`，使用 `origin/b`；如果只传了 `a`，使用 `origin/a`。
5. 校验目标远端分支存在。
6. 如果是 `new` 模式，校验本地目标分支 `a` 不存在，然后基于目标远端分支创建本地分支。
7. 如果是 `sync` 模式，先校验本地目标分支 `a` 不存在仅本地可见、尚未同步到目标远端分支的提交。
8. 如果是 `sync` 模式且当前正位于本地目标分支 `a`，脚本会先创建一个形如 `date_YYYYMMDD_HHMMSS` 的临时分支，避免删除当前分支失败。
9. 如果是 `sync` 模式且本地存在目标分支 `a`，则强制删除该本地分支。
10. 基于目标远端分支创建或重建并切换到本地目标分支 `a`。

### 注意事项

- 参数不能为空。
- `new` 模式只负责创建新分支，不会覆盖已存在的本地目标分支。
- `sync` 模式在当前处于 detached HEAD 时会直接失败。
- `sync` 模式会先校验本地目标分支是否存在未同步到目标远端分支的提交，避免删除后丢失本地独有提交。
- 如果目标远端分支不存在，脚本会直接失败。

## 建议使用场景

- `create-branch-from-remote.sh`：从指定远端分支快速拉出一个新的本地分支，且创建动作始终以远端状态为准。
- `git-sync.sh`：希望统一入口处理“新建分支”和“按远端重建分支”两类动作时使用；默认省略模式时按 `sync` 处理。
