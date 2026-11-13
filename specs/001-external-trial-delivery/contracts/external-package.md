# Contract: 对外试用包

2026-11-10 结项：本契约属于本轮范围外。`scripts/package-beta.py` 保留，本轮不执行，也不生成 `build/external-beta/0.2.1-4`。

## 前置

- 当前提交没有未提交改动。
- `POPUP_BOOK_SIGNING_IDENTITY` 和 `POPUP_BOOK_NOTARY_PROFILE` 都已在本机配置。
- `build/candidate-checks/result.json` 的修订、工作区状态和源码指纹与当前提交一致，且检查为工程检查、后台隔离和五页集成。
- 输出目录 `build/external-beta/0.2.1-4` 尚不存在。

本轮不运行本节。日后若恢复对外打包，任一前置不满足时命令失败且目录不出现；公证或来源检查失败时结论为未通过。

## 成功时的目录

- `KaiHe-0.2.1-4-macOS.zip`
- `KaiHe-0.2.1-4-macOS.zip.sha256`
- `build-receipt.json`：源码修订和源码指纹与自动验收凭据相同。
- `verification.json`：当次自动验收凭据的副本。
- `试用说明.md`：说明适用 Apple 芯片和 macOS 14 或更新版本，以及手动开合和试玩记录方式。

压缩包内的主应用和内嵌页面服务使用开发者身份签名，启用运行时保护与安全时间戳。公证结果为接受，附票和严格签名校验通过，系统按可执行文件完成来源检查。

## 不包含

证书、钥匙串配置、公证账号、截图、日志和本机日常存档。
