# git-tools

当前仓库包含 5 个 Git 辅助脚本。

脚本：

- `gt`：支持 `new`、`sync`、`cmpr`、`mr`、`merge`、`gam` 子命令；既能基于远端创建或重建分支，也能输出 Compare/MR 链接和执行合并。
- `git-mr`：输出当前分支到目标分支的 GitLab Merge Request 新建链接。
- `git-compare`：输出目标分支与对比分支的 GitLab Compare 链接。
- `git-merge`：基于远端基线分支创建或重建本地目标分支，再合并另一个远端分支。
- `git-auto-merge`：通过 GitLab API 创建 Merge Request，检测冲突后自动合并。

## 使用前提

- 需要在 Git 仓库目录内执行。
- 需要使用 `bash` 执行脚本。
- 执行前已跟踪文件必须是干净状态；脚本会阻止存在未提交已跟踪改动的场景。
- 未跟踪文件不会阻止脚本执行，因为脚本只检查已跟踪文件的工作区状态。

## gt

### 作用

`gt` 用于统一处理多类 Git 辅助场景：

- 无参数：快进同步最新 `origin/<当前分支>` 到当前本地分支，不删除、不重建本地分支
- `new`：基于指定远端分支创建新的本地分支
- `sync`：按指定远端分支重建本地分支；如果本地目标分支已存在，会先删除再重建
- `cmpr`：委托 `git-compare` 输出 GitLab Compare 链接
- `mr`：委托 `git-mr` 输出 GitLab Merge Request 新建链接
- `merge`：委托 `git-merge` 基于远端基线分支创建或重建本地目标分支，再合并远端来源分支
- `gam`：委托 `git-auto-merge` 通过 GitLab API 创建 Merge Request，检测冲突后自动合并

为了兼容旧用法，如果传入分支名但省略模式，默认按 `sync` 处理。

### 原理描述

这个脚本的核心原理是把远端 `origin/<branch>` 作为统一可信基线。执行时先同步远端引用，然后根据模式决定动作：无参数时使用 `git merge --ff-only origin/<当前分支>` 快进同步当前分支；`new` 模式直接创建本地分支；`sync` 模式先清理旧本地分支再按远端重建。

### 用法

```bash
./gt
./gt new <本地分支名a> [远端分支名b]
./gt sync <本地分支名a> [远端分支名b]
./gt <本地分支名a> [远端分支名b]
./gt cmpr <目标远端分支> [对比分支]
./gt mr <目标分支>
./gt mr <源分支> <目标分支>
./gt merge <远端基线分支a> <远端来源分支b>
./gt merge <远端基线分支a> <本地目标分支b> <远端来源分支c>
./gt gam <源分支> <目标分支>
```

### 示例

```bash
./gt
./gt new feature/order-refactor
./gt new feature/order-refactor release
./gt sync feature/order-refactor
./gt sync feature/order-refactor release
./gt cmpr release
./gt mr release
./gt mr feature/order-refactor release
./gt merge local release
./gt merge local feature/test release
./gt gam feature/order-refactor release
```

第一条命令表示快进同步最新 `origin/<当前分支>` 到当前本地分支，不删除、不重建本地分支。
第二条命令表示新建本地 `feature/order-refactor`，基线是最新 `origin/feature/order-refactor`。
第三条命令表示新建本地 `feature/order-refactor`，基线是最新 `origin/release`。
第四条命令表示本地 `feature/order-refactor` 直接按最新 `origin/feature/order-refactor` 重建。
第五条命令表示本地 `feature/order-refactor` 按最新 `origin/release` 重建。
如果传入分支名但省略 `sync` 模式名，则保持旧行为，默认按重建处理。`gt cmpr`、`gt mr`、`gt merge`、`gt gam` 分别等价于独立执行 `git-compare`、`git-mr`、`git-merge`、`git-auto-merge`。
`gt mr feature/order-refactor release` 表示直接生成源分支 `feature/order-refactor` 指向目标分支 `release` 的 MR 新建链接。
`gt gam feature/order-refactor release` 表示通过 GitLab API 创建源分支 `feature/order-refactor` 指向目标分支 `release` 的 MR，检测冲突后自动合并。

### 执行流程

1. 校验当前目录是否为 Git 仓库。
2. 校验已跟踪文件没有未提交改动。
3. 执行 `git fetch --all --prune` 同步远端引用。
4. 如果不带参数，读取当前分支，校验 `origin/<当前分支>` 存在，然后执行 `git merge --ff-only origin/<当前分支>`。
5. 如果是 `new` 或 `sync` 模式，解析远端基线分支：如果传了 `b`，使用 `origin/b`；如果只传了 `a`，使用 `origin/a`。
6. 校验目标远端分支存在。
7. 如果是 `new` 模式，校验本地目标分支 `a` 不存在，然后基于目标远端分支创建本地分支。
8. 如果是 `sync` 模式，先校验本地目标分支 `a` 不存在仅本地可见、尚未同步到目标远端分支的提交。
9. 如果是 `sync` 模式且当前正位于本地目标分支 `a`，脚本会先创建一个形如 `date_YYYYMMDD_HHMMSS` 的临时分支，避免删除当前分支失败。
10. 如果是 `sync` 模式且本地存在目标分支 `a`，则强制删除该本地分支。
11. 基于目标远端分支创建或重建并切换到本地目标分支 `a`。
12. 如果本次创建过临时分支，则在成功切回目标分支后删除该临时分支。

