# 前台性能采样工具

- `tool`: `specs/001-external-trial-delivery/tools/sample-performance.py`
- `self_test`: 已可在本机运行。自检不打开应用，也不读取存档。
- `session`: 已提供正式 30 分钟采样入口。性能结论仍为待验收，须等你在独立测试账户中跑完一次未被打断的会话。

本工具不启动《开合之间》，也不新增帧率、内存或功耗合格线。原始 JSON、摘要和打点文件留在本机证据目录，不要提交。

US1 五页开合、试听和本项 30 分钟前台会话使用同一份 `a74fd9c` 应用包，见 `manual-acceptance-checklist.md`。本文件和采样脚本的更新只改计时与计数口径，不要改用后来文档或工具提交所生成的新压缩包。请先拉取当前 `grok/iteration`，再用这里的脚本和起止点。

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

## 计时方法

首次翻页耗时和前台画面更新耗时须在同一次未打断的 US2 会话里采集。规格没有合格线；按下面的起止点记下来即可。不要用离屏管线帧率或 `BookIntegrationCheck` 的消费速率代替前台画面更新。

推荐在会话进行时另开终端打点，`--output` 必须与上面的会话命令相同：

```sh
python3 specs/001-external-trial-delivery/tools/sample-performance.py \
  --mark-prompt \
  --output build/candidate-checks/manual/performance-session.json
```

在打点窗口：按 `F` 记录首次翻页的起点，再按一次 `F` 记录终点；按 `U` 记录一次前台画面更新的起点，再按一次 `U` 记录终点，做满 5 次；按 `C` 取消尚未结束的起点；按 `Q` 结束打点，不影响 30 分钟采样。也可一次写入一个点：

```sh
python3 specs/001-external-trial-delivery/tools/sample-performance.py \
  --mark first-page-turn-start \
  --output build/candidate-checks/manual/performance-session.json
```

其余点为 `--mark first-page-turn-end`、`--mark foreground-update-start`、`--mark foreground-update-end`。会话窗口若在前台，也可输入 `F` 或 `U` 后回车打点。也可用秒表按同一口径记录，再把秒数写进 `performance-session.md`。打点须在会话结束前完成，工具会把结果写进 JSON 的 `timing` 字段和摘要。

### 首次翻页

目录顺序是林间小屋、口袋小镇、窗边小屋、海底剧场、机械天文馆。窗口顶部控制条左侧是当前页名。若该账户刚做过 US1，重新打开后会恢复为上次所在页；否则打开目录第一页「林间小屋」。启动后若短暂显示「开合之间」，要等到页名变成五页之一，并且「上一页」「下一页」可点，这一页才算开场页就绪。这还不是计时起点。

准备：计时前把书打开到半开或全开。底部「展开」百分比至少到 20%，推荐 50% 或更高。低于约 12% 时翻页动画会停住。若开着「跟随屏幕」，铰链也须保持半开或全开。合盖会让整段 30 分钟会话作废，翻页时不要合盖。

- 起点：开场页已就绪后，按下底部控制条「下一页」的瞬间。若开场页已是最后一页「机械天文馆」，改按「上一页」。起点是按下按钮的那一刻，不是应用启动，也不是纸面开始翻动的那一刻。
- 终点：目标页纸面已重新摊平（不再处于翻页旋转中），顶部页名已换成目标页名称，底部说明已换成该页内容，「上一页」「下一页」以及该页核心操作按钮重新可点，且没有出现「此页暂不可用」。

菜单「目录」中的「下一页」或「上一页」、画布焦点下的右或左方向键、触控板左右轻扫，或打开「目录」后点击目标页名，起点同样是发出该操作的瞬间。复测时推荐固定用底部控制条，并在记录中写明开场页和目标页名称。

若出现「此页暂不可用」，或画面回到开场页，这次计时作废，须把书恢复到可操作后再打一组起止点。

### 前台画面更新

这不是离屏管线帧率。正式方法是手动展开滑块的定点拨动，共采集 5 个样本，记下全部秒数并给出中位数。

准备：控制条可见。关闭「跟随屏幕」，顶部应变为「手动预览」，「展开」滑块可拖。当前页须已完全可操作。每次计时前先把滑块拨到 50%，等到立体结构停在半开轮廓、百分比显示 50% 且不再明显移动；这段准备不计时。

- 起点：开始把「展开」滑块一次性拖向 100% 的瞬间，或点击滑块轨道靠近 100% 一端、滑块开始移动的瞬间。
- 终点：底部百分比已稳定显示 100%，并且画面中的纸艺结构已完全停在全开轮廓、不再继续展开。

两次样本之间先把滑块拨回 50% 并等到停稳，这段回程不计时。按同一方向做满 5 次。规格没有合格线。

## 输出位置和字段

