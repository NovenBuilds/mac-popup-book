# 远程迭代记录

起点：远端分支 `grok/five-page-baseline`，提交 `e6ff53060517c9591e08514f3357cfde595c5f5d`，版本 0.2.1（构建 4）。该提交上现有工程检查工作流已通过，见 [运行 43348826144](https://github.com/NovenBuilds/mac-popup-book/actions/runs/43348826144)。那次运行只做了格式、测试、单页检查和正式构建，没有运行 `verify-candidate.sh`，也没有上传日志、构建凭据和可下载应用。

工作分支：`grok/iteration`。本机工作区不作为执行环境。

## 第一批

目标：让每个候选提交都有对应的自动验收日志、构建凭据和可下载应用。

- 在现有 `独立场景工程检查` 工作流中，用 `candidate` 作业替换原先只执行 `bash scripts/build.sh` 的作业。
- `candidate` 在公共检查和各页检查通过后，运行 `bash scripts/verify-candidate.sh`，再由 `scripts/package-ci-artifacts.sh` 整理产物并上传。
- 该应用仍是本地临时签名，不能当作公证试用包。

## 卡点

- 真实开合、试听、合盖唤醒和前台 30 分钟性能需要本机人工操作，保持待验收。条件允许时再出具集中验收单。
- 签名、公证、异机安装和五人试玩缺少 Apple 开发者证书、第二台设备和指定试用人员，保持范围外或待验收。

## 本批 Actions 结果

待推送后回填提交号、运行链接、应用包名称和校验值。
