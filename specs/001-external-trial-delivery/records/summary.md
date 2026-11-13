# 验收汇总

本轮结项。交付物是 0.2.1（构建 4）本机候选版。

- `git_revision`: `e6ff53060517c9591e08514f3357cfde595c5f5d`
- `source_manifest_sha256`: `fbe58a5397f1adcb471f5e0cb5ece71310f9951ba2308aab6ede8db3666d7a58`
- `package_sha256`: `38c5b6a5e1ad1473a723adbf43db92b078fd41f017bc02d3c83f95ad2b605bbe`
- 对外压缩包：未产生，本轮范围外

| 项目 | 本轮结论 | 记录 |
|---|---|---|
| 现有应用与构建凭据 | 保留。91 个应用文件与凭据一致 | `build/开合之间.app`、`build/build-receipt.json` |
| 154 项测试、后台隔离、五页集成 | 保留。离屏结果不写成前台通过 | `build/candidate-checks/result.json` |
| 本机铰链读取 | 曾通过抽测。不代替物理开合 | 结项时由维护者确认 |
| 前台体验与物理开合 | 待验收。日后可选的自用验证 | `local-session.md` |
| 30 分钟性能 | 待验收。工具已自检，会话未开始 | `performance-session.md`、`performance-tools.md` |
| 签名 | 范围外 | `notarized-short.md` 只保留当时的前置检查 |
| 公证 | 范围外 | 同上。未开通付费开发者会员 |
| 公证包短测 | 范围外 | 同上。交付目录未生成 |
| 异机安装 | 范围外 | `cross-machine.md` 只保留当时的条件草稿 |
| 五人试玩 | 范围外 | `playtest.md` 只保留空名单 |

规格、任务勾选和这些记录不改变 `e6ff530` 的源码指纹。应用代码、铰链与手动滑块、打包脚本和上述证据都保留。
