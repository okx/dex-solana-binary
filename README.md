# swap-pallas-release CI

本分支 (main) 仅用于存放 GitLab CI 配置，负责自动化发布 pallas 二进制到 GitHub Release。

## 分支说明

| 分支 | 用途 |
|------|------|
| main | CI 配置（本分支） |
| master | 文档，同步到 GitHub |
| release | 存储编译好的二进制文件 |

## 发布流程

1. 在其他服务器编译 pallas 二进制文件（3 个平台）
2. 通过 MR 将二进制文件和 README.md 提交到 release 分支
3. 在 main 分支打 tag 触发发布：
   ```bash
   git checkout main
   git tag v1.0.0
   git push origin v1.0.0
   ```
4. GitLab CI 自动执行：安全扫描 -> 从 release 分支拉取文件 -> zip 压缩 -> 发布到 GitHub Release

## 发布产物

发布到 GitHub `okx/dex-solana-binary`，包含：
- pallas-darwin-aarch64.zip
- pallas-darwin-x86_64.zip
- pallas-linux-x86_64.zip

## 异常处理

- tag 打错：删除 GitLab tag，删除 GitHub Release，重新打 tag
- GitHub 已有同名 Release：CI 报错退出，不覆盖
- 二进制文件缺失/多余：CI 报错退出
- 上传中途失败：GitHub 上留的是 draft Release，不会公开展示

## 注意事项

- GitHub Token 过期时间：2027/05/14，届时需要更新 GitLab CI Variable `GITHUB_TOKEN`
- 只有 Maintainers 可以创建 `v*` tag