默认写入：

- `build/candidate-checks/manual/performance-session.json`
- `build/candidate-checks/manual/performance-session-summary.md`
- `build/candidate-checks/manual/performance-session-marks.jsonl`（若使用打点）

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
| `save_counter` | `primary_replacement_count`、`backup_change_count`、`count_quality`。本工具走定期轮询，`count_quality` 一律为估计值 |
| `timing` | 首次翻页和前台画面更新的打点结果、全部样本和中位数 |
| `power_marks` | 开始和中间读 `pmset`；结束时再尝试一次 `powermetrics` |
| `watt_sample_available` | 是否采到瓦特数 |
| `manual_fields` | 与 `timing` 对应的耗时；若未打点则留空，可用秒表按同一口径补记 |

输出样例（短时演练，故 `session_complete` 为 `false`；正式 30 分钟会话在无作废原因时应为 `true`。下面的计时数字只是打点示例，不是验收门槛）：

```json
{
  "mode": "dry-run",
  "session_complete": false,
  "invalidation_reasons": [
    "这是短时演练，不能当作 30 分钟结果",
    "不足 30 分钟，不能当作 30 分钟结果"
  ],
  "started_at": "2026-11-13T14:04:20+08:00",
  "ended_at": "2026-11-13T14:04:24+08:00",
  "duration_scheduled_seconds": 4,
  "duration_observed_seconds": 4.0,
  "memory_trend": {
    "start_bytes": 21819392,
    "mid_bytes": 21819392,
    "end_bytes": 21819392,
    "min_bytes": 21819392,
    "max_bytes": 21819392,
    "sample_count": 3
  },
  "save_counter": null,
  "watt_sample_available": false,
  "official_app_confirmed": false,
  "manual_fields": {
    "first_page_turn_seconds": 0.31,
    "foreground_frame_update_seconds": 0.151,
    "foreground_update_samples_seconds": [0.151],
    "source": "marks"
  }
}
```

摘要文件会用中文列出同样的结论，便于回写 `performance-session.md`。

## 复跑步骤

1. 不要沿用上一次被打断或不足 30 分钟的记录。短记录不能代替 30 分钟结果。
2. 先做完 US1 后，完全退出应用，再重新启动同一个验收包（`a74fd9c`）。不要在同一轮开合、合盖或试听后面继续计时。
3. 优先登录独立 macOS 测试账户。没有该账户、也没有明确同意时，不要打开日常账户存档，也不要使用 `--account daily`。
4. 记录机型、系统版本和显示分辨率。会话中不要睡眠、合盖或改分辨率；这些情况会让本次作废。
5. 打开应用并确认是正式《开合之间》后，再运行上面的 `--session` 命令。另开终端运行 `--mark-prompt`，按本节「计时方法」记录首次翻页和 5 次前台画面更新。
6. 会话应包含静置，并打开机械天文馆以便产生主存档变化。本工具对主存档和备份都只做定期轮询，次数一律标为估计值；备份变化只作单列。
7. 等工具自己结束。中途 Ctrl-C、应用退出、睡眠、合盖或分辨率变化后，必须从第 2 步重新开始。
8. 把 JSON、摘要、打点文件、功耗原始输出留在 `build/candidate-checks/manual/`，再把结论回写 `performance-session.md`。五项数据都齐全、分辨率未变，才可将 US2 标为通过。没有瓦特读数时，只把功耗标为待验收。

## 限制

| 能力 | 工具能做什么 | 限制 |
|---|---|---|
| 内存 | 采样正式应用主进程和同包内页面进程的驻留内存，记录走势 | 须在 macOS 上对着正在运行的正式应用使用 |
| 计时 | 按本节起止点记录首次翻页和前台画面更新；可用打点或秒表 | 工具不自动识别画面，须由你在约定的可见瞬间打点 |
| 分辨率 | 用 `system_profiler` 记录起止分辨率，变化则作废 | 该命令可能较慢，约每 60 秒核对一次 |
| 天文馆保存次数 | 在已声明的测试账户中定期轮询 `state.json` 和备份 | 轮询不能逐次确认每一次成功写入，也可能漏计连续替换，因此 `count_quality` 一律为估计值。只有能逐次记录每一次成功写入时才可标为精确；本工具没有这条路径 |
| 电源 | 开始、中间、结束读取 `pmset` | 瓦特数需要超级用户运行 `powermetrics`。请在静置阶段另开终端采集，不要用 sudo 运行本脚本 |
| 睡眠 / 合盖 | 比较墙钟与单调时钟，并在能读到时检查合盖状态 | 读不到合盖状态时，仍靠时钟跳动判断睡眠 |

本机 55 帧/秒和 100 毫秒管线门槛不变，也不用于 US2。离屏帧率不是本项依据。
