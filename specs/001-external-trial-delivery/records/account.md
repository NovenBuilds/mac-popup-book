# 验收账户

- `observed_at`: 2026-11-10 20:55+08
- `account_kind`: 独立测试账户尚未提供
- `daily_store_consent`: 不适用
- `console_user`: 当前登录的是本机唯一的日常账户
- `result`: 待验收

## 查找

本机用户目录中只有当前登录账户，没有另一个可供正式前台使用的 macOS 账户。因此没有把 `account_kind` 写成已经就绪的独立测试账户。

T004 是改用日常账户的条件分支。这次没有改用日常账户，所以日常存档同意标为不适用，也没有打开 `~/Library/Application Support/local.ssr.forestbook/`。

## 还缺

- 一个独立的 macOS 测试账户，供 US1 和随后的 US2 登录。
- 若不能建立该账户，需要你明确同意后，才可以把这次验收改到日常账户。当前没有这份同意。