### 注意事项

- 不带参数时只执行快进同步；如果当前本地分支和远端分支已经分叉，脚本会失败并要求手动处理。
- `new` 模式只负责创建新分支，不会覆盖已存在的本地目标分支。
- `sync` 模式会删除并重建本地目标分支；它和不带参数的快进同步不是同一个动作。
- `sync` 模式在当前处于 detached HEAD 时会直接失败。
- `sync` 模式会先校验本地目标分支是否存在未同步到目标远端分支的提交，避免删除后丢失本地独有提交。
- `sync` 模式创建的临时分支只用于避开当前分支删除限制；成功重建并切回目标分支后会自动删除。
- 如果目标远端分支不存在，脚本会直接失败。

## 建议使用场景

- `gt`：不带参数时用于快进同步当前分支；传入分支名但省略模式时按 `sync` 重建处理；也可统一入口处理“新建分支”和“按远端重建分支”。
- `git-mr` 或 `gt mr`：想快速生成当前分支或指定源分支指向目标分支的 GitLab MR 新建链接时使用。
- `git-compare` 或 `gt cmpr`：想快速打开目标分支和当前分支，或两个指定分支之间的 GitLab Compare 页面时使用。
- `git-merge` 或 `gt merge`：希望严格以远端基线分支为准创建或重建本地目标分支，再把最新来源分支合并进来时使用。
- `git-auto-merge` 或 `gt gam`：希望通过 GitLab API 创建 MR，检测冲突后自动合并时使用。

## git-mr

### 作用

`git-mr` 用于输出当前分支到目标分支的 GitLab Merge Request 新建链接；也支持显式指定源分支和目标分支。

### 原理描述

这个脚本的核心原理是读取当前仓库的 `origin` 远端地址，转换成浏览器可访问的仓库页面地址，再拼接源分支名和目标分支名，生成一个可直接打开的 MR 创建链接。只传目标分支时，源分支默认使用当前本地分支。

### 用法

```bash
./git-mr <目标分支>
./git-mr <源分支> <目标分支>
./gt mr <目标分支>
./gt mr <源分支> <目标分支>
```

### 示例

```bash
./git-mr release
./git-mr feature/order-refactor release
./gt mr release
./gt mr feature/order-refactor release
```

`./git-mr release` 和 `./gt mr release` 表示基于当前所在本地分支，生成一个目标分支为 `release` 的 GitLab MR 新建链接。

`./git-mr feature/order-refactor release` 和 `./gt mr feature/order-refactor release` 表示直接生成源分支 `feature/order-refactor` 指向目标分支 `release` 的 MR 新建链接。

### 执行流程

1. 校验当前目录是否为 Git 仓库。
2. 如果没有显式传入源分支，校验当前不是 detached HEAD，确保可以识别默认源分支。
3. 读取 `origin` 远端地址。
4. 把远端地址转换为仓库页面地址。
5. 基于源分支和目标分支拼接 MR 新建链接并输出。

### 注意事项

- 参数不能为空。
- 该脚本只输出链接，不会执行 `git push`、`git merge` 或创建 MR。
- 省略源分支且当前处于 detached HEAD 时，脚本会直接失败；显式传入源分支时不依赖当前分支。
- 目前默认按 GitLab 的 MR 地址格式拼接链接。

## git-compare

### 作用

`git-compare` 用于输出 GitLab Compare 链接。脚本会自动读取当前仓库的 `origin` 地址，转换成仓库页面地址，再拼接目标远端分支和对比分支。

### 原理描述

这个脚本的核心原理是把 `origin` 远端地址解析为 `https://<host>/<group>/<repo>`，然后拼接成 `https://<host>/<group>/<repo>/-/compare/<目标远端分支>...<对比分支>`。

### 用法

```bash
./git-compare <目标远端分支> [对比分支]
./gt cmpr <目标远端分支> [对比分支]
```

如果省略对比分支，则默认使用当前本地分支，表示当前本地分支和目标远端分支做对比。

### 示例

```bash
./git-compare release
./git-compare release feature/order-refactor
./gt cmpr release
./gt cmpr release feature/order-refactor
```

第一条命令表示输出 `release...当前分支` 的 Compare 链接，也就是当前本地分支和远程分支 `origin/release` 做对比。  
第二条命令表示输出 `release...feature/order-refactor` 的 Compare 链接。

### 执行流程

1. 校验当前目录是否为 Git 仓库。
2. 读取 `origin` 远端地址。
3. 把远端地址转换为仓库页面地址。
4. 如果没有显式传入对比分支，则读取当前本地分支作为对比分支。
5. 基于目标远端分支和对比分支拼接 Compare 链接并输出。

