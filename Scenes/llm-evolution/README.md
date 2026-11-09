# 文字如何长出能力（llm-evolution）

第六跨页首版灰盒：离线技术展览。三组固定例子 × 六座展台，切换后展示预制结果、视觉比喻或不适用说明。

- 玩法纯逻辑在 `PageBehavior`，渲染在 `PageWorker/LLMEvolutionScene.swift`。
- 不联网、不播声（`audio` 为空）。指针命中名见 `LLMEvolutionLayout.HitNames`；键盘/菜单用语义动作 `next-example` / `next-booth` / `toggle-source`，或直接 `select-example-0…2`、`select-booth-0…5`。
- 研究来源见 `LLMEvolutionExhibit` 内各展台说明；注意力连线为示意，非真实权重。

本地检查：

```bash
python3 scripts/page.py check llm-evolution
python3 scripts/page.py build llm-evolution
```
