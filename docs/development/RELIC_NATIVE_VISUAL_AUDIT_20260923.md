# R02–R10 原生遗落物附效视觉审计（只读，2026-09-23）

后续处理（同日）：主控已在 `ChapterOneEncounterRuntime.swift` 的 B10 `bounty_transfer` 截疗分支补记 `lastRelicPlayerHealing += diverted`，因此原生绿色回血飘字可读取这一笔；35 项相关 `MistportCombatCore` 测试通过。下文“当前缺口”记录的是审计时源码状态，九件逐项真实触发录像仍未完成，不因这处计数修复而视为视觉验收。

## 判定范围与现有证据

这些是正式原生战斗中可能触发的九种契约附效，应纳入用户所说“所有法术”的**触发反馈与辨识度验收**；但它们并非九招另有施法者、投射物和命中时刻的独立攻击法术。适用标准是：真实规则触发时，玩家在战场上看得出**哪件遗落物、影响谁、得到或付出什么、何时结束**；强度按作用调整。防护、封存、截疗不能为追求参考图面积而伪造敌方受击或第二次伤害。效果轮廓仍须遵守自然撕散/蚀散与各自材质，不能用完整圆环、矩形光板或等距光条作主体。

`MPCChapterOneCatalog.isRelicEnabled` 对九件逐一列入白名单，不能因 `relicsEnabled=false` 误判全停用（`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263–269`）。当前 `output/whole-spell-round2-20260922/delivery-index.json:475–566` 中九项 `clips=[]`；`output/whole-spell-round2-20260922/relics-review.md` 只有源码核对，没有九件在真实战斗触发时的 MP4。仓库中 `output/sequence-nine-relic-integration-20260916/tests.log` 和 Swift 测试覆盖的是规则，不是画面。未发现可把九件原生触发一键录为视频的现成录制器；`tools/vfx-trials/build_whole_spell_round2_capture.py` 录的是既有动态法术，原计划显式把九件排除在独立片段外。

当前商店购买门槛由 `GameStore.swift:9–43,1915–1919,1974–1984` 明定；R02 是 Q4 后自动授予，R03/R04 要完成 Q4，R05 完成 Q9，R06 完成 Q14，R10 完成 Q17，R07 完成 Q18，R08 完成 Q20，R09 完成 Q26（另要求完成 Q25）。当前源码 `GameStore.swift:139–147,1668–1676` 的测试任务上限是 Q30、按顺序解锁；Q17+ **有路线和规则代码**，但本次未验证新档连续到达/购买/触发，不能把单元夹具视为玩家流程或真机视觉通过。

## 逐件缺口和最小实录样本

