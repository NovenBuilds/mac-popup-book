# 开合之间

一本会随 MacBook 屏幕展开的互动立体书。翻到一页，慢慢抬起屏幕，让纸景从书脊立起来。也可以用窗口里的展开滑块来玩。

## 打开书

如果你已经拿到《开合之间.app》，双击打开。首次进入可从目录选页。鼠标或触控板用来操作场景，窗口里的翻页按钮和目录用来换页。支持简体中文和英文，随系统语言切换。

项目当前从源码构建。需要搭载 Apple 芯片的 Mac、macOS 14 或更新版本、Xcode 和 Python 3。铰链角度可用时，可以在窗口里校准展开角度。角度不可用时，用手动展开滑块。声音可在窗口中关闭。

## 五个跨页

| 跨页 | 试试这个 |
| --- | --- |
| 林间小屋 | 打开小屋，轻抚纸猫，或邀请它靠近。 |
| 口袋小镇 | 拨道岔选下一圈路线，开过 90° 或点击车站发车。 |
| 窗边小屋 | 拖动时光拉条，看看房间从清晨变到夜晚。 |
| 海底剧场 | 拖动水流珠，或点选一股水流，观察鱼群转向。 |
| 机械天文馆 | 转动曲柄，在观察点停下来看看太阳、地球和月球。 |

## 从源码构建

在终端执行以下命令。构建会把应用放在项目的 `build/开合之间.app`。

```sh
git clone https://github.com/NovenBuilds/mac-popup-book.git
cd mac-popup-book
bash scripts/build.sh
bash scripts/run.sh
```

每次更新源码后先重新构建。项目使用 Xcode 随附的 Swift 工具链，已验证的开发版本为 Swift 6.4。常规构建无需三维建模软件。

## 开发场景

整书窗口、目录、铰链输入和音频管理由主程序负责。各页在 `Scenes/` 中独立维护，每页在独立进程里运行。新增页面先单独预览，正式书页及顺序由 `Book/published-pages.json` 控制。

```sh
bash scripts/check.sh
bash scripts/integration.sh
bash scripts/integration.sh --published
python3 scripts/page.py list
python3 scripts/page.py check pocket-town
python3 scripts/page.py preview pocket-town
```

单页预览使用手动角度、临时存档和静音。后台验收可检查故障隔离与渲染，加上 `--published` 可检查当前发布清单里的整书和交互。实机开合和试听通过正式应用进行。已有《林间小屋》的设置和存档沿用原路径。

远程迭代分支推送后，GitHub Actions 会运行 `bash scripts/verify-candidate.sh`，并在该次运行中提供验收日志、构建凭据和可下载的应用。该应用使用本地临时签名，不等于公证后的对外试用包。Actions 跑机会记录离屏管线数据，但不套用本机 55 帧/秒的性能门槛。

[工程契约](docs/engineering/PAGE_CONTRACT.md) · [场景开发流程](docs/engineering/SCENE_WORKFLOW.md) · [成品验收标准](docs/engineering/RELEASE_ACCEPTANCE.md)

## 项目资料

[项目知识与接管报告](docs/project-knowledge/index.md) · [规划与历史记录](docs/planning/index.md)。规划正文自 2026-11-05 起归档在本仓库，原研究目录保留大型实验与历史证据。

候选包的自动检查、外部签名及实机验收见[五页试用交接](docs/engineering/BETA_HANDOFF.md)。
