# 第一章愚者完整体验验收审计

更新：2026-07-22

## 目标

测试角色开放第一章全部可用内容，并可完整体验所有调查、遭遇、物品、构筑、队友、
区域首领、结局选择与阶位8误导训练。

## 已由当前代码和自动测试证明

| 要求 | 当前实现 | 权威证据 |
| --- | --- | --- |
| 完整技能体验 | 序章从1个技能起步，调查中逐步获得10个主动技能；首领战前全部可用，含6个普通技能槽与1个固定终极技能槽 | `progressiveChapterStart`、`fullProgressionUnlocksBeforeBoss`、`ChapterOneContentTests.allFoolSkillsExist` |
| 全被动开放 | 6个被动，战前可装备2个 | `ChapterOneContentTests.requiredCounts`、构筑槽位测试 |
| 全遗器开放 | 12件遗器，战前可装备2件；雾锚耗尽可在测试台修复 | `ChapterOneContentTests.relicDesignCompleteness`、12件遗器运行时测试 |
| 全物品开放 | 11种物品按堆叠上限持有，关键物品固定1件，可一键补满 | `fullyUnlockedTestCampaign`、`refillAllTestItems` |
| 战斗消耗品 | 醒神茶、镜银药膏、校时钥均可在战斗内使用并消耗 | `battleConsumables` |
| 全队友开放 | 3名AI队友、3种职责、每人3普通技能＋1终极＋1被动 | `companionRoles`、确定性AI P01–P15 |
| 完整关卡体验 | 4项调查、8场遭遇按剧情顺序开放；已完成关卡可重演，未来关卡不可提前进入 | `requiredCounts`、`investigationEncounterShape`、渐进入口模拟器验收 |
| 正式剧情接入 | 旧钟区20个任务节点全部映射到8场权威遭遇 | `oldClockMissionRouting` |
| 全遭遇可完成 | 每场遭遇可通过全部波次并到达胜利 | `everyEncounterCanReachVictory`（8参数用例） |
| 教学队伍节奏 | 前2场单人、随后2场1名队友、最后4场2名队友 | `partyTeachingOrder` |
| 区域首领 | 三阶段、归一时刻、第十三声四种应对、失败分析 | Boss阶段与第十三声运行时测试 |
| 结局与进阶 | 3种区域结局、2种阶位8误导响应均可完成并持久化 | `regionalEndings`、`rankEightPreviewResponses` |
| 规则回归 | 95项测试、10个套件全部通过 | 2026-07-22 `swift test` 输出 |
| iOS可构建 | App和本地CombatCore包成功编译 | 2026-07-21/22 Simulator Debug `xcodebuild` 输出 |

## 仍需直接运行证明

- [ ] 从正常标题页点击“第一章完整测试”，确认测试台展示且可退出；
- [ ] 逐页检查关卡、技能、物品、队友列表在目标设备上的文字、滚动、选择与状态反馈；
- [ ] 实际操作一场普通战、一场精英战与首领战，确认目标选择、技能冷却、消耗品、
  AI行动、失败分析和胜利奖励的触控流程；
- [ ] 首领胜利后实际完成一种区域结局与一种误导训练，并回到测试台确认持久状态；
- [ ] 从旧钟区正式任务入口完成一次新版战斗桥接。

## 当前环境阻塞

本机 `CoreSimulatorService` 与 `simdiskimaged` 在安装/启动 App 时失效。
`~/Library/Developer/CoreSimulator/Devices` 当前软链接到项目根目录的
`.simulator-devices`；即使指定新设备集，已崩溃的服务也无法注册运行时。
在系统重启并恢复 Simulator 服务之前，以上五项不得标记完成。