| ID | 真实触发 / 当前可见入口 | 视觉缺口与应有独立身份 | 最小画面和反例样本 |
|---|---|---|---|
| **R02 僭命勋章** | 手动 8 秒临时生命/攻击增益，结束将剩余 HP 对半结算；24 秒冷却。`ChapterOneEncounterRuntime.swift:1370–1422`。`ChapterOneTestView.swift:2357–2390` 只有道具图标的紫光、皇冠、计时与 `syncVisualHealth()`。| 战场角色本体尚无可核对的勋章/借命状态；仅角落图标不足以读到“借来又被取回”。建议胸口短促暗紫金契纹与生命条借额分层，结束时反向收回；不制造攻击爆炸。 | DEBUG 测试面板跳 Q5/Q6，装勋章，录发动前→发动后→8 秒清算→24 秒冷却；同时截 HP/上限与角色。反例：Q3/Q4不可发动、退场清算只一次。现成规则夹具 `UsurpedLifeMedalTests`。 |
| **R03 盐封呼吸囊** | 只收容有限持续伤害 60%，每收 10 点暂封 1 上限；`ChapterOneEncounterRuntime.swift:2928–2945`。当前 `ChapterOneTestView.swift:2209` 只列 `收容 stored/baseHP`。 | 毒伤一跳和封上限无战场来源标记，易误读成盾或回血。建议毒雾中的盐粒被囊体吸入、囊体层次逐次填满、上限纹轻微沉暗；别画成直击免疫盾。 | 买入并装备后 Q5 触发毒雾，录至少两次毒跳和上限变化；对照未装备同一跳，战后上限恢复。现成夹具 `ChapterThirtyEarlyRelicTests.poisonPartiallyContainedNeverDoubleChargesLowHealth`。 |
| **R04 返礼银扣** | 首次真实直击收容最多 30% 入场 HP，**该次攻击者**得所收伤害一半的普通礼盾；8 秒且礼盾破除后才就绪。`ChapterOneEncounterRuntime.swift:2078–2085`。HUD 有就绪/礼盾状态与敌血条下 `盾 N`（`ChapterOneTestView.swift:2212,2997–3007`）。| 目前画面主要靠数字，银扣“挡下→返给攻击者”因果未见可辨路径。建议角色身侧短银片折流，落到实际攻击者身上成碎甲膜；只围绕该敌，不画全敌盾。 | 买入 Q4 后在 Q6 受一次直击，录玩家减伤、攻击者礼盾出现、盾被击碎后再就绪；真免疫下不破盾。规则夹具 `ChapterThirtyEarlyRelicTests.giftShieldCannotExpireOrBeBrokenThroughTrueImmunity`。 |
| **R05 迟签印章** | 一笔技能直伤延后 3 秒并加 40%（有上限）；到点有效目标才造成实际伤害。`ChapterOneEncounterRuntime.swift:1038–1051,1850–1865`。HUD 待签秒数；正数事件只走通用飘字和 `presentEnemyImpacts(skill:nil)`（`ChapterOneTestView.swift:2021–2026`）。 | 通用命中没有印章身份，玩家无法把三秒前技能与此刻结算相连。建议目标表面有不规则残墨/纸缘伏笔，到点蜡红压印后裂散；原技能不得二次施放。事件结构只带目标/伤害，若制作需保留来源语义。 | 完成 Q9 后买入，Q10 或多敌场打一笔正数技能直伤，录初始无该笔伤害→3 秒印记→同一目标到账；反例：目标先死/真免疫时无新命中。规则夹具 `SequenceNineRelicIntegrationTests.stampDefersOnlyOnePacketAndDoesNotBoostTwice`、`deferredTicketVoidsAtTrueImmunity`、`deferredDeathDoesNotRetargetAnotherLivingEnemy`。 |
| **R06 反照墨镜** | 选定受伤敌人 2 秒后普攻先给该敌回血；4 秒内另一敌直击可向固定受赠目标反射，8 秒冷却。`SequenceNineRelicState.swift:53–71`。当前回血事件只发通用 `enemy-heal`，反射事件只发通用 hit（`ChapterOneTestView.swift:2021–2033`）。 | 治疗与反射分两次、跨两敌，通用绿字/受击难读为同一镜面契约。建议固定目标出现破损墨镜高光、赠血向内倒流；第二敌攻击时一片碎镜折到固定目标，明确两名敌人的不同角色。 | 完成 Q14 后买入，双敌场先伤固定敌人、选中等 2 秒、普攻赠血、另一敌直击→固定敌人受反射；同场录切换目标导致返照失效，单敌/满血不触发。现成规则夹具 `SequenceNineRelicIntegrationTests.mirrorPaysActualHealingBeforeReflectingOtherEnemy`、`mirrorTargetSwitchCancelsPaidPreparationWithoutRefund`。 |
| **R07 缄卷镇纸** | 三张以上编排牌，固定第三槽一次技能连伤害/状态一并封存，换 4 秒一次直伤收容；18 秒冷却。`SequenceNineRelicState.swift:73–87`。`ChapterOneTestView.swift:1988–2011` 明确封印时**不发 Unity skill**，仅保持原 contact 期限；HUD 显示庇护容量/时窗。| 当前第三牌无原技能演出是规则正确，但若没有取代性的“封卷→收容”可见动作，像技能失灵。建议第三牌从手侧卷入厚重纸纹、镇纸压下，随后一次直击在身体近处出现局部纸墨撕散；不得重播被封技能或敌方命中。 | 完成 Q18 后买入，编排≥3张，录第三槽施放时无原技能/无伤害/无状态→一次直击收容；另录编排<3张正常施法、冷却内第三槽正常施法。现成规则夹具 `SequenceNineRelicIntegrationTests.paperweightSealsFixedThirdSlotIncludingStatusAndPaysCooldown`、`paperweightNeedsThreePreparedCardsAndSealsOnlyOnceDuringCooldown`。 |
| **R08 逆潮铜锚** | 同敌同招首段真受伤再多付 5% 入场 HP，随后 2 秒同源同招两段共享最多 35% 收容；10 秒冷却。`SequenceNineRelicState.swift:88–99` 与运行时 `ChapterOneEncounterRuntime.swift:2056–2066`。HUD 只显示剩余段数/容量。 | 仅数值不能区分“首击代价”和“后两段收容”，若画首击免伤会反语义。建议首击铜锚坠落压身、后两段沿同一锚链被卷入，第三段后短暂崩散；来源/招式 ID 不可泛化。 | 完成 Q20 后买入，Q17 执行者或同敌三段招式录首段增伤、后两段收容、跨源不收；优先用现成 `SequenceNineRelicIntegrationTests.anchorGroupsOnlyRealPairedExecutorSegments` 作规则基准。 |
| **R09 归属断线针** | 只截取**选中目标从另一敌获得**的治疗，最多 20% 入场 HP、每场两次；随后自身禁疗 6 秒、12 秒冷却。`SequenceNineRelicState.swift:101–108`。HUD 次数/禁疗；通用玩家绿色飘字只读 `lastRelicPlayerHealing`（`ChapterOneTestView.swift:1821–1824`）。| 截疗路径缺“治疗线从敌到玩家被切断”的战场读法；当前 B10 转息还少玩家飘字，见下方确定性展示缺口。建议极细赤铜断线先切原治疗流，再连到玩家针尖；残余治疗仍到原目标，之后玩家禁疗可见。 | 完成 Q26 后买入；使用 Q7 修理敌、塔 `tower_mend` 或 B10 囊体转息场景，先让选中敌/玩家缺血，录实际截取→原目标残余治疗→自身禁疗 6 秒；反例自疗/满血/第三次不截。现成规则夹具 `SequenceNineRelicIntegrationTests.needleSplitsOneRealHealAndBlockedMedicineIsNotConsumed`；**B10 分支需单独录**，该夹具不覆盖它。 |
| **R10 空栏名片** | 手动指定固定敌人，3 秒内双方相互直伤无效；其他敌、毒伤与控制仍生效，18 秒冷却。`ChapterOneEncounterRuntime.swift:1027–1037`。`ChapterOneTestView.swift:2336–2354` 点击仅改 session，按钮显示契约中/冷却，未发 Unity 新指令。| 战场上最难辨目标：与哪一个敌人订契没有可见身份，也容易误以为全场无敌。建议玩家与固定敌人各出现残缺空白姓名纸片/断续墨痕，两者间短暂柔曲牵引；第三方不被罩入。 | 完成 Q17 后买入，双敌场手动点固定敌人后发动，录双向直伤被挡、第三方直伤照常、控制照常、3 秒后恢复；另录 Q5 毒雾仍伤。现成规则夹具 `SequenceNineRelicIntegrationTests.blankCardBlocksOnlyBoundPairAndStillAppliesControl`、`blankCardCannotBeSwappedOutDuringActiveContractAndDoesNotStopPoison`。 |

