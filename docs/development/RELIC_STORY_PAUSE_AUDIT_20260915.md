# 遗落物暂时停用：剧情与展示审计（2026-09-15）

用户本轮要求覆盖旧铃契约：先无遗落物；翠焰亡灵开场毒雾持续加浓至战斗结束，绿焰预告强力重击，假面留待手动使用。此次按全局暂停处理，保留旧拥有数据和原始资产，由主代理统一停用奖励、装配与效果。

## 本代理已修改
- `mistport-ios/Mistport/ChapterOneOnboarding.swift`：删除 Q2 取回条到 Q5 交铃的链条，改为名字引向邮务间的调查线索；Q5 战前、干预及战后改为毒雾/绿焰/手动假面指导；Q6 通过犬吠衔接；身份牌、怀表保留调查物证，但不再提遗落物。
- `mistport-ios/Mistport/ChapterModels.swift`：同步 Q2、Q5、Q6 摘要，删除 Q14、Q15、Q17 遗落物承诺及后期无主印章奖励文案，保留调查线索与主线证明。
- `mistport-ios/Mistport/CharacterProfileView.swift`：移除调查必定解锁遗落物的说明；按 `MPCChapterOneCatalog.relicsEnabled` 隐藏装备页及预览入口、过滤旧拥有列表。
- `mistport-ios/Mistport/SceneViews.swift`：依同一开关隐藏行囊遗落物分类/数据、构筑遗落物步骤/槽位；移除教程和战术摘要中的遗落物承诺。隐藏步骤后从被动开始，上一页不会回到隐藏页。

备份：`backups/relic-story-pause-20260915/`（后三文件）；Onboarding 原件由主代理本轮备份。

## 交给主代理的其它入口
- `GameStore.swift` 原 697–698：旧装备参与 combatPower；原 724 后：旧装备参与 configuredDungeonSkills 的伤害/冷却等修正。
- `GameStore.swift` 原 768–793 装备方法、856–869 战术预设会设定旧装备；正式 toggleCampaignRelic、加载迁移与保存由主代理处理。
- `ContentView.swift` 原 143–169：愚者正式关卡走 ChapterOneMissionBridgeView；其它路径/无主线关卡走 DungeonPrototypeView，仍传 equippedRelicIDs。该旁路不能以正式关卡不用为由遗漏。
- `DungeonView.swift` 原 582 CombatRelicStrip 是旧副本入口，无条件显示；应同时按开关隐藏并阻断传入遗落物。
- `ChapterOneTestView.swift`：旧试演、铃面板、Q5干预消息、遗落物行囊与奖励由主代理负责，未由本代理改动。

## 验证边界
已对 Onboarding 与 ChapterModels 进行文本扫描，玩家故事不再包含铃/欠账/遗落物发放承诺。保留 enum 与 persistenceKey 兼容旧档，不重放奖励。当前文件修改尚待主代理 Swift 构建和真机验证；未宣称运行验收。

## 主代理集成
GameStore战力/旧副本技能加成与装备方法、ContentView传参、DungeonView遗落物条均已按开关停用；正式effectiveLoadout与奖励路径在核心统一拦截。空物品行也已隐藏；补给保留。Swift真机构建通过，手机实际操作仍待复核。
