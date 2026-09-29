# 每日玩法任务 1.1：重复工作递减接入 App · 2026-09-29

当前交付 **Build 163**。Build 162 为中间验证，Build 163 补齐了塔战直接开战的按天检查。

## 实现

- 邮务 J0、巡检 J1、塔内维护 J2（含批量补领）与主线重玩调用同一个 `MPCDailyWorkLedger.settle`，日期统一使用 `pacingDay`。首通奖励不递减。
- 新存档键 `mistport.daily-work.v1` 保存账本及 `migratedAt` 回执。旧档首次读入为空账本，后续读入不重复迁移；重开清零。已有工作、钱款、一次性奖励不回填。
- 邮务、主线和教会的写前结算回执均携带账本快照；恢复时重放绝对钱款与计数，重复回调不发第二次奖励。
- 接单前显示实际铜币/功勋，以及第 4 单半价、第 7 单一成、功勋已记满提示。维护胜利页显示本单实际结算。任务板显示实际重玩铜币及锁定原因。
- 复查任务 0 时补齐 `beginChurchTower` 的直接开战检查：既检查预览，也检查真正开始战斗，避免过期整备页绕过额度；领奖不加按天拦截。
- `--verify-daily-work` 在独立 suite 混做 J0/J1/J2/主线，检查 100%/50%/10%、功勋上限、重复回调、重启和写前回执恢复、次日、重开。

## 验证

- 规则库 `DailyWorkTests` 4 项通过（任务 0 已跑全量 516 项）。
- Build 162 独立工作树完整 iOS 构建成功并装机；新增自检和原五组自检通过，见 [日志](debug-checks-build162.txt)。
- [Build 162 真机截图](work-build162.png)：第 7 单，巡检 6 铜/0 功勋、维护 8 铜/0 功勋，明确提示递减与功勋上限。画面为独立测试存档，不是真实玩家进度。
- Build 162 安装前后 87 个 Preferences 文件逐字节一致。真实存档仅新增 `mistport.daily-work.v1`，所有旧键未变。两份明确命名的测试 suite 有预期变化，其他既有文件不变，见 [差异报告](preferences-build162.json)。首次启动后需等偏好写入完成再取证，3 秒抓取曾早于磁盘落盘，后续 7 秒抓取已确认迁移。
- 比对工具：`tools/daily-loop/verify_preferences.py`。必须显式指定允许新增的玩家键和允许变化的测试 suite；不能豁免真实玩家 suite。

- Build 163 构建成功，安装前后 95 个 Preferences 文件逐字节一致；六组自检通过，见 [最终日志](debug-checks-build163.txt)。[最终真机截图](work-build163.png)、[最终存档比对](preferences-build163.json)；玩家主 plist 逐字节不变。

## 工作区与证据

任务 0 之后发现其他会话正在同一工作区修改角色页，并出现 Unity 链接失败。已将本任务自己的改动移到 `/Volumes/andrew's SSD/Mistport-worktrees/daily-work`，原工作区保留对方改动；本任务不包含角色页布局与技能介绍的并行修改。

- DerivedData：`/Volumes/andrew's SSD/Mistport-build-cache/daily-work-dd`。
- Unity 导出复制到独立工作树，导出新鲜度检查通过，未修改运行资源。
- 完整构建日志、Preferences 备份：独立工作树 `output/daily-work-20260929/`。
- 签名 Build 163：`/Volumes/andrew's SSD/Mistport-archives/releases/Build163/Mistport.app`。
- 签名 Build 162：`/Volumes/andrew's SSD/Mistport-archives/releases/Build162/Mistport.app`。

用户尚未认可此界面/手感；任务 1.2–1.8、任务 2 尚未完成。自检使用受控战斗结算输入，不能充当真人完整试玩或真机计时。
