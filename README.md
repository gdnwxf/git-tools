# git-tools

当前仓库包含 5 个 Git 辅助脚本和 1 份独立说明文档。

脚本：

- `create-branch-from-remote.sh`：基于指定远端分支创建新的本地分支；如果只传一个参数，则默认按同名远端分支创建。
- `git-sync.sh`：支持 `new` 和 `sync` 两种模式；既能基于远端创建新分支，也能按远端重建本地分支。
- `git-mr.sh`：输出当前分支到目标分支的 GitLab Merge Request 新建链接。
- `git-compare.sh`：输出目标分支与对比分支的 GitLab Compare 链接。
- `git-merge.sh`：基于远端基线分支创建或重建本地目标分支，再合并另一个远端分支。

独立文档：

- `git-merge.md`：单独说明 `git-merge.sh` 的使用方式、执行流程和注意事项。

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
11. 如果本次创建过临时分支，则在成功切回目标分支后删除该临时分支。

### 注意事项

- 参数不能为空。
- `new` 模式只负责创建新分支，不会覆盖已存在的本地目标分支。
- `sync` 模式在当前处于 detached HEAD 时会直接失败。
- `sync` 模式会先校验本地目标分支是否存在未同步到目标远端分支的提交，避免删除后丢失本地独有提交。
- `sync` 模式创建的临时分支只用于避开当前分支删除限制；成功重建并切回目标分支后会自动删除。
- 如果目标远端分支不存在，脚本会直接失败。

## 建议使用场景

- `create-branch-from-remote.sh`：从指定远端分支快速拉出一个新的本地分支，且创建动作始终以远端状态为准。
- `git-sync.sh`：希望统一入口处理“新建分支”和“按远端重建分支”两类动作时使用；默认省略模式时按 `sync` 处理。
- `git-mr.sh`：已经切到源分支，只想快速生成当前分支指向目标分支的 GitLab MR 新建链接时使用。
- `git-compare.sh`：想快速打开目标分支和当前分支，或两个指定分支之间的 GitLab Compare 页面时使用。
- `git-merge.sh`：希望严格以远端 `origin/a` 为基线，先创建或重建本地 `b`，再把最新 `origin/c` 合并进来时使用。

## git-mr.sh

### 作用

`git-mr.sh` 用于输出当前分支到目标分支的 GitLab Merge Request 新建链接。

### 原理描述

这个脚本的核心原理是读取当前仓库的 `origin` 远端地址，转换成浏览器可访问的仓库页面地址，再拼接当前分支名和目标分支名，生成一个可直接打开的 MR 创建链接。

### 用法

```bash
./git-mr.sh <目标分支>
```

### 示例

```bash
./git-mr.sh release
```

这条命令表示基于当前所在本地分支，生成一个目标分支为 `release` 的 GitLab MR 新建链接。

### 执行流程

1. 校验当前目录是否为 Git 仓库。
2. 校验当前不是 detached HEAD，确保可以识别当前源分支。
3. 读取 `origin` 远端地址。
4. 把远端地址转换为仓库页面地址。
5. 基于当前分支和目标分支拼接 MR 新建链接并输出。

### 注意事项

- 参数不能为空。
- 该脚本只输出链接，不会执行 `git push`、`git merge` 或创建 MR。
- 当前处于 detached HEAD 时，脚本会直接失败。
- 目前默认按 GitLab 的 MR 地址格式拼接链接。

## git-compare.sh

### 作用

`git-compare.sh` 用于输出 GitLab Compare 链接。脚本会自动读取当前仓库的 `origin` 地址，转换成仓库页面地址，再拼接目标分支和对比分支。

### 原理描述

这个脚本的核心原理是把 `origin` 远端地址解析为 `https://<host>/<group>/<repo>`，然后拼接成 `https://<host>/<group>/<repo>/-/compare/<目标分支>..<对比分支>`。

### 用法

```bash
./git-compare.sh <目标分支> [对比分支]
```

如果省略对比分支，则默认使用当前本地分支。

### 示例

```bash
./git-compare.sh release
./git-compare.sh release feature/order-refactor
```

第一条命令表示输出 `release..当前分支` 的 Compare 链接。  
第二条命令表示输出 `release..feature/order-refactor` 的 Compare 链接。

### 执行流程

1. 校验当前目录是否为 Git 仓库。
2. 读取 `origin` 远端地址。
3. 把远端地址转换为仓库页面地址。
4. 如果没有显式传入对比分支，则读取当前本地分支作为对比分支。
5. 基于目标分支和对比分支拼接 Compare 链接并输出。

### 注意事项

- 参数不能为空。
- 该脚本只输出链接，不会执行 `git push`、`git merge` 或创建 Compare 页面。
- 省略对比分支且当前处于 detached HEAD 时，脚本会直接失败。
- 目前默认按 GitLab 的 Compare 地址格式拼接链接。

## git-merge.sh

### 作用

`git-merge.sh` 用于基于远端基线分支创建或重建一个本地目标分支，并把另一个远端分支的最新内容合并进来。

### 原理描述

这个脚本的核心原理是把远端分支当成可信输入源，而不是依赖当前本地分支状态。它会先同步远端引用，再以最新 `origin/a` 作为基线创建或重建本地 `b`，最后把最新 `origin/c` 合并进 `b`。这样可以避免“当前本地分支不干净、落后，或者已经偏离远端”导致的基线不一致问题。

### 用法

```bash
./git-merge.sh <远端基线分支a> <本地目标分支b> <远端来源分支c>
```

### 示例

```bash
./git-merge.sh local feature/test release
```

上面这条命令表示本地 `feature/test` 会先按最新 `origin/local` 创建或重建，再把最新 `origin/release` 合并进来。

### 执行流程

1. 校验参数是否完整。
2. 校验本地目标分支名 `b` 不与远端基线分支 `a`、远端来源分支 `c` 同名。
3. 校验当前目录是否为 Git 仓库。
4. 校验已跟踪文件没有未提交改动。
5. 执行 `git fetch --all --prune`，同步远端引用。
6. 校验 `origin/a` 和 `origin/c` 都存在。
7. 如果本地 `b` 已存在，校验它没有仅本地可见、尚未同步到 `origin/a` 的提交。
8. 执行 `git checkout --detach origin/a`。
9. 执行 `git checkout -B b`，基于最新 `origin/a` 创建或重建本地 `b`。
10. 执行 `git merge --no-edit origin/c`，把远端 `origin/c` 合并到本地 `b`。

### 当前分支影响

当前本地分支是否为 `a`，不影响最终结果。脚本不会先依赖本地 `a`，而是直接以远端最新 `origin/a` 为准创建或重建本地 `b`。

### 注意事项

- 参数不能为空。
- 本地已跟踪文件有未提交改动时，脚本会直接失败。
- 如果远端 `origin/a` 或 `origin/c` 不存在，脚本会直接失败。
- 如果本地 `b` 存在未同步到 `origin/a` 的提交，脚本会直接失败，避免提交丢失。
- 合并 `origin/c` 时如果出现冲突，脚本会停止，需要手工解决冲突。
- 更完整的流程说明可查看 [git-merge.md](./git-merge.md)。
