# Git 提交作者信息批量修改记录

## 背景

仓库中所有历史提交的作者信息需要从原账号统一替换为新账号。

| 字段   | 旧值                       | 新值                    |
| ------ | -------------------------- | ----------------------- |
| author | `zhangsan`              | `wangwu`                |
| email  | `zhangsan@qq.com`  | `wangwu@lookout.com`  |

## 前置检查

执行重写前先确认以下信息，避免误伤其他作者或破坏远程协作。

### 1. 查看历史中所有唯一作者

```bash
git log --all --pretty=format:"%H %an <%ae>" | awk '{print $2,$3}' | sort -u
```

输出（确认仅有一个旧作者）：

```
zhangsan <zhangsan@qq.com>
```

### 2. 确认远程与分支状态

```bash
git remote -v
git branch -a
```

结果：无远程仓库，仅本地 `master` 分支 → 重写历史安全，无需 force push 协调。

### 3. 检查可用的重写工具

```bash
which git-filter-repo
```

未安装 `git-filter-repo`，回退使用内置的 `git filter-branch`。

> 提示：生产环境推荐 `git filter-repo`（更快、更安全），可通过 `brew install git-filter-repo` 安装。

## 处理工作区未提交变更

`filter-branch` 要求工作区干净，否则报错 `Cannot rewrite branches: You have unstaged changes.`。

```bash
git stash push -u -m "temp stash for author rewrite"
```

`-u` 用于同时暂存未追踪文件。

## 重写所有提交的作者与提交者

使用 `--env-filter` 同时改写 author 与 committer 字段，覆盖所有分支与标签。

```bash
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --env-filter '
OLD_NAME="zhangsan"
OLD_EMAIL="zhangsan@qq.com"
NEW_NAME="wangwu"
NEW_EMAIL="wangwu@lookout.com"

if [ "$GIT_COMMITTER_NAME" = "$OLD_NAME" ] || [ "$GIT_COMMITTER_EMAIL" = "$OLD_EMAIL" ]; then
    export GIT_COMMITTER_NAME="$NEW_NAME"
    export GIT_COMMITTER_EMAIL="$NEW_EMAIL"
fi
if [ "$GIT_AUTHOR_NAME" = "$OLD_NAME" ] || [ "$GIT_AUTHOR_EMAIL" = "$OLD_EMAIL" ]; then
    export GIT_AUTHOR_NAME="$NEW_NAME"
    export GIT_AUTHOR_EMAIL="$NEW_EMAIL"
fi
' --tag-name-filter cat -- --branches --tags
```

要点说明：

- `FILTER_BRANCH_SQUELCH_WARNING=1`：抑制 filter-branch 的过时警告。
- `-f`：覆盖已有 `refs/original/` 备份（重复执行时需要）。
- 同时改写 `GIT_AUTHOR_*` 与 `GIT_COMMITTER_*`，否则 `git log` 看 author 变了，但 `git log --format='%cn %ce'` 仍是旧账号。
- `-- --branches --tags`：作用于所有本地分支与标签，避免遗漏。

## 验证重写结果

```bash
git log --all --pretty=format:"%H %an <%ae>" | sort -u -k2
git for-each-ref
```

此时会看到三类 ref：

| Ref                                   | 含义                          |
| ------------------------------------- | ----------------------------- |
| `refs/heads/master`                   | 已重写为新作者 ✓              |
| `refs/original/refs/heads/master`     | filter-branch 自动生成的备份  |
| `refs/stash`                          | 之前 `git stash` 留下的引用   |

> 注意：`refs/stash` 的作者来自当前 `git config user.*`，与历史重写无关，不必处理。

## 恢复工作区变更

```bash
git stash pop
```

## 清理 filter-branch 备份（不可逆）

确认无误后，删除备份 ref 并执行 gc，使仓库干净化。

> ⚠️ 这一步不可逆。执行后无法回退到原始 commit hash。如对结果有任何疑虑，请先 `git clone` 一份做备份。

```bash
git update-ref -d refs/original/refs/heads/master
git reflog expire --expire=now --all
git gc --prune=now
```

## 最终校验

```bash
git log --all --pretty=format:"%H %an <%ae>" | awk '{print $2,$3}' | sort -u
git log --oneline -5
```

输出仅包含新作者，整次操作完成：

```
wangwu <wangwu@lookout.com>
```

## 注意事项

1. **所有 commit hash 都会变化**。重写后历史是新对象，依赖旧 hash 的引用（PR、issue 链接、tag）需同步更新。
2. **存在远程仓库时**：需要 `git push --force-with-lease`，并提前通知所有协作者重新 clone 或 rebase 本地分支，否则会污染上游。
3. **GPG 签名会失效**：原签名基于旧的提交对象，重写后需要重新签名。
4. **优先使用 `git filter-repo`**：相同任务命令更简洁，例如：
   ```bash
   git filter-repo --mailmap mailmap.txt
   ```
   配合 `mailmap.txt`：
   ```
   wangwu <wangwu@lookout.com> zhangsan <zhangsan@qq.com>
   ```
5. **配置 `git config`**：未来新提交直接使用正确身份，避免再次重写：
   ```bash
   git config user.name "wangwu"
   git config user.email "wangwu@lookout.com"
   ```
