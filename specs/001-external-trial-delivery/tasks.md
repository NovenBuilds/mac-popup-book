# 远程迭代（自 `grok/five-page-baseline` / `e6ff530` 起）

工作分支：`grok/iteration`。全程在远程进行，本机执行权限保持「永不」。每完成一版，先自行核验，提交并推送，确认 GitHub Actions 通过后再继续下一批。

交接时已完成的 0.2.1（构建 4）本机候选结论仍见下文原清单：US1、US2 保持待验收；签名、公证、异机安装和五人试玩保持范围外。

## 本阶段任务

- [x] R000 将交接规格与记录纳入 `specs/001-external-trial-delivery/`，并与远端 `e6ff530`（0.2.1，构建 4）核对
- [ ] R001 在 GitHub Actions 中对每个候选提交运行 `bash scripts/verify-candidate.sh`，上传验收日志、构建凭据和可下载应用
- [ ] R002 确认该次运行的提交号与应用校验值一致，并把运行链接写入 `specs/001-external-trial-delivery/records/remote-iteration.md`
- [ ] R003 真实开合、试听和前台 30 分钟性能仍待验收；需要人工操作时出具一份集中验收单
- [ ] R004 签名、公证、异机安装和对外试用仍缺证书、设备或人员，保持范围外或待验收，不阻塞其他可远程完成的工作

---

# Tasks: 0.2.1 本机候选版

