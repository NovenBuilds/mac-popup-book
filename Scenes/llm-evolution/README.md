# 字间工坊（llm-evolution）

展开到接近全开，纸艺印机自动巡演约 30 秒，依次演示两种续写、按要求改写和图文判断。合盖暂停时钟，重新展开从当前幕继续。巡演结束后，四张成品停在展台上。

- 可暂停、继续、重播和前后切幕。点击纸页上的说明卡或下方「说明与来源」打开说明。
- 展品是离线预制示例。关键词连线为示意，研究出处见说明卡。
- 巡演逻辑在 `PageBehavior`，纸艺舞台在 `PageWorker/LLMEvolutionScene.swift`。

本地检查：

```bash
python3 scripts/page.py check llm-evolution
python3 scripts/page.py build llm-evolution
```