## R09 B10 展示缺口，影响边界

精确路径：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2537–2553` 的 `bounty_transfer` 在 2545–2548 行通过 `interceptHealing(...)` 得到 `diverted` 并执行 `playerHP += diverted`，但未将数值计入 `lastRelicPlayerHealing`。同文件塔内治疗在 2577–2580 行、主线 `repair_guard` 在 2612–2616 行均累加此计数。`mistport-ios/Mistport/ChapterOneTestView.swift:1821–1824` 仅在该计数大于 0 时生成玩家治疗飘字。`endRound` 每轮把计数清零（运行时 1965–1973 行），因此 B10 这一轮不会从上轮借到数值。**截疗和玩家 HP 数值结算已经发生，缺的是该分支的玩家治疗飘字/反馈，不是规则疗量。** 这也说明只看规则测试会漏掉视觉读数。建议实际录制并核对 HP 条、绿色飘字及 B10 残余转息；修复由战斗/原生展示负责人处理，不在本只读审计修改。

## 现成复现入口与最小验收方式

1. 规则夹具可直接运行（本审计未运行）：

   ```bash
   swift test --package-path mistport-ios/MistportCombatCore --filter 'UsurpedLifeMedalTests|ChapterThirtyEarlyRelicTests|SequenceNineRelicIntegrationTests'
   ```

   `output/whole-spell-round2-20260922/core-tests-passed.txt` 记载的历史命令已覆盖后两套；这是既有规则回执，**不能证明本次画面**。
2. DEBUG 原生入口：以 `--verify-p1-ui` 启动，`GameStore.swift:252–253` 开发者工具可见；`ContentView.swift:500–513` 的关卡面板调用 `GameStore.debugJumpToOldClockMission(number, enterImmediately:true)`（实现 `GameStore.swift:1842–1896`），可跳到上述 Q5/Q6/Q10/Q15/Q17/Q18/Q19/Q21/Q27 的真实桥接场景。跳关重建的是该关之前的进度，**不会自动购买并装备该遗落物**；需从原生商店购入、在人物页装备后开战。`--verify-p1-ui` 使用隔离验证存档，避免动用户正常存档。对缺钱/敌阵不合适者，用既有 `SequenceNineRelicIntegrationTests.session(q:passive:active:skills:)` 作为最小规则夹具，不能将其输出称为 Unity 实录。
3. 视觉证据应每项保存至少一段真实**完整战斗画面**，前后覆盖触发、代价/受益、结束；再截命中局部和 UI 数值，关联同一测试场次的状态/事件。必须有正例和关键反例；R05 目标死亡/免疫、R06 切目标、R07 少于三牌、R08 换来源、R09 截疗次数/禁疗、R10 第三方伤害最能识别错误。现有 R 系列无此视频，整体仍是**规则有入口、视觉未验收**。

优先级：先修 R09 B10 明确缺数的展示计数；再给 R10/R07/R06 建立可识别的目标/封存/跨敌因果反馈；随后补 R02–R05/R08/R09 的材质和状态细节，并对九项逐条真实录屏复核。大面积亮云不适合这些契约附效，重点是局部造型、相位和受益/代价清晰。
