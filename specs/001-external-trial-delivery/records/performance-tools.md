# 性能采样工具自检

- `observed_at`: 2026-11-10 21:20+08
- `tool`: `specs/001-external-trial-delivery/tools/sample-performance.py`
- `self_test_log`: `build/candidate-checks/manual/tool-self-test.json`
- `result`: 工具自检通过。30 分钟前台测量尚未开始，性能结论仍为待验收。

自检没有启动《开合之间》，也没有读取日常存档。原始输出留在本地证据目录，不提交。

| 能力 | 自检 | 正式会话还缺 |
|---|---|---|
| 内存 | 进程驻留内存从 13631488 字节增到 15761408 字节，`ps` 也能读到当前进程 | 独立测试账户中、重新启动应用后的连续 30 分钟读数 |
| 计时 | 50 毫秒等待实测为 0.054 秒，计时器可用 | 人在前台标记首次翻页的起点和终点，并记录画面更新间隔 |
| 分辨率 | 读到内建 Liquid Retina XDR，3456×2234 | 测量全程保持这一分辨率不变 |
| 天文馆保存次数 | 临时目录中 2 次主存档替换和 1 次备份变化，计数质量为精确 | 测试账户里真实的 `pages/mechanical-planetarium/state.json` |
| 瓦特功耗 | `powermetrics` 存在，但必须以超级用户运行。本次返回“must be invoked as the superuser”，没有瓦特数 | 你授权超级用户采样，或接受功耗单列为待验收 |

`pmset -g batt` 可以读到正在使用交流电以及电池百分比。这不是瓦特功耗，不能填入静置功耗。`pmset -g therm` 没有热警告或 CPU 功耗状态。

正式 US2 仍从重新启动 `build/开合之间.app` 开始，与 US1 分开。五项数据全部齐全才标为通过；没有瓦特读数时，只把功耗标为待验收。
