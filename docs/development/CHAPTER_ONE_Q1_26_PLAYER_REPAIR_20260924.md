# 第一章 Q1–Q26 玩家报告修复（2026-09-24）

依据 `output/chapter-one-player-audit-20260924/PLAYTHROUGH.md` 的八项玩家问题，本批只改说明、结算、行囊原画、装备状态和入口，不改战斗数值、技能顺序、存档 ID、关卡奖励或 Q27–Q30 规则。改前六份 Swift 源码及 SHA256 在 `backups/chapter-one-player-ux-20260924`。

| 报告问题 | 本批处理 | 边界 |
| --- | --- | --- |
| 胜败页约 2–9 秒自动关闭 | 取消倒计时和背景点击关闭。胜利结算完整展开后由“继续 · 前往后续”按钮关闭；失败页由“返回主界面”或“重新挑战”关闭。 | 模拟器手玩 Q1 胜利及 Q5 失败，两页均等待 12 秒未自动关闭；未以真人连续通关重新计时。 |
| Q1 重开、Q8 四层误认、Q20/Q25 目标及失败成本说不清 | Q1 明说教学重新开始且需手动编牌；Q8 区分未满四层与满四层的实际效果及按编排顺序自动出牌；Q20/Q25 战前与战中分别写出拘束解除／根结拆除、需要的窗口；Q26 写出 900 点车链供能。战前显示止痛膏和永久裂纹，失败页显示已用药不会返还。 | 不改变实际机制和损耗。 |
| 0% 遗落物仍显示已装备／就绪 | 角色页及战前标“已失效 · 完好度0%”，提供按现有价格的直接修复按钮；战前选择和角色页选择均不把失效物当成可用。战前下方原本残留的“就绪”也改成“失效0% · 修复后生效”。 | 在隔离模拟器的临时 0% 存档实际支付 80 铜币修复银扣，恢复至 100%；随后恢复测试前存档。 |
| Q24–Q27 资源与难度坡度 | 战前补给数、裂纹、0% 装备可见；0 药且商店解锁时提供 30 铜币直购。 | 报告里的 Q24/Q26 失败与 Q27 九败不足以证明数值错误；没有改血量、限持 1 药或战斗节奏。Q27 单列后续真人复核。 |
| 重复铜币、蓝色通用图、行囊“原画待补” | 结算保留一条铜币收益，过滤奖励物品列表中的重复铜币；结算与行囊共用按稳定 ID 选择的位图原画。新增项圈、名册、红线、路线、总签钥五种 512px 物证缩略图，保留已有物品原画；Q1–Q26 首通的 42 种物品 ID 均有图像映射。 | 同类证据仍可能共用一张图，并非 42 张独立插画。 |
| 辅助朗读把不同敌体叫旧犬 | Unity/SpriteKit 战场展示层从辅助树隐藏；原生目标按钮继续根据当前敌人身份和 HP 朗读。 | 模拟器逐场读到 Q5“翠焰亡灵”、Q6“档案守卫”、塔 F1“盾颚魔”；也复查 Q27 双敌，无重复旧犬名称。 |
| “前15关”／“隐者”／声望 130/100／补给和邮务埋得深 | 文案改第一章 30 关、愚者、累计声望与 100 晋阶门槛；角色总览新增诊所补给与城市邮务入口，战前可直接买药。 | 没有解锁原本锁住的主城商店。 |
| Q26 900 供给未计入伤害 | 胜利统计改标“对敌伤害”，Q26 战前台词写明只统计锤卫本体。 | 不把机关 900 当敌人伤害，也不改伤害累计逻辑。 |

## 检查与保留证据