**Input**: Design documents from `/specs/001-external-trial-delivery/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: 规格没有要求新的自动测试。本清单不生成测试任务。已有的 154 项测试和离屏集成只作为基线，不在这里重做。

**Organization**: 本轮结项。交付物是 `e6ff530` 上的 0.2.1（构建 4）本机候选版。勾选且标为「范围外」的任务表示本轮关闭，不表示验收通过。标为「待验收」的任务留作日后可选的自用验证，不阻塞结项。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 可以并行（不同文件，且不依赖尚未完成的任务）
- **[Story]**: 该任务所属用户故事（US1–US6）
- 描述中写明确切文件路径

## Path Conventions

- 人工结论：`specs/001-external-trial-delivery/records/`
- 原始采样、截图和日志：`build/candidate-checks/manual/`，不提交
- 本地候选包：`build/开合之间.app`
- 固定候选修订：`e6ff53060517c9591e08514f3357cfde595c5f5d`
- 实际发出的压缩包：`build/external-beta/0.2.1-4/KaiHe-0.2.1-4-macOS.zip`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 准备记录位置，不修改应用

- [x] T001 在 `specs/001-external-trial-delivery/records/index.md` 写明证据类型、默认独立测试账户，以及原始文件放在 `build/candidate-checks/manual/` 且不提交
- [x] T002 [P] 创建本地证据目录 `build/candidate-checks/manual/`，供截图、功耗原始输出和日志使用，且不纳入提交

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 固定候选修订，并核对现有应用与构建凭据。规格工作区可以不干净

**⚠️ CRITICAL**: 没有独立测试账户且未获得日常存档同意时，前台观察保持待验收。能做的准备仍要完成，并写明缺口

- [x] T003 在 `specs/001-external-trial-delivery/records/account.md` 记录账户查找结果。找到独立测试账户时写 `account_kind=独立测试账户`。本机没有该账户时写明缺口，不打开日常存档
- [x] T004 日常账户是条件分支。使用独立测试账户，或尚未改用日常账户时，在 `specs/001-external-trial-delivery/records/account.md` 把 `daily_store_consent` 标为 `不适用`。只有用户明确同意后才改为 `日常账户` 且 `已同意`
- [x] T005 核对现有 `build/开合之间.app`、`build/build-receipt.json` 与 `build/candidate-checks/result.json` 是否同属 `e6ff530`。把核对结果写入 `specs/001-external-trial-delivery/records/local-session.md`。不因规格或记录更新而重跑 `bash scripts/verify-candidate.sh`
- [x] T006 从上述凭据抄录完整修订、`source_manifest_sha256` 和应用清单校验值到 `specs/001-external-trial-delivery/records/local-session.md`

**Checkpoint**: 本地候选包身份已核对。账户或人工配合缺失时，US1 记录缺口后停止观察

---

## Phase 3: User Story 1 - 用同一个包看真实开合 (Priority: P1) 🎯 MVP

**Goal**: 记录五页前台和物理开合。本轮状态为待验收

**Independent Test**: `specs/001-external-trial-delivery/records/local-session.md` 的结论保持待验收。本机铰链读取的抽测不代替这份记录

### Implementation for User Story 1

- [x] T007 [US1] 按 `docs/engineering/RELEASE_ACCEPTANCE.md`，把五页收合、半开、全开和核心互动写入 `specs/001-external-trial-delivery/records/local-session.md`。未能观察的页写 `待验收`
- [x] T008 [US1] 把慢开、快合、半开反向、合盖唤醒、小镇超过 90° 和真实失联 1 秒写入 `specs/001-external-trial-delivery/records/local-session.md`。合盖唤醒属于 US1。模拟失联另标 `evidence_kind` 为 `模拟`
- [x] T009 [US1] 把每页的鼠标、触控板、替代按钮、手动、静音和翻页结果写入 `specs/001-external-trial-delivery/records/local-session.md`。没有人工操作时写 `待验收`
- [x] T010 [US1] 按 `specs/001-external-trial-delivery/contracts/acceptance-record.md` 汇总 US1。已观察项目填 `通过` 或 `未通过`；缺少账户、人员、铰链、鼠标或触控板时填 `待验收` 和 `pending_reason`

**Checkpoint**: US1 保持待验收。本轮不把它补做成通过

---

## Phase 4: User Story 2 - 留下长时间的前台性能记录 (Priority: P2)

**Goal**: 日后可选的自用性能测量。本轮状态为待验收，工具自检不代替 30 分钟会话

**Independent Test**: `specs/001-external-trial-delivery/records/performance-session.md` 保持待验收。五项数据全部齐全才可在日后标为通过

### Implementation for User Story 2

- [ ] T011 [US2] **待验收** 日后从重新启动 `build/开合之间.app` 开始，在 `specs/001-external-trial-delivery/records/performance-session.md` 记录固定分辨率、首次翻页的起止点和前台画面更新耗时。本轮不执行
- [ ] T012 [US2] **待验收** 日后连续记录满 30 分钟的内存读数和静置功耗，写入 `specs/001-external-trial-delivery/records/performance-session.md`。本轮不执行
- [ ] T013 [US2] **待验收** 日后以主存档成功替换填写 `primary_replacement_count`，备份单列；只能观察文件变化时把 `count_quality` 标为 `估计值`。本轮不执行
- [ ] T014 [US2] **待验收** 日后只有五项数据全部齐全且分辨率未变，才可在 `specs/001-external-trial-delivery/records/performance-session.md` 标为通过。缺功耗时功耗单列待验收。本轮不执行

**Checkpoint**: US2 保持待验收，不阻塞本轮结项

---

## Phase 5: User Story 6 - 交付记录与最终修订一致 (Priority: P1)

**Goal**: 本机候选记录与 `e6ff530` 一致。对外打包属于范围外

**Independent Test**: `specs/001-external-trial-delivery/records/summary.md` 写明候选修订。规格改动不改变已核对的本地包身份

### Implementation for User Story 6

- [x] T015 [US6] 在 `specs/001-external-trial-delivery/records/summary.md` 汇总各故事结论，并区分本地包校验值与日后的压缩包校验值
- [x] T016 [US6] **范围外** 不在临时检出中运行 `bash scripts/verify-candidate.sh` 或 `python3 scripts/package-beta.py`。脚本保留在 `scripts/package-beta.py`

**Checkpoint**: 本机凭据保持 `e6ff530`。规格文档不进入该源码指纹

---

## Phase 6: User Story 3 - 发出可以在别人电脑上打开的试用包 (Priority: P1)

**Goal**: 范围外。不签名、不公证、不做公证包短测

**Independent Test**: `build/external-beta/0.2.1-4/` 本轮不生成。已有前置检查只作为历史记录

### Implementation for User Story 3

- [x] T017 [US3] **范围外** 不配置签名和公证。历史记录仍在 `specs/001-external-trial-delivery/records/notarized-short.md`，交付目录未生成
- [x] T018 [US3] **范围外** 不运行 `python3 scripts/package-beta.py` 产生 `build/external-beta/0.2.1-4/`
- [x] T019 [US3] **范围外** 不做公证包短测
- [x] T020 [US2] **范围外** 不因公证包短测重跑性能。日后只在源码变更影响性能时才重测

**Checkpoint**: 签名、公证和短测已移出本轮

---

## Phase 7: User Story 4 - 在另一台 Mac 上安装并恢复 (Priority: P2)

**Goal**: 范围外。不进行异机安装

**Independent Test**: `specs/001-external-trial-delivery/records/cross-machine.md` 保留准备记录，结论改为范围外，不开始安装

### Implementation for User Story 4

- [x] T021 [P] [US4] **范围外** 异机条件记录保留在 `specs/001-external-trial-delivery/records/cross-machine.md`，本轮不继续准备对外安装
- [x] T022 [US4] **范围外** 不在第二台 Mac 上安装或恢复

**Checkpoint**: 异机安装已移出本轮

---

## Phase 8: User Story 5 - 五位新用户完成首次试玩 (Priority: P2)

**Goal**: 范围外。不组织五人试玩

**Independent Test**: `specs/001-external-trial-delivery/records/playtest.md` 保留空名单，结论改为范围外，不计时

### Implementation for User Story 5

- [x] T023 [P] [US5] **范围外** 试玩空名单保留在 `specs/001-external-trial-delivery/records/playtest.md`，本轮不招募用户
- [x] T024 [US5] **范围外** 不计时、不记录误点或阻断
- [x] T025 [US5] **范围外** 不按 20 秒标准判定试玩通过或未通过

**Checkpoint**: 五人试玩已移出本轮

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: 汇总证据边界，不提交原始采样和凭据

- [x] T026 更新 `specs/001-external-trial-delivery/records/summary.md`，使每个通过项指向对应记录和 `package_sha256`
- [x] T027 [P] 对照 `specs/001-external-trial-delivery/quickstart.md` 检查固定修订、分开的 US1/US2 和待验收规则仍与记录一致
- [x] T028 确认 `specs/001-external-trial-delivery/records/` 没有截图、功耗原始输出、证书或钥匙串配置

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 可立即开始
- **Foundational (Phase 2)**: 依赖 Setup。本地阶段只核对现有应用，不要求规格工作区干净
- **User Story 1**: 依赖 Foundational。可以包含合盖唤醒
- **User Story 2**: 使用 US1 的同一个包、应用校验值和测试账户，但从重新启动应用开始，单独测满 30 分钟
- **User Story 3、4、5 与 T016、T020**: 本轮范围外，不再依赖临时干净检出或公证包
- **User Story 1 与 User Story 2**: 保持待验收，不阻塞结项
- **Polish**: 结项汇总已写入 `records/summary.md`

### User Story Dependencies

- **User Story 1 (P1)**: Foundational 之后即可开始
- **User Story 2 (P2)**: 不与 US1 混跑。包身份沿用 US1 已核对的应用校验值
- **User Story 3、4、5**: 本轮范围外。已有准备记录不构成安装或试玩通过

### Within Each User Story

- 先核对包身份，再写观察
- 账户或人工配合缺失时完成准备并列出缺口，不把未观察项目写成通过
- 只有观察为未通过时，才为该缺陷另开修正。修正形成新提交后，再固定新的候选修订
- 新候选确定后，在新的临时干净检出中重新生成验收凭据

### Parallel Opportunities

- T002 可与 T001 并行
- 范围外任务不再并行执行
- US1 与 US2 若日后自用验证，仍分开运行

---

## Parallel Example: 本轮不再并行对外任务

签名、公证、异机安装和五人试玩已移出本轮，不再启动对应任务。

---

## Implementation Strategy

### 本轮结项

1. 保留 Phase 1 和 Phase 2 对 `e6ff530` 应用与凭据的核对
2. US1 与 US2 维持待验收，作为日后可选的自用验证
3. 签名、公证、公证包短测、异机安装和五人试玩标为范围外
4. 停在 `specs/001-external-trial-delivery/records/summary.md` 供审阅

### Incremental Delivery

日后若恢复对外分发，需另开一轮，并先验证铰链在其他机型和系统升级后的设备标识与报告格式。本轮不执行该增量。

### Parallel Team Strategy

本轮没有需要并行的对外安装或试玩。

---

## Notes

- 候选源码与规格文档分开。本地阶段不因文档更新重跑 `bash scripts/verify-candidate.sh`
- 使用独立测试账户时，`daily_store_consent=不适用`
- US1 可以合盖唤醒。US2 从重新启动开始，连续测满 30 分钟
- T014 的五项数据全部齐全才标为 `通过`
- 保存计数的单位是主存档成功替换；`count_quality` 只能是 `精确` 或 `估计值`
- 不把离屏凭据写成前台或物理开合通过
- 本轮不发现新的实机缺陷，因此不修改应用代码
- 范围外勾选不代表验收通过
