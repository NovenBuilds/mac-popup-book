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

- 提交 `05d6df40f3b37608fa5d03dcc8c23b1af473b0a4`，运行 [43351785422](https://github.com/NovenBuilds/mac-popup-book/actions/runs/43351785422)：`common`、`discover` 和全部 `scene` 通过；`candidate` 在隔离验收失败。
- 失败原因：`后台管线性能`。离屏消费约 25.56 帧/秒，50 次注入反馈 p95 约 66.74 毫秒，传输消费 p95 约 9.97 毫秒。本机门槛是至少 55 帧/秒、p95 至多 100 毫秒。工程检查已通过，应用已构建，但因验收失败未上传可下载应用。证据包：`candidate-evidence-05d6df40f3b37608fa5d03dcc8c23b1af473b0a4`。
- 处理：本机 55 帧/秒门槛保持不变。远程跑机改为记录同样数据，仅在离屏消费低于 1 帧/秒时失败。
- 提交 `e5d7e9a5fc584fb8b735fea2feb59e4e5ccc33bf`，运行 [43353715983](https://github.com/NovenBuilds/mac-popup-book/actions/runs/43353715983)（2026-11-13 10:39–10:53，Asia/Shanghai）：`common`、`discover`、全部 `scene` 和 `candidate` 通过。工程检查 154 项测试通过；隔离与五页离屏集成的功能检查通过。
- 构建凭据与提交一致：工作区干净，源码清单 SHA-256 `80d3fc3ef65f6025571133c8b6efc45b06b04d7e2d5d908158813c4c4e3161c6`，应用清单 SHA-256 `671e0500f99237e9fd8e0ee985c230bf3635aacb5769dd7735244158292679db`，可执行文件 SHA-256 `6f838da5294b85da5fca7881f6c14c6ca0a5cf8316ca7f9e929d322e3797aa05`。
- 可下载应用：`KaiHe-0.2.1-4-e5d7e9a5fc58-macOS.zip`，SHA-256 `e78386c3a65efb3167644c6bb5b003fefd37c624f2eb4ec47bf37e9141d2d382`。[应用产物](https://github.com/NovenBuilds/mac-popup-book/actions/runs/43353715983/artifacts/14005861717)，[证据产物](https://github.com/NovenBuilds/mac-popup-book/actions/runs/43353715983/artifacts/14005493009)。本地临时签名，不是公证试用包。
- 跑机设备为 Apple Paravirtual device。隔离验收离屏消费约 26.37 帧/秒（反馈 p95 约 84.61 毫秒，传输 p95 约 5.64 毫秒）；森林约 19.95 帧/秒（传输 p95 约 20.99 毫秒）。已记录，未达本机 55 帧/秒门槛，不作为远程失败。
