# 前台性能采样工具

- `tool`: `specs/001-external-trial-delivery/tools/sample-performance.py`
- `self_test`: 已可在本机运行。自检不打开应用，也不读取存档。
- `session`: 已提供正式 30 分钟采样入口。性能结论仍为待验收，须等你在独立测试账户中跑完一次未被打断的会话。

本工具不启动《开合之间》，也不新增帧率、内存或功耗合格线。首次翻页耗时和前台画面更新耗时仍须人工计时，写回 `performance-session.md`。原始 JSON 和摘要留在本机证据目录，不要提交。

## 启动命令

先完全退出应用，再重新打开验收单里的同一个《开合之间》包。不要用场景预览，也不要接在 US1 开合同一轮后面计时。应用标识须为 `local.ssr.forestbook`，界面语言简体中文（zh-Hans-CN）。远程 CI 的临时签名包不是公证试用包；核对 SHA-256 后可用右键打开。

在仓库根目录执行：

```sh
python3 specs/001-external-trial-delivery/tools/sample-performance.py \
  --session --account independent \
  --output build/candidate-checks/manual/performance-session.json
```

工具会等待最多 60 秒，直到看到正式应用。默认采满 1800 秒，每 15 秒记录一次内存，并监视当前测试账户下的天文馆主存档。

自检：

```sh
python3 specs/001-external-trial-delivery/tools/sample-performance.py --self-test \
  --output build/candidate-checks/manual/tool-self-test.json
```

短时演练（不能当作 30 分钟结果）：

```sh
python3 specs/001-external-trial-delivery/tools/sample-performance.py --dry-run \
  --output build/candidate-checks/manual/performance-dry-run.json
```

不要用 `sudo` 运行本脚本，以免看错主目录。没有独立测试账户、也没有明确同意时，不要加 `--account daily --consent-daily-store`，也不要打开日常账户里的 `~/Library/Application Support/local.ssr.forestbook/` 存档。

## 输出位置和字段

默认写入：

- `build/candidate-checks/manual/performance-session.json`
- `build/candidate-checks/manual/performance-session-summary.md`

关键字段：

| 字段 | 含义 |
|---|---|
| `started_at` / `ended_at` | 本地时区的起止时间 |
| `duration_scheduled_seconds` / `duration_observed_seconds` | 计划时长与实际时长 |
| `session_complete` | 只有满 30 分钟、确认正式应用、且没有作废原因时为 `true` |
| `invalidation_reasons` | 睡眠、合盖、分辨率变化、应用退出、中断或时长不足等原因 |
| `official_app_confirmed` / `bundle_id` / `app_bundle` | 是否采到正式包 `local.ssr.forestbook` |
| `machine` | 机型、系统版本、系统语言（若可读） |
| `display_start` / `display_end` | 起止分辨率 |
| `samples` | 中间读数：时间、内存、可选存档计数 |
| `memory_trend` | 起始、中间、结束、最低、最高内存（字节） |
| `save_counter` | `primary_replacement_count`、`backup_change_count`、`count_quality` |
| `power_marks` | 开始和中间读 `pmset`；结束时再尝试一次 `powermetrics` |
| `watt_sample_available` | 是否采到瓦特数 |
| `manual_fields` | 首次翻页、前台画面更新的占位，须人工补记 |

输出样例（短时演练，故 `session_complete` 为 `false`；正式 30 分钟会话在无作废原因时应为 `true`）：

```json
{
  "mode": "dry-run",
  "session_complete": false,
  "invalidation_reasons": [
    "这是短时演练，不能当作 30 分钟结果",
    "不足 30 分钟，不能当作 30 分钟结果"
  ],
  "started_at": "2026-11-13T12:26:28+08:00",
  "ended_at": "2026-11-13T12:26:34+08:00",
  "duration_scheduled_seconds": 6,
  "duration_observed_seconds": 6.0,
  "memory_trend": {
    "start_bytes": 20721664,
    "mid_bytes": 20721664,
    "end_bytes": 20721664,
    "min_bytes": 20721664,
    "max_bytes": 20721664,
    "sample_count": 4
  },
  "save_counter": null,
  "watt_sample_available": false,
  "official_app_confirmed": false
}
```

摘要文件会用中文列出同样的结论，便于回写 `performance-session.md`。

## 复跑步骤

1. 不要沿用上一次被打断或不足 30 分钟的记录。短记录不能代替 30 分钟结果。
2. 先做完 US1 后，完全退出应用，再重新启动同一个验收包。不要在同一轮开合、合盖或试听后面继续计时。
3. 优先登录独立 macOS 测试账户。没有该账户、也没有明确同意时，不要打开日常账户存档，也不要使用 `--account daily`。
4. 记录机型、系统版本和显示分辨率。会话中不要睡眠、合盖或改分辨率；这些情况会让本次作废。
5. 打开应用并确认是正式《开合之间》后，再运行上面的 `--session` 命令。需要人工计时的两项，在同一次前台会话里另行记录起点和终点。
6. 会话应包含静置，并打开机械天文馆以便产生主存档替换。备份变化只作单列。
7. 等工具自己结束。中途 Ctrl-C、应用退出、睡眠、合盖或分辨率变化后，必须从第 2 步重新开始。
8. 把 JSON、摘要、功耗原始输出留在 `build/candidate-checks/manual/`，再把结论回写 `performance-session.md`。五项数据都齐全、分辨率未变，才可将 US2 标为通过。没有瓦特读数时，只把功耗标为待验收。

## 限制

| 能力 | 工具能做什么 | 限制 |
|---|---|---|
| 内存 | 采样正式应用主进程和同包内页面进程的驻留内存，记录走势 | 须在 macOS 上对着正在运行的正式应用使用 |
| 计时 | 记录会话起止和中间采样时间 | 首次翻页、前台画面更新仍须人工计时 |
| 分辨率 | 用 `system_profiler` 记录起止分辨率，变化则作废 | 该命令可能较慢，约每 60 秒核对一次 |
| 天文馆保存次数 | 在已声明的测试账户中监视 `state.json` 成功替换；备份单列 | 只能看到文件变化而无法确认替换时，`count_quality` 为估计值 |
| 电源 | 开始、中间、结束读取 `pmset` | 瓦特数需要超级用户运行 `powermetrics`。请在静置阶段另开终端采集，不要用 sudo 运行本脚本 |
| 睡眠 / 合盖 | 比较墙钟与单调时钟，并在能读到时检查合盖状态 | 读不到合盖状态时，仍靠时钟跳动判断睡眠 |

本机 55 帧/秒和 100 毫秒管线门槛不变，也不用于 US2。离屏帧率不是本项依据。
