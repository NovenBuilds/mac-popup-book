# Quickstart: 0.2.1 本机候选版

本文说明本轮已经结项的本机候选版。它不修改应用，也不对外打包。

## 本轮交付

候选修订：

```sh
git rev-parse e6ff53060517c9591e08514f3357cfde595c5f5d
```

本机应用是 `build/开合之间.app`，版本 0.2.1（构建 4）。构建凭据是 `build/build-receipt.json`，离屏验收凭据是 `build/candidate-checks/result.json`。该凭据的检查为工程检查、后台隔离和五页集成，共 154 项测试、0 失败。这只证明离屏自动检查。

本机铰链读取曾通过抽测。物理开合、前台体验和 30 分钟性能仍是待验收，留作日后可选的自用验证。

## 本轮不做

签名、公证、公证包短测、异机安装和五人试玩是范围外。这轮不开通 Apple 开发者付费会员。`python3 scripts/package-beta.py` 保留，但不运行。`build/external-beta/0.2.1-4` 不生成。

暂缓对外分发，是因为铰链读取依赖特定设备标识和报告格式，跨机型和系统升级后的兼容性尚未验证。

## 日后的自用验证

若要补做前台或性能，登录独立 macOS 测试账户，使用验收单指向的同一个候选包。US1 与 US2 分开运行。US1 可以合盖唤醒。US2 从重新启动应用开始，连续测满 30 分钟。在仓库根目录运行：

```sh
python3 specs/001-external-trial-delivery/tools/sample-performance.py \
  --session --account independent \
  --output build/candidate-checks/manual/performance-session.json
```

启动命令、输出样例和复跑步骤见 `specs/001-external-trial-delivery/records/performance-tools.md`。没有超级用户授权时，瓦特功耗单列为待验收。未获得明确同意时，不使用日常存档。

预期结果：观察完成前，这两项保持待验收。范围外事项不因补做自用验证而改为通过。