- `swift test --package-path mistport-ios/MistportCombatCore --filter ChapterOneThirtyMissionContractTests`：5 项通过；`--filter ChurchOwnedRelicLedgerTests`：4 项通过，覆盖 0% 不可用、修复与存档原子性。日志在 `output/chapter-one-q1-26-repair-20260924`。
- 当前源码的 `ChapterThirtyBalanceTests` 法定配装扫描通过；Q24、Q25、Q26 各有 35、36、33 组预设组合获胜（`q24-26-balance-current.log`）。这是给定天赋、每关一剂药、预设施放时机的确定性模拟，不覆盖连续资源损耗、真人反应与阅读负担，所以没有据此降低敌人血量或放宽药品限持。
- Unity 模拟器导出成功；iPhone 模拟器和 iOS 设备目标的**不签名** Xcode 构建均成功。最后一处状态文字修正后的构建日志为 `xcodebuild-simulator-status-fix-final.log`、`xcodebuild-device-status-fix-final.log`。尝试签名 Build 67 后又用 `-allowProvisioningUpdates` 重试，Xcode 明确报 `No Accounts: Add a new account in Accounts settings`，并且当前钥匙串缺少团队 `DTHU5527HL` 的 `iOS Development` 私钥身份；`security find-identity` 返回 0 个有效 Apple 开发身份。手机仍为 `0.1.0 (66)`，本批**未安装到真机**。签名失败日志为 `xcodebuild-device-signed.log`、`xcodebuild-device-signed-retry.log`。
- 在独立 iPhone 16 模拟器实际查看了城市、角色总览、遗落物、行囊、物证详情及 Q27 战前提示；行囊实有 46 种物品，当前没有“原画待补”；Q27 当前目标辅助树没有重复旧犬名称。模拟器偏好文件测试前后 SHA256 一致，原进度已恢复。
- 续测在同一隔离模拟器手动完成 Q1 教学及结算，胜利页等 12 秒仍保留、点继续才退出；Q5 未编卡试打失败后，失败页等 12 秒仍保留、点返回才退出。失败停留画面见 `output/chapter-one-q1-26-repair-20260924/q05-defeat-hold.png`。
- 将隔离模拟器测试存档临时设为银扣 0%、止痛膏 0，角色页与战前均显示失效，战前直接修复银扣花 80 铜币、买药花 30 铜币，序列化结果为银扣 100%、药 1、铜币 788→678。发现战前遗落物状态行仍称“就绪”后补上 0% 优先判定，重新导出/构建/安装模拟器包，辅助树现读“失效0% · 修复后生效”。复查截图为 `output/chapter-one-q1-26-repair-20260924/q27-prebattle-depleted-final.png`；Q27 仅借战前共用 UI 测试，未打 Q27。测试后关机恢复两份原偏好文件，SHA256 分别为 `92efec298bcc8a16c1970552e442c182c4a9c0fccfd3b36f2cb8b70357175153`、`45f1ede9d2eed3c4de9b778ace9834cd8b5a8439f8961d995f8cadb0fbd6b9dc`，与测试前逐字节相同。
- 为验证最后一处文字修正，重新导出模拟器 Unity 库并构建成功（`unity-simulator-status-fix.log`、`xcodebuild-simulator-status-fix-final.log`）；正式项目 `mistport-ios/UnityBuild` 随后恢复为设备导出，模拟器导出暂存在 `/tmp/mistport-simulator-export-q1-26-cont`。
- 尝试签名前备份 iPhone 应用的 8 个偏好文件；尝试后再次拷出并逐文件 `diff` 一致。备份在 `backups/chapter-one-player-ux-20260924/device-{before,after-attempt}`，设备应用列表仍为 `0.1.0 (66)`。
- 新物证图用内置 imagegen 生成，选定图已存进 `mistport-ios/Mistport/Assets.xcassets/ItemEvidence{Collar,Registry,Thread,Route,Key}.imageset`。统一提示词方向：`Square painterly fantasy inventory icon, dark plum-black background, aged parchment and worn brass, one legible central object, rich material detail, no readable text or UI frame.` 五个主体分别为带号狗项圈拓印、缺页失踪名册、暗红线轴、海岸押运路线图、档案总签铜钥。项目实际使用的 512px 图已落盘，不依赖 Codex 临时目录。

仍需真人确认 Q24–Q26 的资源坡度与真机胜败页操作；这些检查不能由模拟器交互和构建通过替代。
