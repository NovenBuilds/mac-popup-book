# 签名公证前置检查

结项后此项为范围外。下面的文字是调整范围前的检查记录，予以保留。

- `evidence_kind`: 公证包短测
- `observed_at`: 2026-11-10 21:20+08
- `git_revision`: `e6ff53060517c9591e08514f3357cfde595c5f5d`
- `result`: 范围外
- `pending_reason`: 调整范围前确认 `POPUP_BOOK_SIGNING_IDENTITY` 和 `POPUP_BOOK_NOTARY_PROFILE` 都没有设置。没有生成交付目录，也没有做短测。本轮不再把该缺口列为待验收。

## 已执行的检查

- `python3 scripts/package-beta.py` 立即退出，提示先配置上述两个环境变量。退出码为 1。
- `build/external-beta/0.2.1-4` 不存在。
- `codesign`、`notarytool` 和 `stapler` 都在本机。`notarytool` 位于 `/Applications/Xcode.app/Contents/Developer/usr/bin/notarytool`。
- 钥匙串中有 1 个有效代码签名身份，类型是 Apple Development，团队标识为 WG557L572B。打包脚本没有使用它，因为环境变量未设置。
- 尚未确认这枚开发证书能否完成对外公证。公证配置名也没有提供。

短测的首次启动、五页、铰链、手动开合、声音、退出重启和存档恢复都还没有做。压缩包校验值留空，等临时干净检出里的打包成功后再填。