### 注意事项

- 参数不能为空。
- 该脚本只输出链接，不会执行 `git push`、`git merge` 或创建 Compare 页面。
- 省略对比分支且当前处于 detached HEAD 时，脚本会直接失败。
- 目前默认按 GitLab 的 Compare 地址格式拼接链接。

## git-merge

### 作用

`git-merge` 用于基于远端基线分支创建或重建一个本地目标分支，并把另一个远端分支的最新内容合并进来。传 2 个参数时，会按最新 `origin/a` 重建本地 `a`，再把最新 `origin/b` 合并到本地 `a`。

### 原理描述

这个脚本的核心原理是把远端分支当成可信输入源，而不是依赖当前本地分支状态。它会先同步远端引用，再以最新 `origin/a` 作为基线创建或重建本地目标分支，最后把指定来源远端分支合并进目标分支。这样可以避免“当前本地分支不干净、落后，或者已经偏离远端”导致的基线不一致问题。

### 用法

```bash
./git-merge <远端基线分支a> <远端来源分支b>
./git-merge <远端基线分支a> <本地目标分支b> <远端来源分支c>
./gt merge <远端基线分支a> <远端来源分支b>
./gt merge <远端基线分支a> <本地目标分支b> <远端来源分支c>
```

### 示例

```bash
./git-merge local release
./git-merge local feature/test release
./gt merge local release
./gt merge local feature/test release
```

第一条命令表示本地 `local` 会先按最新 `origin/local` 创建或重建，再把最新 `origin/release` 合并进来。  
第二条命令表示本地 `feature/test` 会先按最新 `origin/local` 创建或重建，再把最新 `origin/release` 合并进来。

### 执行流程

1. 校验参数是否完整，只允许 2 个或 3 个业务参数。
2. 如果传 2 个参数，则本地目标分支使用远端基线分支 `a`；如果传 3 个参数，则本地目标分支使用第二个参数 `b`。
3. 传 3 个参数时，校验本地目标分支名 `b` 不与远端基线分支 `a`、远端来源分支 `c` 同名。
4. 校验当前目录是否为 Git 仓库。
5. 校验已跟踪文件没有未提交改动。
6. 执行 `git fetch --all --prune`，同步远端引用。
7. 校验远端基线分支和远端来源分支都存在；如果来源远端分支不存在，脚本会直接失败。
8. 传 3 个参数时，校验远端目标分支不存在；如果 `origin/b` 已存在，脚本会直接失败。
9. 执行 `git checkout --detach origin/a`。
10. 执行 `git checkout -B <本地目标分支>`，基于最新 `origin/a` 创建或重建本地目标分支；如果本地目标分支已存在，会被重建。
11. 执行 `git merge --no-edit <远端来源分支>`，把远端来源分支合并到本地目标分支。

### 当前分支影响

当前本地分支是否为远端基线分支，不影响最终结果。脚本不会先依赖同名本地分支，而是直接以远端最新基线分支为准创建或重建本地目标分支。

如果当前分支正好是远端基线分支对应的本地分支，脚本仍然会执行 `git checkout --detach origin/a`，再创建或重建目标分支；本地同名分支不会被删除，本地未 push 的提交也不会自动进入目标分支。

### 注意事项

- 参数不能为空。
- 本地已跟踪文件有未提交改动时，脚本会直接失败。
- 如果远端基线分支或远端来源分支不存在，脚本会直接失败。
- 传 3 个参数时，如果远端目标分支已存在，脚本会直接失败。
- 如果本地目标分支已存在，脚本会按最新远端基线分支重建它。
- 合并 `origin/c` 时如果出现冲突，脚本会停止，需要手工解决冲突。
- 创建后的本地 `b` 不跟踪 `origin/a`；如果后续需要建立 `origin/b` 跟踪关系，需要在合适时机手工执行 `git push -u origin b`。

## git-auto-merge

### 作用

`git-auto-merge` 用于通过 GitLab API 创建源分支到目标分支的 Merge Request，等待 GitLab 计算合并状态，确认无代码冲突后调用 API 自动合并。

### 用法

```bash
./git-auto-merge <源分支> <目标分支>
./gt gam <源分支> <目标分支>
```

### 示例

```bash
./git-auto-merge feature/order-refactor release
./gt gam feature/order-refactor release
```

两条命令都表示创建源分支 `feature/order-refactor` 指向目标分支 `release` 的 MR，检测冲突后自动合并。

### 注意事项

- 需要真实脚本目录存在 `git_config.json`，并配置有效的 `gl_host`、`gl_token` 和 `project_id_mapping`；如果通过 `~/tools` 下的链接执行，会自动回到链接指向的脚本目录读取配置。
- 源分支和目标分支必须都存在于 GitLab 项目中，且二者不能相同。
- 如果已存在同源同目标的打开状态 MR，脚本会直接失败并输出已有 MR 信息。
- 如果源分支相对目标分支没有提交或文件差异，脚本会直接失败。
- 该脚本会创建 MR，并在 GitLab 判定可合并时自动执行合并，属于有远端副作用的操作。
