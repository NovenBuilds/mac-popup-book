# US2 前台性能

- `evidence_kind`: 前台性能
- `observed_at`: 2026-11-10 21:20+08
- `git_revision`: `e6ff53060517c9591e08514f3357cfde595c5f5d`
- `source_manifest_sha256`: `fbe58a5397f1adcb471f5e0cb5ece71310f9951ba2308aab6ede8db3666d7a58`
- `package_sha256`: `38c5b6a5e1ad1473a723adbf43db92b078fd41f017bc02d3c83f95ad2b605bbe`
- `account_kind`: 独立测试账户尚未提供
- `daily_store_consent`: 不适用
- `display_resolution`: 3456×2234。正式测量尚未开始，因此还不能证明全程未变
- `result`: 待验收
- `pending_reason`: 采样工具已自检，30 分钟会话还没有在独立测试账户中从重新启动应用开始。

五项正式数据都还没有：

| 项目 | 状态 |
|---|---|
| 首次翻页耗时 | 待验收 |
| 前台画面更新耗时 | 待验收 |
| 连续 30 分钟内存 | 待验收 |
| 静置功耗 | 待验收。未授权超级用户时，`powermetrics` 不能给出瓦特数 |
| 天文馆主存档成功替换次数 | 待验收。备份将单列 |

工具准备见 `performance-tools.md`。这次不重跑性能，因为还没有短测差异，也没有影响性能的源码变更。

---

2026-11-13 更新：`sample-performance.py` 已提供 `--session` 正式入口，启动命令、输出样例和复跑步骤见 `performance-tools.md`。30 分钟会话仍未在独立测试账户中开始，本项保持待验收。本记录此前针对 `e6ff530` 本机包的观察结论不改为通过。
