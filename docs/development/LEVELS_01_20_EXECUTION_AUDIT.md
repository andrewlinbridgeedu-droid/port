# 第1—20关实施与验收台账

目标：完成旧城区1—20关全部相关设置，按当前确认方向制作。状态：进行中，任何已有配置不等于验收完成。

## 依据与优先级
用户最新要求 > AGENTS.md > 当前制作推进计划 > 旧设计资料。实时独立行动、每战手动点牌、未选只普攻；主线无额外经验；不显示选敌标记但保留点选。旧回合制与旧第5关纸人/猎犬方向不得覆盖当前要求。

## 当前状态摘要（2026-09-12，按最新实测更新）
- 统一战前版面已接入：单一原紫金面板、上中开始文字；每场手动点牌排序，空编排只普攻。早期及第14/19/20关有画面证据，尚非逐关全部验收。
- 正式连续流程完成第1—4关；连续存档备份见backups/before-q10-talent-verification/continuous-q4-save.plist。当前隔离正式存档从第10关战前9/20 fixture实际连续打完第10—20关，现为20/20，不能当新档1—17连续进度。独立预演不修改该正式进度。
- 第9关完成后4点天赋的界面边界已验证（8/20为0、9/20为4）；第16关累计8点仍为未批准候选。
- Unity入口现覆盖第1—20关；第13/17关均已正式实战通关，第16→17关换槽已验证。第13/17关缺专属精英模型。傀儡、归名执事及第19关两精英仍有守卫占位，不能算独立造型完成。
- 第19关已改双精英核心数据及错相行动，并用四格手动编排实战胜利；第20关单假面加普攻试演可胜，关底强度和独立阶段仍未完成。
- 记忆蛭尺寸、材质和死亡渐隐已取得实战证据；敌方无伤防御/准备不再走攻击表现路径，专项画面与具体意图的对齐仍待补证。
- 三证环已修正三种不同类别、百分比护盾和20%下一攻击；名牌已修正治疗百分比，护盾驱散已构建安装，实际触发专项画面仍待补证。两者规则测试不代表全部遗物负面设计完成。
- 第5关仍是用户否定的旧纸人/猎犬正式流程，翠焰亡灵与铃仍仅试演；Q05_FORMAL_MIGRATION_PROPOSAL.md已提交范围问题，待用户明确答复。
- 无主印章实际效果未实现，三证环真实负面未定稿；模型、法术差异、后期正式剧情/保存与连续第5—20关仍未完成。

## 初始源代码证据（历史快照，勿作当前状态）
- ChapterOneTestView.usesUnityBattlefield仅允许1—10关；后十关未走Unity战场。
- unityBattleEnemyID将全部记忆蛭映射到同一primary、全部核心映射到同一primary；精英ID未覆盖。不能直接开启11—20，否则重复目标会共用回调。
- 第5关正式内容仍是纸人之夜、旧猎犬和纸人交付。翠焰亡灵与铃仅独立试演，未自动升级为正式设计。
- 现有技能解锁由mission及campaign共同决定，11—13关战前教学是否真实获得需核对，不得用全卡预览证明可通。
- 本轮ChapterOneNaturalCombatTests通过：15个逐关回合模型样例、Q16独立时序及猎犬倍率。前序胜利为fixture，Q16回合模型明确预期失败；不代表实时连续通关。

## 每关要求
每关同时核对：前置剧情/目标；可辨认敌人变化与故事身份；实际3D实例、动画、法术；合法手动编排和技能效果；遗落物来源、正负效果；物品真实增量与重演边界；胜负/退场/回调；保存恢复和下一关。新档连续实测与跳关实测分别记录。

| 关 | 当前名称 | 当前阵容ID | 3D入口 | 整关验收 |
|---|---|---|---|---|
| 1 | 雨夜醒来 | enemy_hollow_clockmaker_q1 | Unity入口已接，逐关待复核 | 未完成 |
| 2 | 雾都幽灵 |  | Unity入口已接，逐关待复核 | 未完成 |
| 3 | 循名而来的猎犬 | enemy_clockwork_hound | Unity入口已接，逐关待复核 | 未完成 |
| 4 | 猎犬试探 | enemy_clockwork_hound | Unity入口已接，逐关待复核 | 未完成 |
| 5 | 纸人之夜 | enemy_clockwork_hound | Unity入口已接，逐关待复核 | 未完成 |
| 6 | 犬吠中的名字 | enemy_clockwork_hound | Unity入口已接，逐关待复核 | 未完成 |
| 7 | 空白身份牌 | enemy_hollow_clockmaker, enemy_hollow_clockmaker, enemy_memory_leech_node | Unity入口已接，逐关待复核 | 未完成 |
| 8 | 不属于我的名字 | enemy_memory_leech, enemy_hollow_clockmaker | Unity入口已接，逐关待复核 | 未完成 |
| 9 | 被改写的证词 | enemy_calibration_puppet, enemy_memory_leech_node | Unity入口已接，逐关待复核 | 未完成 |
| 10 | 失踪者名单 | enemy_clockwork_hound, enemy_calibration_puppet | Unity入口已接，逐关待复核 | 未完成 |
| 11 | 不属于我的家人 | enemy_memory_leech, enemy_memory_leech, enemy_hollow_clockmaker | 入口已接；模型/实测见当前摘要 | 未完成 |
| 12 | 强制校正 | enemy_calibration_puppet, enemy_calibration_puppet | 入口已接；模型/实测见当前摘要 | 未完成 |
| 13 | 救援命令 | elite_clock_chaser, enemy_memory_leech_node | 未接Unity战场 | 未完成 |
| 14 | 错误名牌 | enemy_memory_leech, enemy_calibration_puppet | 入口已接；模型/实测见当前摘要 | 未完成 |
| 15 | 归属标签 | enemy_hollow_clockmaker, enemy_memory_leech_node, enemy_memory_leech_node | 入口已接；模型/实测见当前摘要 | 未完成 |
| 16 | 街区封锁 | enemy_hollow_clockmaker, enemy_hollow_clockmaker, enemy_clockwork_hound | 入口已接；模型/实测见当前摘要 | 未完成 |
| 17 | 被删掉的人 | elite_memory_trimmer, enemy_hollow_clockmaker | 未接Unity战场 | 未完成 |
| 18 | 盐晶运输车 | enemy_calibration_puppet, enemy_clockwork_hound | 入口已接；模型/实测见当前摘要 | 未完成 |
| 19 | 归名执行队 | elite_clock_chaser × 2（错相行动） | Unity守卫占位；独立模型/法术未完成 | 未完成 |
| 20 | 唯一正确的名字 | boss_hollow_clock_guard, enemy_memory_leech_node | 入口已接；模型/实测见当前摘要 | 未完成 |

## 下一实施批次
1. 抽出按敌人实例生成的稳定战斗映射，支持同类多目标及精英；Swift和Unity共用可核对标识。
2. 补11—20阵容生成，验证双蛭、双核心、三敌、精英与首领；缺正式模型单独给Meshy规格，不能改名冒充。
3. 核对第五关正式升级与第六关追猎线衔接，落实铃/假面各自职责与负面效果；正式迁移须保持存档兼容。
4. 逐批推进技能、法术、物品、剧情与保存；先9—10，再11—13、14—16、17—20。
5. 最终新档1—20连续实测，记录所得、正常工具、关底转场与重启恢复。未满足全部要求不得标记目标完成。

## 独立实例标识实施（2026-09-12）
已新增核心 `MPCChapterOneBattleIdentity`，ChapterOneTestView改为调用该映射。按整个波次阵容（包含已死亡单位）分配primary/secondary/instance-N；双蛭、双核心和精英均有独立ID。保留前十关既有ID命名，未直接开启后十关Unity入口。

验证：`/tmp/chapter-identities-test.log`，20关标识覆盖/唯一性样例与2个同类单位死亡后稳定性样例全部通过。此证据只覆盖Swift映射，不证明Unity已经创建这些新增实例。下一步在Unity生成/注册对应实例，将目标、血条、退场及命中回调改为按完整实例集合解析。

## Unity 实例基础（2026-09-12）
已新增 `wave-instances:` 桥接入口与同类模板副本创建。校验阵容1–3个独立ID；按同族现有资产建立实例，未知精英族明确失败。切换旧阵容时停用附加实例。目标解析支持精确查找全部已安装ID；记忆蛭与核心施法接触回调使用当前handle，而非固定primary。

场景验证 `/tmp/wave-clones-verify.log`：`WAVE_CLONE_PASS memory-leech`、`WAVE_CLONE_PASS clock-core`。验证真实安装场景的克隆ID、模型与挂点引用独立、移动不影响源实例，Unity编译通过。检查脚本 `Assets/Editor/VerifyWaveEnemyClones.cs`。尚未从Swift开启后十关或装机验证完整多敌战斗；这一基础不等于后十关完成。

## 后十关入口接线（进行中）
已将11、12、14、15、16、18、19、20关切到动态Unity阵容，13/17专用精英资产仍缺，保留明确缺口。新增按已得进度建立的 `--preview-chapter-one-mission=N` 跳关检查入口，初始不选牌；它不构成连续通关证据。核心发招改发实例ID，避免双核心共用primary回调。Unity导出通过 `/tmp/later-waves-export.log`，Swift实例测试22样例通过。iOS构建/画面尚待检查。

首次第11关装机：`/tmp/later-waves-build.log`构建通过，但运行发现 `ArgumentException: Missing installed enemy family: memory-leech-primary`。画面仍旧守卫，三血条堆叠，不能验收。定位为桥接ready早于BuildCombatants句柄绑定；已将阵容请求改为等待已安装句柄后执行，正在重新导出验证。不得把首次构建成功当作第11关已完成。

启动时序修复版构建安装成功（`later-waves-ready-build.log`），第11关不再抛缺失句柄，三血条分别定位，但两只蛭未显示，仍失败。场景检查`wave-clones-bounds.log`显示启用的蛭SkinnedMeshRenderer bounds extents为零，已启用离屏蒙皮更新，下一轮验证该修复是否足够。正式通关与画面仍未验收。

## 后十关对白与结算去重（2026-09-12）

ChapterOneOnboarding新增Q11—20战前及战后共20个cue，ChapterOneTestView已接入既有对白/主城返回流程。保留原文件于backups/levels20-onboarding；未改奖励、技能解锁或第五关试演边界。仍须装机检查分页、显示时机和保存恢复。

奖励回归发现：同一胜利session重复completeEncounter会重复增加Q1止痛膏。核心现为每个session生成独立settlementID，由campaign在修改库存前去重；新session的正常重演仍奖励消耗品，剧情物品保持首通一次。该去重用于当前运行中的重复回调，未声称替代GameStore的持久化结算日志。

`/tmp/levels20-core-regression.log`：164项核心测试、24组全部通过，包括重复提交及独立重演边界。Levels20RewardsRegressionTests使用扩大生命池和完整技能集隔离结算行为，仅证明奖励/解锁API，不是正常构筑或新档连续通关证据。

`/tmp/levels20-leech-export.log`：Unity导出成功（进程退出0）。`/tmp/levels20-story-build.log`的iOS构建仍在进行，尚未安装本轮版本；第11关双蛭显示与1—20整关验收继续保持未完成。

## 当前装机复测

`levels20-story-build.log`最终BUILD SUCCEEDED，已启动原测试模拟器、安装并以`--verify-p1-ui --preview-chapter-one-mission=11`运行。实际画面仍是中央守卫可见、两侧记忆蛭血条可见但模型不可见，因此离屏更新修复未通过，不能验收。此开发预览入口不经过正式战前剧情，亦不构成对白验收。

正在用VerifyWaveEnemyClones检查蒙皮。发现生成prefab各SkinnedMeshRenderer的rootBone均为死亡脓水用puddle（本地缩放0.001），场景模型整体缩放约0.00168。检查脚本新增BakeMesh、重算网格bounds并比较改用MemoryLeechRig根骨后的结果；仅诊断克隆，不修改正式场景资产。日志`/tmp/levels20-leech-skin.log`，仍待对比结果和修复后装机。

根骨对比检查退出0，但更换rootBone后烘焙范围仍显示为零，未证明该候选修法有效。下一步核对顶点精确范围、bindposes及骨骼缩放，不能只修改rootBone后宣布解决。

高精度诊断：Mesh_0的sharedMesh高度0.01，原localBounds高度6.98149；烘焙顶点范围非零（高度0.001678），骨骼段正常，先前“零范围”为日志精度造成的误读。布阵使用导入动画包围盒将模型整体缩至0.001678。InstallP1Visuals现于保存prefab/布阵前用sharedMesh.bounds重设静止尺寸依据，并保留离屏蒙皮更新；未应用无效的rootBone替换。备份在backups/levels20-leech。正在运行InstallAndExport，日志`/tmp/levels20-leech-rest-bounds.log`；仍需导出、构建和实际画面验证，未标记修复通过。

导入层修订已成功导出，但重新检查场景后，localBounds又被Unity重算为动画范围，整体缩放仍约0.00196，未通过。因此在EnemyPresenter.TryCalculateRendererBounds中增加仅针对MemoryLeechPresentation的静止sharedMesh.bounds计算，避免激活时重算影响布阵。正在重新InstallAndExport（进程session 25910）。此前构建session 73842针对上一候选，不能当最终修复版；最终导出完成后须重新构建，避免混用导出版本。

最新场景检查通过执行：主体烘焙高度由0.001678变为3.30619，证明微小尺寸原因已消除，但仍需实际画面检查大小、位置与动画。追加修复BattlePrototype按活跃句柄解析守卫攻击：动态阵容可能存在隐藏的同ID旧模板，查找优先活跃实例；primary/secondary攻击也使用已解析实例，不再固定调用旧字段。已备份。统一导出进程11189，日志levels20-leech-export.log；后续顺序构建安装，未宣称该攻击修复实测通过。

用户询问模型数量后，已提供5个模型建议并记录于LEVELS_01_20_MODEL_REQUEST.md；尚未收到新模型，不将其视为交付完成。

统一导出11189已退出0。新增活跃/隐藏同ID守卫查找检查，初版因错误假设场景已有secondary失败，修正为按运行时从primary创建两实例后通过：`WAVE_ACTIVE_GUARD_PASS`、`WAVE_CLONE_PASS memory-leech`、`WAVE_CLONE_PASS clock-core`，检查进程30444退出0。此为场景验证，非实战回调验收。

构建40277因build.db locked失败；只读进程检查发现PID15178正使用同一DerivedData构建。没有删除数据库、没有终止该未归属构建，需观察其完成/日志后再推进安装。最终版本尚未装机。

`/tmp/leech-rest-fresh-build.log`已BUILD SUCCEEDED，PID15178已结束。安装退出0，启动PID22580，第11关实际截图确认左右两只蛭均可见、中央守卫可见，微小尺寸问题已解除；蛭呈白色，材质仍未通过。检查原始source.glb发现颜色/金属粗糙度/法线三图均存在，而FBX未正确绑定。已无修改提取原图到Models/MemoryLeech/Textures，InstallP1Visuals显式绑定Mesh_0，新增GLTF通道材质shader（B金属度、G粗糙度转光滑度、法线）。正在重新导出，不能把白模显示当最终美术或通关验收。

贴图版导出61329退出0。场景检查34436退出0，`WAVE_LEECH_MATERIAL_AND_SIZE_PASS`、`WAVE_ACTIVE_GUARD_PASS`及两个克隆检查均通过。iOS构建54589仍在运行，日志`/tmp/levels20-leech-fixed-build.log`，已完成UnityFramework链接，进行应用资源/新鲜度检查。修复前截图已保存`output/levels01-20/q11-before-material-fix.png`，未把它作为修复后截图。

并行任务“设计雾港游戏开发 Agent 架构”已主动协调：其不改Unity、不构建、不操作模拟器，仅审计血条/选敌标记；当前1—20主线任务独占构建与实测。等待当前构建完成后继续安装，不另起冲突构建。

按用户“不显示选敌标记”的约束，ChapterOneTestView.updateQueuedTargetPresentation改为清空Unity sigil，DungeonScene.showQueuedTargets删除标记生成，仅保留selectedEnemyID赋值和旧标记清理。排队目标字典、透明点击区域与实际伤害选择未修改。备份在backups/no-target-markers。解析检查session53848；当前应用构建54589在此前已启动，因此其结果不能作为该原生改动已编译的证据，待结束后再增量构建。

解析检查53848退出0。贴图版完整构建54589退出0、BUILD SUCCEEDED。为确保选敌标记清理确实编译，已启动顺序增量构建94049，日志`/tmp/levels20-no-markers-build.log`，当前仍运行于导出新鲜度pre-action。没有同时安装尚在被构建写入的App；材质版实战截图仍待该增量构建后交付。

增量构建94049退出0、BUILD SUCCEEDED；安装72845退出0，启动29938。第11关实际显示两只紫灰色记忆蛭、甲壳与肢体贴图，中央守卫；手动选择假面→身份错置→伪证→错影四牌，截图确认1—4序号，点击开始，实际看到技能命中中央守卫并掉血；随后点左蛭。返回测试列表显示11/28，前置为10关fixture，说明本次Q11胜利记录完成。不是新档连续通关。截图工具因审批等待捕获到战后列表，已如实命名为`output/levels01-20/q11-after-combat-progress.png`，不能当战斗过程截图；实际退场与完整contact链仍需预先开启录像再复测。

## Q11录像复测

重启30219，预先开启录像56602并确认Recording started，再手选假面→错置→伪证→错影。实际先打守卫、点左蛭、点右蛭，分别可见受伤，主角持续承受攻击，敌人死亡后进入“演练完成/不发放正式奖励”。录像正常停止并写盘：`output/levels01-20/q11-material-combat.mov`，93.68秒。已用AVFoundation抽帧核对：q11-t58.png三敌模型贴图、q11-t72.png双蛭投射与右蛭-70伤害、q11-t86.png胜利结算。没有降敌血/强制胜利；仍是开发跳关演练，不证明正式奖励保存或新档连通。

尚未通过：逐帧1秒渐隐时长未测；蛭血条仍横穿头部，需校正高度；绿色球状投射仍是初版法术表现，不能作为用户要求的最终差异化法术验收。Q11整关状态仍未完成。

## 构建协调与资产规格补充
本轮重新核对当前状态，采用已落盘的静止网格bounds尺寸修法。`leech-rest-build.log`因共享DerivedData数据库锁失败；重新导出后清单逐文件SHA256与源文件一致、文件集合也一致，但新鲜度检查曾失败，期间观测到另一xcodebuild/Unity诊断流程交错。未安装或宣称修复通过。当前构建日志`/tmp/leech-rest-fresh-build.log`，应先核实其终态再启动新构建。

补充正式模型需求 `LEVELS_13_17_MESHY_BRIEF.md`：第13关精英空壳守卫、第17关精英记忆蛭，列清身份、剪影、材质、尺寸、动作、挂点及英文提示。只是待生成规格，动画由开发侧制作，不是已交付资产。

## Q11血条留白装机验证

`/tmp/levels20-leech-hud-build.log`确认BUILD SUCCEEDED，安装后启动PID40917。记忆蛭血条相对Unity锚点从+22调整为-36，点击区域仍使用原偏移。实际待战及战斗画面血条已位于头部上方；手点四牌开始并点左蛭，观察到左蛭死亡脓水形态、右蛭承伤，最终演练胜利。完整录像`output/levels01-20/q11-hud-clearance.mov`正常结束写盘，战后截图`q11-hud-end.png`。该结果为Q11跳关演练，非正式存档连续通关。

退场代码复核：UnityBattleBridge先等待MemoryLeechPresentation.Die的Death动画长度，再执行1秒材质alpha下降。代码存在不等于视觉通过：新GLTF主体shader为opaque，需进一步核实淡出支持及最终结果提示时序。暂未验收1秒视觉渐隐。

## 记忆蛭主体退场材质修复

确认原MemoryLeechGLTF.shader固定o.Alpha=1，且无_Color属性，现有alpha循环无法让主体渐隐。新增Resources/Shaders/MemoryLeechGLTFFade.shader，保留原贴图通道，仅提供透明退场版本；UnityBattleBridge只在退场临时材质副本上切换shader，完成后仍恢复原材质。备份backups/leech-exit-alpha。Unity导出日志/tmp/leech-exit-alpha-export.log，后续须构建和实战验证，尚未宣称视觉渐隐通过。

退场shader导出19977退出0，资源已包含在导出报告。构建73215进行中。进一步发现胜利等待4.5秒仅按Q8关号启用；现改为阵容包含普通记忆蛭即使用相同等待，防止Q11等混合阵容1.2秒就弹出结果遮挡死亡动画。备份见同目录ChapterOneTestView.swift。该Swift修改发生于构建途中，当前构建后需顺序增量构建确认。

顺序增量构建16074退出0、BUILD SUCCEEDED，安装成功，重新启动47614后待Unity加载进入Q11。四牌手动编排，录制31666确认Recording started后开始战斗。录像目标output/levels01-20/q11-exit-fixed.mov；尚待终局抽帧。

Q11修复版录像31666已停止写盘，84.59秒，战斗正常胜利。AVAssetReader按样本实际时间抽帧到q11-exit-exact：71.405及71.603仍见完整不透明脓水，72.013已消失且尚无结算遮罩。证明结果等待避免过早遮挡，但未证明平滑渐隐，脓水材质的透明shader变体仍需继续检查，不能将主体shader修复等同所有死亡部件通过。

## 记忆蛭死亡部件透明变体

上一版录像证明脓水突隐。现给非GLTF主体的记忆蛭死亡部件新增Resources/Shaders/MemoryLeechPartsFade.shader，使用明确编译的alpha:fade路径保留_Color、_MainTex、金属度、光滑度及法线；UnityBattleBridge仅在临时退场副本上切换。通用Standard透明变体可能被剥离是候选原因，未以该推断当作已证实根因。备份UnityBattleBridge.before-puddle.cs。导出日志/tmp/leech-parts-fade-export.log，进程53436；仍须成功构建并录像验证。

死亡部件透明版导出53436及构建32335均退出0，BUILD SUCCEEDED，安装成功，启动51442。尚待本版实战录像验证。已更新台账开头的当前摘要，把旧入口状态标注为历史快照，保留备份。

## Q11死亡部件渐隐实测通过

最新安装51442，手选假面→身份错置→伪证→错影，录像16453预先确认Recording started，实战正常胜利。录像output/levels01-20/q11-parts-fade.mov，56.815秒，已正常停止写盘。AVAssetReader按样本PTS抽帧：q11-parts-exact/frame-40.815.png脓水不透明，frame-41.613.png脓水和泡明确半透明且地砖透出，frame-42.008.png已消失，随后才出现演练结算。此证据支持本场脓水渐隐修复通过，不延伸为其他敌人、新档连通或逐关法术验收；精确起止帧未量化为严格1.000秒。

## Q11—13技能交付时序文案

核对claimVictory：荒谬归结、反客为主、无名宣告在对应首胜后永久解锁，正式makeChapterOneSession也不提前授权它们。修订ChapterOneContent中Q11—13关卡简介，移除战前要求使用本关战后新技能的指示，明确战后获得；未改变技能解锁与数值。备份backups/levels11-13-skill-timing。定向swift test --filter Levels20RewardsRegressionTests退出0，3项通过，日志/tmp/levels11-13-skill-timing-tests.log。这是核心奖励边界检查（放大血池隔离结算），不是正常实时战斗或正式存档验收；本轮文本尚未装机。

## 正式入口每战手动编排修复

发现正式ChapterOneBattleSetupOverlay的earlyTutorialLayout.task在空选时自动填前几张牌；laterMissionLayout的startIsDisabled禁止空牌序并强制重排教学。这与用户每关手动点牌、未点只普攻冲突，跳关预览不经过此overlay，之前Q11录像不能覆盖该问题。已删除自动填牌，允许空序列开战，保留按钮短暂启动防误触；beginConfiguredBattle本来就按draftSkillIDs构建空/有序序列。备份backups/manual-all-missions，swiftc -parse通过。应用构建/tmp/manual-all-missions-build.log、进程16235进行中。需正式入口装机验证，不能仅跳关预览宣布修复通过。

正式编排版16235构建成功，安装启动55017。实际从地图4/20进度点击进入Q5，经玛拉剧情和转场到正式ChapterOneBattleSetupOverlay。未点任何卡，画面无编排卡/序号，开始战斗按钮可用；点击后主角普攻且队列仍空，敌我血量下降。截图formal-q5-empty-sequence.png及formal-q5-basic-only.png。此为正式入口早期布局的空序列行为证据，非新档连续通关；Q5仍旧猎犬/纸人，不能当新设计验收。后十关laterMissionLayout空序列仍待装机验证。

## 隔离存档与正式战斗预览入口

发现GameStore DEBUG启动配置末尾--verify-p1-ui总将phase覆写为districtMap，因此与--preview-prebattle-loadout/--preview-clock-guard组合不能直达正式桥接界面。现保留已经选中的dungeon阶段，其余仍进入地图；仅DEBUG测试入口，继续使用mistport.p1-ui-verification隔离存档。备份backups/formal-preview-route。swiftc解析通过，构建/tmp/formal-preview-route-build.log、36640进行中。待用后期预览验证laterMissionLayout空选开战，不作为正式进度通关。

后期正式编排布局实测：36640构建成功，安装启动58341，--verify-p1-ui与--preview-clock-guard组合进入Q20正式桥接。q20Prelude两页可读并进入编排，AX两张卡均未选且开始挑战启用；未点牌直接开始，编排面板关闭且无自动牌序，见敌人受伤。截图formal-q20-empty-sequence.png及formal-q20-basic-only.png。隔离存档仅此前四关进度，跳到Q20后只有早期两牌，不能据此判断Q20正常进度技能、平衡或通关；首领仍守卫替身。早期Q5和后期Q20两种正式布局的空选开战已分别有实机证据。

## 重试回到手动编排

restartEncounter原先恢复initialSession牌序，且正式父视图仍处battle。现重试清空chosenLoopSkills与父draftSkillIDs，新增onRetrySetup回调使正式桥接回setup；本地interlock等待父状态更新，adoptConfiguredSession解除；清掉Q5独立试演开战标记。备份backups/retry-manual-sequence，swiftc解析通过，构建/tmp/retry-manual-sequence-build.log、17670进行中。尚需失败→重试→空序列→手动开始实测。

重试版17670构建成功，安装启动61726。Q20正式预览手选错步穿行一牌后实际胜利并进入q20Aftermath，未复现失败，不能作为重试证据，也不证明正常Q20平衡。源代码复核发现battleIsActive变false的handoff会adopt旧session并恢复牌序，已在该setup同步后再次清空chosenLoopSkills。此追加修复尚待构建；重试验收未完成。

重试handoff追加修复构建/tmp/retry-handoff-build.log（57321）仍在运行，已多次用同一handle确认存活，未重启构建。复核失败面板自动关闭倒计时，后续需及时点击重新挑战以验证空编排。当前尚无失败重试通过证据。

重试handoff构建57321已退出0、BUILD SUCCEEDED，安装成功，启动65357先出现已恢复战后奖励再返回主城，说明隔离存档存在上次未关闭结算；没有把该画面作为重试证据。随后正常终止并重新启动同预览，未清除存档。失败重试实测仍待继续。

65542的Q20空牌序实战已失败，画面伤害统计834、普攻100%，进一步证明空序列不自动放技能。失败截图观察到剩6秒，随后点击重试坐标却返回主城；不能区分工具延迟导致倒计时退出与容器onTapGesture竞争，重试未通过。下一步需录像记录点击时刻或隔离手势，勿认定已修复。

失败面板点击隔离：将祖先ZStack的关闭onTapGesture移到背景Color，两层装饰渐变不拦截点击，使按钮不再处于关闭手势祖先下。保留原8秒倒计时。此为消除潜在竞争，未把上一轮返回主城归因于已证实的手势bug。备份backups/defeat-background-tap，构建/tmp/defeat-background-tap-build.log、73721进行中；仍待实测。

失败面板背景手势版73721构建退出0，安装启动69033。Q20空牌序失败，统计834普攻100%；截图见5秒剩余后点击重试坐标，返回主城，未通过。仅隔离祖先手势不足以证明解决；需为倒计时退出、背景退出和重试回调增加可区分诊断，排除观察到点击之间的倒计时耗尽。

失败动作诊断：BattleDefeatOverlay.finish现DEBUG记录source、countdown、uptime，四来源background/exit-button/retry-button/countdown；隔离UI测试时同时写debug.lastDefeatAction供进程退出后读取。Release行为不变。备份backups/defeat-action-diagnostics，解析通过，构建/tmp/defeat-action-diagnostics-build.log、35008进行中。下一轮失败后读该键判定退出来源，避免根据截图剩余秒数猜测。

诊断版35008构建成功、安装启动72458，Q20空牌序失败后自动返回主城。读取隔离plist的debug.lastDefeatAction：source=countdown countdown=0 uptime=6408.722184375。本轮确定为倒计时退出，无retry-button记录；不能据此认定重试回调错误。后续需面板出现即点击（当前工具交互延迟使8秒窗口易错过），不更改正式倒计时来伪造原行为通过。

72768再次失败后点击，日志仍为countdown=0（uptime6552.692109583334），工具延迟错过窗口。新增DEBUG且--verify-p1-ui同时存在时才生效的--hold-defeat-countdown，专门隔离重试交互验证；该模式不能证明正式8秒计时交互。正式自动退出已观察两次，重试需独立验收。

重试交互隔离实测：66587构建成功，安装76121，使用--verify-p1-ui --preview-clock-guard --hold-defeat-countdown。自然失败后点击重试，日志source=retry-button countdown=8 uptime=6817.457097333334。回到正式setup，两张牌AX均未选、敌我满血，间隔观察血量不变；截图retry-empty-setup.png。再次点击开始后敌我受伤，证明回调→空编排暂停→手动再开战链路可用。本场原牌序为空，尚不证明非空旧牌清除；倒计时被调试暂停，不能声称8秒内点击时序已验证。

重试后重新选牌实测：76121第二次空序列失败后再重试，AX假面未选→手动选择已选→开始。假面单牌战斗胜利，结算统计总1440、普攻81.5%、假面18.5%，铜币+42（隔离存档重演）。证明重试后手动选择可实际执行；未自然失败，因此仍不能证明非空旧牌序的重试清除。未修改数值强造失败，也不作为Q20正常进度难度验收。

用户截图纠正：去掉底部开始挑战及额外Panel，保留中间偏上文字。ChapterOneBattleSetupOverlay统一使用现有earlyTutorialLayout，所有关卡仅显示金色开始战斗，卡牌留原底栏。备份backups/unified-start-layout。26412构建成功，安装后79835的Q20实际截图unified-start-q20.png确认无额外面板/底部按钮，中央偏上文字、原底栏保留。

## 用户最新统一布局与成长核对

用户明确每关版面一致，卡牌与遗落物随真实进度增加，人物强度按规划。当前角色页已绑定game.hermitTalents，旧30点沙盒描述过时；但GameStore.hermitTalentBudget仍为Debug固定9点，Release按completedChapterMissionIDs.count/2封顶9，违反已确认前8关0、第9关后4点。UNIFIED_GAME_DESIGN第232附近表明确标天赋建议，后16关+4及后续里程碑不能整体自动批准；已确认第9关4点可作为实现依据。battleRelicContents目前按session.loadout而非全持有展示；需区分可用、持有与已装备。核心party默认1000HP，正式GameStore目前直接传campaign.party，人物成长真实接入仍待追踪，不能用Debug固定9点测试结果作正式强度验收。

已落实确认天赋边界：GameStore.hermitTalentBudget仅在completedChapterMissionIDs包含old-clock-9时为4，否则0，移除Debug9点/每两关1点。后续候选里程碑尚未接入，不宣称1—20成长完成。旧存档在初始化已用restored(...budget:)按预算和前置过滤，不直接修改用户原存储；后续保存按现分配。备份backups/confirmed-talent-budget。swiftc解析通过，Hermit核心4测试通过（分配和战斗效果，非GameStore里程碑测试），日志/tmp/confirmed-talent-tests.log。构建/tmp/confirmed-talent-budget-build.log、15050进行中，待装机核对Q8/Q9边界。

天赋战斗传递复核：makeChapterOneSession已带game.hermitTalents，但正式beginConfiguredBattle重建loadout遗漏，现补loadout.talents=game.hermitTalents。测试台playableLoadout原固定budget9且读standard，现按Q9完成给4/否则0，并遵守隔离存档参数。备份backups/start-talent-transfer。解析通过；15050构建仍运行，本轮追加需其完成后顺序增量构建，尚未装机验证天赋效果。

15050构建成功。天赋传递追加改动启动顺序构建/tmp/talent-transfer-build.log、55412。检查debugJumpToOldClockMission发现降低进度未重算已学天赋，现在completedMissionIDs重建后按hermitTalentBudget restored过滤，防止前8关携带后期天赋。此追加发生于构建中，仍需后续增量确认，未装机验收。

55412天赋传递构建退出0、BUILD SUCCEEDED。为覆盖构建期间追加的跳关已学天赋预算过滤，启动顺序增量/tmp/talent-progress-final-build.log、14538。确认DeveloperTestPanel按钮调用debugJumpToOldClockMission，可用Q9战前/Q10战前检查0/4点，尚未执行装机点数验证。

14538最终增量构建退出0、BUILD SUCCEEDED（/tmp/talent-progress-final-build.log），已安装并启动隔离存档PID89760。实际点击开发者列表第9关后进入玛拉开场剧情；尚未完成角色页0/4点界面核验。CUA后续getState返回User unavailable，本次不将装机成功计为点数或人物强度验收。

统一遗落物持有边界：MPCChapterOneCampaignState.effectiveLoadout此前仅排除depleted，现在同时校验ownedRelicIDs并去重，保留已装备顺序，不自动装备或改写保存选择。GameStore起战及预演原已有局部持有过滤，本次将约束补入共享入口（正式beginConfiguredBattle重建loadout也使用它）。新增battleRelicOwnership覆盖未获得、获得、耗尽、失去持有、重复配置和原选择保留；ChapterOneEncounterRuntimeTests共52测试通过，日志/tmp/relic-ownership-tests.log。备份backups/relic-ownership-loadout。此次为核心规则验证，尚未重新构建安装iOS，不算逐关成长/新档连续验收。

新增sequentialProgression：新campaign按Q1—20顺序通过公开session战斗API取得胜利，再completeEncounter，逐步断言卡牌集合（1错步/3假面/8错置/9伪证/10追猎/11归结/12反客/13终极）、1/2/4格、终极解锁和完成数，重复同session结算不增物品。Levels20RewardsRegressionTests四项通过，/tmp/levels20-sequential-rewards.log；备份backups/levels20-sequential-rewards。该测试仍使用win辅助中的100000HP/全技能，仅证明顺序结算状态，不证明正常角色强度或新档UI连续通关。
新发现：ownedBattleSkills和availablePrebattleSkills均排除isUltimate，普通序列也排除namelessStage，当前没有看到已解锁终极的专属战斗入口。Q13后终极可用性未通过，需补入口及实测，不能用核心isUltimateUnlocked代替。已向用户异步询问规划稿Q16后累计8点是否正式采用，待回复；不能把未回复当批准。

终极技能入口实现：ChapterOneTestView原ownedBattleSkills取消对已获得且session已解锁终极的排除；沿用原卡牌栏卡面，不新增Panel。终极战斗中手动请求，可取消尚未开始的请求，不进入普通sequence或占普通格；continuousCombatTick在当前动作结束后优先派发终极，仍走原技能动画/命中/核心结算。待释放状态在adoptConfiguredSession/restartEncounter清零，施放中和已使用后禁止重复请求。备份backups/ultimate-card-entry；swiftc解析通过，utilitySkills核心测试通过（群体4误认、重复使用抛ultimateAlreadyUsed），日志/tmp/ultimate-once-tests.log。iOS构建62688 /tmp/ultimate-card-entry-build.log进行中，尚未装机/真实动画验收。

62688终极入口构建成功并安装，启动93688（--verify-p1-ui --preview-chapter-one-mission=14）。第14关预演可进入统一战前/战斗，末端终极卡面露出面板右侧，滚动及拖动未观察到成功访问完整卡面；点击右缘后有紫色施法画面但不足辨别是否终极，未判释放通过。截图output/levels01-20/q14-ultimate-dock-overflow.png。需先排查ScrollView裁切/触摸/宽度问题，再取施法效果证据。另安装前在第9关战前进度（8/20）实际角色页看到“旧版战斗：可用0点”，后续4点尚未完成UI核验；当前CharacterProfileView有新版独立预览入口，应保留其他工作中的新版实现。

卡牌栏溢出修复候选：combatDock容器明确frame(width: geometry.size.width-24)，共享早后期同一宽度；移除ScrollView.scrollClipDisabled，恢复滚动视口裁切。终极卡牌AX值区分待开始、可释放、等待释放、已使用。备份backups/bounded-card-dock，swiftc解析通过。构建74869 /tmp/bounded-card-dock-build.log运行中；尚未实测滚动恢复，不能将布局修复候选记作交互通过。

74869构建成功，安装后97081第14关预演确认卡牌裁切回面板内，但拖动仍未滚动。点错步卡可见序号1与上方编排卡，证明点击传递正常；UnityPassthroughView本身hitTest=nil，不是整体触摸遮挡。下一候选移除卡牌Button上的simultaneous LongPressGesture，保留右上角详情入口，避免与ScrollView拖动竞争；备份backups/card-scroll-gesture，解析通过。97934 /tmp/card-scroll-gesture-build.log构建中；不预先认定滚动根因或终极释放通过。

97934手势修复构建本轮持续复核仍运行，Unity export freshness check passed，尚无终态，不重启构建/不覆盖安装；待该句柄完成后复测。Unity现有fool_skill_10展示名称无名宣告，与核心namelessStage映射一致，映射检查不能替代真实施法验收。

97934构建成功，安装1075第14关；去长按后拖动及left滚轮仍不滚动，排除“去掉长按即可修好”的假设。已恢复原simultaneous LongPressGesture和相应提示，保留验证有效的裁切/宽度修复。当前安装1075是去长按实验版，源码已恢复；终极操作仍未验收。下一步应直接检查UIScrollView实际contentSize与viewport/是否可滚动，或增加不改变面板结构的确定性访问方式，不能继续无证据反复切换手势。

卡牌滚动尺寸诊断：为卡牌HStack内容及ScrollView视口添加无触摸透明GeometryReader，DEBUG且--verify-p1-ui时将global frame写入隔离defaults debug.card-dock.content / viewport，随frame变化更新，可用内容width对viewport width及拖动前后x测量真实滚动。备份backups/card-scroll-measurement；解析通过。55341 /tmp/card-scroll-measurement-build.log运行中，待装机读取尺寸，尚无运行时数据。该版包含已恢复的长按，正式界面无新增元素。

55341诊断构建成功，安装并启动5092第14关预演。隔离defaults实测viewport={x:34,y:812.5,width:372,height:77}，content={x:34,y:812.6667,width:431,height:77}；CUA拖动[306,747]→[125,747]后同值，明确有59pt可滚空间但未产生位移。不能继续按“内容不够宽”修复，也不能仅凭CUA拖动失败证明iOS物理触摸失败；需要检查UIScrollView.isScrollEnabled/pan状态或提供保持原面板的可访问滚动入口。终极末端仍未完成操作验收。

通过LLDB只读检查5092 UIKit树（检查后detach）：SwiftUI.HostingScrollView frame372x77、content431x77、offset0,0、scrollEnabled=1、userInteractionEnabled=1、pan.state=0（闲置）。日志/tmp/card-scroll-inspect.log。因此不是isScrollEnabled=false或内容尺寸不足；CUA自动拖动不移动尚不能证明真机手势缺陷。后续可增加可访问的显式滚动入口或诊断pan事件，避免重复构建猜测布局。

卡牌栏确定性访问入口：保留横向ScrollView，增加ScrollViewReader及稳定skill.id锚点；持有超过5张时在原行左右显示查看前面/后面卡牌按钮，滚至首/末，不增加Panel或改变持有/编排规则。备份backups/card-hand-navigation，解析通过；45927 /tmp/card-hand-navigation-build.log构建中，待验证点击后的content.x变化、完整终极卡面及真实释放。此改动提供替代访问方式，不宣称修复未知的CUA拖动问题。

45927翻看按钮版构建成功，安装启动9356第14关预演。CUA点击右箭头330,745后卡列从错步起始变为身份错置起始，末端无名宣告卡完整显示；证明按钮导航有效。空普通编排点击开始后再点末端296,747，可见施法画面，但尚未取到foolUltimateUsed/全体4误认的运行时证据（simctl log查询fool_skill_10为空），不判完整终极效果通过。截图output/levels01-20/q14-ultimate-after-tap.png为点击后战斗现场。入口可访问性通过，原CUA拖动问题未宣称解决。

终极命中证据：在continuousCombatTick实际value.useFoolSkill(.namelessStage)成功后记录隔离debug.ultimate-contacts，含session结算UUID、encounter、canUseAgain及每个存活敌人的illusionStacks/finaleReady；最多保留20条，仅DEBUG+--verify-p1-ui，不写正式存档。用于后续点击/重复点击/重试的真实运行验证，不代替规则本身。备份backups/ultimate-contact-evidence，解析通过；26310 /tmp/ultimate-contact-evidence-build.log构建中。

26310终极证据构建成功并安装启动12749。第14关预演空普通编排→右箭头→开始→点末端无名宣告。实际命中记录session E7522F3D-0DC2-4747-8B8E-887193D9BB32：enemy_memory_leech#0及enemy_calibration_puppet#1均illusionStacks=4、finaleReady=true，canUseAgain=false。保存output/levels01-20/q14-ultimate-contact-evidence.json。此证据确认共享战斗视图的手动终极执行、全体效果和使用后不可再用状态；本场随后失败自动回测试列表，未完成同场二次点击/重试恢复实测，也不是正式桥接或新档通关验收。

正式桥接终极验收：13067仅--verify-p1-ui，从开发者关卡列表debugJump第14关，经过两页玛拉剧情→正式setup→手动假面→右翻→开始→点击终极。session 2BDAC857-4601-4CF5-95F1-E216C3C9AC0F实际命中两敌均4误认、finaleReady=true、canUseAgain=false。同场战斗仍运行时再次点击末端卡牌，记录总数保持2（前独立预演1+本正式场1），未新增终极施放。保存output/levels01-20/q14-formal-ultimate-contact-evidence.json及q14-formal-ultimate-used.png。正式编排→终极解锁传递→手动施放→同场重复点击不再施放已通过此跳关检查；仍不是新档连续通关、Q14难度或重试恢复验收。

从起点连续流程开始：隔离存档备份backups/before-continuous-campaign/verification-20260912-171250.plist后，仅隔离suite以--reset-tutorial重置，启动13740，正式地图0/20进入Q1（未用debugJump）。初始无技能/遗落物，手点开始后3普攻触发玛拉；逐页发卡后回setup，错步未自动选中，手点卡显示序号1，再开始，实际击败敌人进入契约战后对白。保存检查completed=[old-clock-1]，venueCoins210（重置默认180+首通30），inventory通行证1/止痛膏1，battle-loadout=[]。当前停Q1战后玛拉第一页，尚未完成退出战后→Q2及重启恢复检查；reset-tutorial为现有重置入口，非卸载安装全新容器，不宣称完整新档1—20验收。

连续流程Q1→Q2：Q1战后确认契约后重启14331（仅--verify-p1-ui，无reset），地图1/20正确指向Q2；铜币仍210，通行证/止痛膏各1，无重复发奖。正常地图进入Q2并读完四页战前对白；仅错步一牌、未预选、无遗落物。手点错步再开始，实际两幽灵同时-98，随后进入Q2战后取回条对白。保存证据output/levels01-20/continuous-q2-progress.json；当前停Q2战后第一页，后续Q3尚未进入。这是从重置进度继续的正式流程，非跳关。

连续Q2→Q3：Q2战后继续调查直接衔接Q3玛拉，正常授予假面并说明手点顺序。setup仅错步/假面，无预选；先点假面后错步，实际上方与角标显示假面1、错步2，开始后击败猎犬，进入“项圈里刻着你的名字”战后第一页。保存output/levels01-20/continuous-q3-progress.json。当前停Q3战后，未跳关/加生命/额外天赋。该过程验证两格编排及关卡衔接；未单独抓取假面两次承伤的命中明细，不将其算作完整技能机制专项验收。

连续Q3→Q4：完成Q3战后及此前未确认的主城欢迎引导，地图正常3/20→Q4。发现firstSequenceReorder对白仍称拖动换序，与用户手点顺序不符；源码改为移出后按顺序重选，备份backups/click-order-tutorial，解析通过，尚未重建安装该文案。现安装版Q4战前两牌未预选，手点假面→错步后实际胜利，保存4/20、铜币300、hound_trace1，停Q4战后组合说明。录像output/levels01-20/continuous-q4-combat.mov；已抽帧：5.208为远处居中猎犬战前，16.402为大面积白黄火焰遮挡，不能仅此宣称火球视觉已合格。需要继续检查投射过程及强度/遮挡，保留真实录像。

Q4白亮爆炸排查：BattlePrototype的猎犬命中路径在HellHoundEffekseerFireball.PlayImpact自带FireBall终末爆炸同时，又StartCoroutine播放burst-infernal-impact-v1，同位置叠加两套爆炸。移除额外burst调用，保留原FireBall命中与唯一ReportCombatContact；未改伤害/时机/飞行比例。备份backups/hound-single-impact。无其他Unity/xcodebuild进程后启动44811 Unity模拟器导出/tmp/hound-single-impact-export.log，尚未完成导出、iOS重建及视觉复测；不能预判全部过曝已解决。源码还有上轮click-order-tutorial文案待下一次iOS构建覆盖。连续进度停Q4战后，勿重置。

44811 Unity导出退出0，日志明确“exported UnityFramework project .../mistport-ios/UnityBuild (951663875 bytes)”且batchmode successfully；随后启动顺序iOS构建31448 /tmp/hound-single-impact-ios-build.log，含单次火球爆炸与第4关点击换序文案。当前未装机/视觉复测，不计遮挡修复通过。

31448 iOS构建成功并安装19836，--verify-p1-ui --preview-chapter-one-mission=4（不改连续4/20进度），手点假面→错步并录制output/levels01-20/q4-single-impact-combat.mov。抽帧q4-single-impact-frames/frame-14.822.png仍见大面积白黄火焰遮挡，去掉重复burst不足解决原特效过曝；未判视觉通过。下一步定位原FireBall飞行/终末节点尺寸和亮度，而非重复删改已移除调用。

原火球可读性调整候选：核对EffekseerHandle.SetAllColor为全局RGBA乘色接口后，HellHoundEffekseerFireball的蓄力/飞行/命中均设(0.65,0.65,0.65,0.55)，命中独立scale从0.27改0.14。保留Fly按authoredTravel拟合起终点的scale/rotation、0.78s飞行时长、frame150命中回调，避免视觉缩小改变弹道。备份backups/hound-readable-fireball。无Unity/xcodebuild运行后启动55692 /tmp/hound-readable-fireball-export.log；待导出、iOS构建及同视角视频复测，数值仅修复候选，未判火球视觉通过。

55692导出退出0且exported UnityFramework明确成功（951668744 bytes）；随后启动61342 iOS顺序构建/tmp/hound-readable-fireball-ios-build.log，尚未装机。

61342 iOS构建成功，安装完成后启动23746独立Q4预演；手点假面→错步并实际胜利。录像output/levels01-20/q4-readable-fireball-combat.mov，抽帧18.808显示远处猎犬蓄火，19.200显示前景命中亮焰但主角轮廓仍可辨；相比上版大面积白黄遮挡有改善，终末仍偏亮，未将整体视觉判为最终验收。11.600等亮度最高帧包含假面/技能光环，不能据白像素计数误判为火球峰值。统一战前单面板、上中部金色开始文字仍在。注意unityBattlePresentation Q4虽名hellHoundPounce，Unity UseHellHoundPounceModel内hellHoundUsesFireBreath=true；本轮未因旧命名误改成狂暴火犬，也未改数值/伤害/剧情。连续正式进度仍停4/20，独立预演不代表连续Q5以上已完成。

本轮正式恢复24043：地图4/20，进入Q5仍触发旧原信/纸人交付对白，截图output/levels01-20/q5-formal-old-delivery-unresolved.png。没有确认该交付或宣称Q5通过。备份当前隔离连续存档于backups/before-q10-talent-verification/continuous-q4-save.plist。随后开发者选择第10关建立9/20 fixture，重启24303→主城→角色→天赋，实际AX与画面均为“旧版战斗：可用4点 · 新版独立预览”，截图output/levels01-20/q9-completed-four-talent-points.png；结合此前8/20为0的实测，确认已批准第9关4点界面边界。该验证是跳关fixture，未验证分配后实时伤害与1—20连续成长；当前运行存档9/20，连续4/20存档已备份尚未恢复。

第19关规则修复：正式encounter由两个普通enemy_hollow_clockmaker改为两个既有elite_clock_chaser（沿用1450HP/104攻/22防，未发明新精英数值）。该关独立意图[calibration,strike]，两实例起始相位0/1，各自命中只推进自己的相位；普通Q13精英模式不变。模型clock-chaser尚未安装，因此Unity入口暂排除19，沿用现有SpriteKit人形守卫占位；修正精英旧fallback错误映射猎犬，绝不视作独立精英造型已完成。第二个独立模型、不同专属法术和实时视觉仍待交付。备份backups/q19-dual-elite-rules。
新增ChapterOneExecutionPairTests验证两者rank均elite、4轮交替伤害、独立actor回调、击败第一人后survivor身份和节奏；连同20关实例/奖励检查，/tmp/q19-dual-elite-tests.log全部9测试（含参数样例）通过。earned-loadout回合模型Q19胜利25次行动、剩余272HP，/tmp/q19-earned-loadout-tests.log；不是实时或新档验收。iOS构建17748 /tmp/q19-dual-elite-ios-build.log进行中。

17748构建成功安装27796，独立Q19装机发现排除Unity后的SpriteKit角色/敌人比例显著缩小，不符合统一战场，故该渲染候选不通过。现恢复Q19 Unity入口，并让elite_clock_chaser暂映射已安装clock-guard人形3D占位族（保留两实例稳定primary/secondary），核心elite等级/数值及错相行动不回退。Q13入口仍禁用；独立追令者/执行者造型待模型，不把此占位计作交付。先前本轮关于排除19与clock-chaser-secondary的描述由本条取代。构建47023 /tmp/q19-preserve-3d-build.log进行中，待复测统一比例。

47023构建成功、安装启动30885第19关独立预演，确认恢复统一3D前景主角/两人形守卫占位/单紫金面板/上中开始文字。手动假面→错步→错影追猎→荒诞归结四牌后实战胜利；录像output/levels01-20/q19-dual-elite-combat.mov，40.008为双目标交战，65.005为演练完成与不发正式奖励页面。未使用终极/消耗品，未更改本场HP或额外点天赋。此证据支持新双精英数值在该编排下实时可通，不证明正式新档剧情/奖励、准备校正的专属动画或独立模型完成。最终映射专项/tmp/q19-placeholder-identity-tests.log五项测试通过（含20关参数样例）。

第20关表现审计发现通用守卫路径未传guard/calibration意图，Unity无论无伤准备还是攻击都调用PresentClockGuardStrike并Consume假面VFX。修复Swift仅为clock-guard族携带这两种意图；Unity解析后走原地准备0.65秒、回调原实例ID，不挥刀、不Consume、不清playerDefending。真实攻击仍走原路径。影响Q19准备、第20关防御及其他守卫防御；不宣称新增首领阶段。备份backups/enemy-nondamage-intents。新增核心专项确认准备保留假面次数、攻击伙伴才消耗，四项测试通过/tmp/enemy-nondamage-intents-tests.log。Unity63000导出退出0，iOS75394 /tmp/enemy-nondamage-intents-ios-build.log进行中，待实际防御/假面画面验收。

75394构建成功，安装完成启动34968第20关独立预演。只手选假面、不用终极/消耗品，实战完成后独立进度20/28；录像output/levels01-20/q20-defensive-intent-combat.mov。抽帧10.010主角与假面均可见，但尚未将每个画面与guard意图回调精确对齐，因此不能仅凭该帧宣布防御表现专项完全验收。Unity导出明确951689968bytes。此实战还暴露Q20只用假面加普攻即可通过；当前boss900HP/118攻/24防且仍守卫占位，不代表关底强度、独立阶段/法术已按完整方向完成。已确认资料中Q20独立阶段具体数值仍缺，不用旧瑟维安阶段直接覆盖赫恩。

第17关裁去的名牌负面修复：说明为下一次治疗减少30%，旧healingPenalty=30实际固定扣30生命，且phantom.3天赋治疗绕过。改为3000基点并集中receivePlayerHealing，覆盖止痛膏/盐茶、借来的名字被动、天赋幻身治疗、伙伴治疗；只扣下一次正治疗事件，返回真实恢复量用于日志。备份backups/nameplate-healing-percent。首版测试错误假设战前沿用残血而失败，核实章节启动满血后改为真实守卫攻击制造缺血；1000/2000HP下首药140/280、次药200/400验证通过。/tmp/nameplate-healing-percent-tests.log，57测试3组（含108关参数样例）通过。无主印章仅有说明，无runtime实现；所写放弃25%终极增伤在当前终极里也不存在，不能据文案宣称负面效果达标。iOS增量构建/tmp/nameplate-healing-percent-ios-build.log进行中。

27336 iOS构建成功并完成安装（72840退出0）。本轮治疗百分比验证为核心测试，未宣称新增装机用药画面验收。正式1—20遗物缺口整理为LEVELS_01_20_RELIC_RULE_GAPS.md；下一明确代码缺口是三证环把A→B→A误算三种不同类别，且100盾未按最大生命百分比。

三证环已有规则修复：独立Set跟踪当前链的类别，重复类别清空后以该类别开始新链；三种不同类别触发后清空。盾值改为playerMaxHP的10%，不改首领自身previousActionCategory机制。备份backups/three-category-relic。新增ABA不触发、重计数后第三种触发、触发后新链及1000/2000HP护盾100/200验证；/tmp/three-category-relic-tests.log，53项2组回归通过。新负面效果仍未定稿，未判整件遗落物完成。

95619三证环类别版构建成功，但安装前发现下一次攻击说明20%而技能只有10%、普攻没有加成。本轮补技能120%且仅正伤害消费，普攻也120%并消费；无伤动作不消耗。新增测试触发当次普攻60、插入utility、下次72、再下次60，54项2组回归通过/tmp/three-category-damage-tests.log。最新增量构建/tmp/three-category-damage-ios-build.log进行中；当前安装仍是上一治疗百分比版，勿把旧构建当本次装机完成。

14456三证环强化版构建成功，安装2947退出0。补技能双session对照，第一次120%、第二次不加成；/tmp/three-category-skill-tests.log三项通过。第5关正式迁移候选整理为Q05_FORMAL_MIGRATION_PROPOSAL.md，未自动把试演升级正式。

第17关trim_buff核对：旧逻辑仅69伤害，名牌无条件触发且未移除增益。现先实现护盾驱散：命中移除现存护盾，之后正常结算攻击；只有实际移除护盾才触发名牌2层误认和下一治疗-30%。尚未定义/实现其他增益的驱散优先级，不能宣称完整裁忆机制。备份backups/trimmer-shield-dispel。测试覆盖有盾/无盾实际触发、移盾后伤害、百分比治疗与次治疗恢复；54项2组通过/tmp/trimmer-shield-dispel-tests.log。iOS构建/tmp/trimmer-shield-dispel-ios-build.log进行中。第5关迁移问题仍待用户明确答复，未升级试演。

22583护盾驱散版构建成功，安装97963退出0。当前摘要已按最新证据更新，移除此前记忆蛭渐隐“仍修复中”等旧状态；保留13/17模型、Q5正式迁移、Q20独立阶段及连续5—20等缺口。护盾驱散规则尚无新增真实装机触发截图，不把安装成功写作整关通过。

正式9/20 fixture重启48604进入Q10：两页玛拉对白正确说明本关仍两格、通关后四格，四张已得牌未预选；但战前只见居中单犬，傀儡占位缺失，截图output/levels01-20/q10-missing-escort-before.png。规则阵容有hound+puppet；旧UseLateEscort复用HellHound场景并额外激活guard，而动态wave已有等待句柄安装的完整实例布阵。现将Swift动态wave入口从>10扩到>=10，Q10沿真实session.enemies生成两实例；不把占位当新傀儡模型完成。备份backups/q10-wave-presentation，Swift解析通过，iOS51623 /tmp/q10-wave-presentation-ios-build.log构建中，待同一正式入口复测。尚未通关Q10，正式进度仍9/20。

51623构建成功、安装23017后正式51971重进Q10，双敌恢复为左犬/右守卫傀儡占位。战前假面→错步后点第三牌被两格限制拒绝，随后实际胜利，录像output/levels01-20/q10-formal-wave-fixed-combat.mov。前后存档q10-before-formal-verification.json / q10-after-formal-verification.json：新增old-clock-10、铜币490→530、tracking_module1。读完战后两页错影追猎/四格说明，重启52270地图10/20指向Q11，铜币530和模块1未重复。正常进入Q11两页对白后五张已得牌、初始未预选；手点假面→错步→伪证→错影，角标1—4与上方四牌一致，截图q11-four-slots-after-q10.png。当前停Q11战前，四牌已手选尚未开战。此为9/20 fixture起的正式10→11衔接，不是连续新档1→11。傀儡独立模型未交付，不能记为第10关整关视觉验收完成。

沿第10关后正式进度直接进行Q11，假面→错步→伪证→错影四牌实战胜利，录像q11-formal-after-q10.mov；存档q11-formal-progress.json为11/20、铜币580。读完战后两页、重启52747地图11/20开放Q12，正常两页战前后进入Q12，卡牌栏六张且新归结卡出现，未预选，截图q12-earned-six-cards.png。当前停Q12战前，尚未战斗。发现Q11—13战后交付只泛称工具，源码已补明确荒谬归结/反客为主/无名宣告名称及入口，不改解锁规则；备份backups/later-skill-delivery-copy、Swift解析通过，尚未安装新对白。

76716技能交付提示版构建成功、安装22668退出0，启动55992正式11/20进度进入Q12。六张牌未预选，手选假面→错步→身份错置→归结后实际胜利；录像q12-formal-after-q11.mov，存档q12-formal-progress.json为12/20、铜币630。当前停Q12战后第二页，后续Q13尚未进入；第13关缺独立精英3D，不能将之后备用渲染测试记为完整视觉验收。第12关的fortify/calibrate当前没有完整强化/驱散机制及专属表现，需继续补齐，通关证据不能替代该机制验收。

傀儡三阶段核对：fortify/calibrate原已通过currentIntent给予普攻50%减伤，slam原为2倍攻击，非完全无规则；缺的是calibrate实际驱散和无伤阶段表现。本轮calibrate仅针对enemy_calibration_puppet移除护盾，沿用实际驱散后名牌触发（不提前发遗物），不改重击数值；Swift/Unity把fortify/calibrate也传到无伤准备分支，不消耗假面受击VFX。护盾以外增益的驱散与独立特效仍待设计/交付。备份backups/puppet-calibration，55项3组回归通过/tmp/puppet-calibration-tests.log；专项覆盖普攻30→60、强化不清盾、校正清盾无伤、重击140、伙伴阶段未被推进。Unity导出/tmp/puppet-calibration-export.log进行中，尚未装机。

87468傀儡校正Unity导出退出0，日志明确951691493bytes成功导出；顺序启动55555 iOS /tmp/puppet-calibration-ios-build.log。新增校正后的ChapterOneNaturalCombatTests通过（15关回合样例、Q16独立时序、猎犬倍率），/tmp/puppet-calibration-natural-tests.log，不是实时新档通关证据。当前安装仍上一技能提示版，尚未安装本次Unity校正。

55555傀儡校正iOS构建成功，安装52189退出0。当前正式隔离存档仍12/20，旧战后第二页需继续。新版校正实际装机触发尚未取证；第13/17备用渲染统一比例仍待处理，缺独立模型不等于应维持不同战场版式。

统一13/17战场候选：supportsUnity启用全部20关；追令精英继续现有人形守卫占位，裁忆者改用记忆蛭同类占位族，保留精英内容ID/数值，不宣称独立模型完成。血条、命中1.1秒、死亡4.5秒等待改按呈现族判断，避免精英被当普通人形0.65秒/1.2秒。备份backups/elite-unified-battlefield，20关唯一实例映射与死亡稳定性测试通过/tmp/elite-unified-identities-tests.log，Swift解析通过；iOS /tmp/elite-unified-battlefield-build.log构建中，待实际13/17装机。

62582统一精英战场构建成功，安装97318退出0、启动63225。重启恢复Q12未确认奖励页，实读铜币630/镜银药膏1，无重复发奖；奖励页自动退回主城后正常地图进入Q13两页战前，仍12/20。

Q13统一3D正式实战：正常比例主角、左精英守卫占位/右核心、原单面板，四牌假面→错步→身份错置→归结实战胜利。录像q13-formal-unified-battle.mov，q13-formal-progress.json记录13/20、铜币695（+65，含精英15加成）。当前Q13战后第二页，终极解锁后下一关实际使用尚未在此段正式推进验证；此前Q14终极实测为独立fixture，不能混记。第17新入口尚待装机；专属精英模型和法术仍未交付。

Q13战后确认后沿正式进度进入Q14，已得终极正常出现在卡栏，手选仅假面后开战并手动释放终极；新session DABBEA6C-6FA1-48D3-9E11-72A59388A2CC 双敌各4层误认/finaleReady，重复点击没有新增成功释放。实际胜利后存档14/20、铜币745（+50），q14-formal-progress.json、q14-earned-ultimate-combat.mov。读完两页战后对话返回主城。此为9/20 fixture后的正式10→14段，不能算新档1→14连续通关。

Q14战前发现双敌左侧重叠，q14-cross-level-overlap.png。定位UnityBattleBridge.SetEnemyVisibility持有上一关死亡位置，每次visible又恢复旧位置，覆盖新的队列布阵。修复为切换战场命令前停止旧退场、恢复并清空旧位置/旋转缓存；不改变阵型坐标。备份backups/enemy-exit-cross-level；VerifyEnemyExitReset真实场景守卫从左槽退场→清理→右槽→重复visible保持右槽，/tmp/enemy-exit-reset-test.log ENEMY_EXIT_CROSS_LEVEL_RESET_PASS。Unity导出成功951729589bytes，/tmp/enemy-exit-reset-export.log；iOS /tmp/enemy-exit-reset-ios-build.log构建中，尚待装机跨关复测。

87827退场缓存修复版iOS构建成功，安装63342退出0、启动67857。正常地图14/20进Q15，三敌左守卫/右核心/后核心，手选假面→错步→身份错置→归结四卡后实际胜利。q15-formal-exit-reset-combat.mov、q15-formal-progress.json：15/20、铜币795（+50）、新增relic_unified_gear，未自动装备。读完两页战后返回主城。Q15尚无三证环真正负面效果；跨关换槽实际复测继续到Q17，不能仅凭编辑器检查称已装机验收。地图Q15入口显示旧天赋觉醒标签但点击实际进入战斗，需另核对旧成长节点文案。

正式Q15→Q16衔接：Q16初始空编排，左右两守卫/后排猎犬正常，重新手选同四牌并实际通关，q16-formal-exit-reset-combat.mov、q16-formal-progress.json：16/20、铜币860（+65）、盐茶1。末段实见旧纸人已发动与黑血条画面q16-live-combat.png，之后进入封锁线剧情；不把旧纸人视作新版遗落物验收。战后单页已确认返回主城，继续Q17换槽实测。

正式Q16→Q17未重启衔接：左精英蛭占位、右守卫，原Q16左守卫已正确换到右侧，没有恢复旧死亡位置。截图q17-cross-level-formation-fixed.png；四牌重新手选后实际通关，q17-formal-unified-combat.mov、q17-formal-progress.json：17/20、铜币940（+80）、新增relic_trimmed_nameplate。完整两页战后已确认返回主城。此段没有特意装盾触发精英驱散，不能称该机制专项装机已验证；精英仍同类占位模型。

同时补齐SetEnemyVisibility/SetTargetSigils的活跃实例优先查找，避免隐藏旧secondary模板与本关克隆同ID时错显旧模板。/tmp/enemy-exit-clone-test.log两项通过：跨关换槽缓存清理、同ID隐藏模板不被visible指令激活。Unity /tmp/enemy-exit-clone-export.log导出中，本次小补充尚未安装，刚才Q17实测为前一版退场缓存修复。

97323活跃实例优先版Unity导出成功951727628bytes，3076 iOS构建成功/tmp/enemy-exit-clone-ios-build.log，安装5531退出0，启动72270。重启地图17/20指向Q18，铜币940、三证环/纸人/受损名牌持有列表保持，无重复奖励，q17-restart-preserved-progress.json。当前停Q18地图入口，尚未开战；无运行中构建/录像。第16→17实际换槽画面为前一退场缓存修复版，最新补充查找逻辑通过编辑器检查与装机启动，尚未专门构造旧secondary模板的模拟器验证。

正式Q17重启后正常进入Q18：两页战前、空编排、左傀儡守卫占位/右猎犬；手选假面→错步→身份错置→归结后实战胜利。q18-formal-combat.mov，q18-formal-progress.json为18/20、铜币1005（+65）、迟秒怀表2、记忆丝3。两页战后已确认返回主城，继续Q19。此为9/20 fixture起的正式连续段，不是新档连续1—18。

正式Q18→Q19：空编排后手选假面→错步→错影→归结，开战手点右侧精英，双敌实际通关。q19-formal-combat.mov；12.007秒实帧q19-formal-frames/frame-12.007.png见右侧挥斧、左侧待机，右血量更低，原单面板且没有选敌标记。q19-formal-progress.json为19/20、铜币1085（+80）、旧钟街通行凭证1。两页战后已确认返回主城。外观仍两个守卫占位，不能算双精英独立美术完成。

正式Q19→Q20：两页战前、统一原单面板，重新手选假面→错步→身份错置→归结并手动释放终极。q20-formal-combat.mov；q20-formal-progress.json记录20/20、铜币1205（+120）、无主印章首次持有、权柄回声1、旧钟街通行凭证2（前关已1），序列仍9。终极新session 25EA5A22-2FE3-4191-A1B8-A23AB3144BB4确认首领与核心均4层误认/finaleReady，每战不可再次使用。此段只是9/20 fixture后的正式连续10—20通关；并非新档1—20，也不证明赫恩独立阶段与无主印章效果已完成。

新增Q15_Q20_RELIC_CONTRACT_PROPOSAL.md具体候选并已异步询问用户：三证环触发后下一次实际直接承伤+25%；印章终极层数4→2换一次符合条件的身份错置不消耗误认。尚无明确答复，未接入正式逻辑；按AGENTS候选不能当正式规则。第5关迁移与第16关天赋8点的问题仍未得到明确答复。

第20关战后两页均已确认；重启73822地图仍20/20、第二区按钮开放，第三—五区禁用。q20-restart-progress.json确认金币1205、序列9、物品与遗物保持，没有重复发奖。当前停第一地图通关后入口；地图仍显示旧“晋阶演证”按钮文案，是成长文案待对齐项。无构建或录像运行。

地图成长入口文案修复：MissionBoardView.buttonTitle旧逻辑只把第1—8关显示为进入，导致第10/15/20关点击战斗按钮却分别显示技能进化/天赋觉醒/晋阶演证。现第一地图全部统一进入，按钮行为与战斗成长规则未改。备份backups/map-entry-growth-label；GameStore.hermitTalentBudget当前仍第9关4点，未接入第16关8点候选。/tmp/map-entry-growth-label-build.log构建中，待装机。

69995地图入口文案版构建成功；安装14718退出0、启动77442。实际AX确认第20关按钮已为进入，进度仍20/20、第二区开放。截图q20-map-entry-label-fixed.png。当前无构建/录像运行，遗落物候选问题未获答复，未改正式技能。

人物成长合法预算补证：GameStore.makeChapterOneSession与ChapterOneTestView.beginConfiguredBattle均传入game.hermitTalents。新增HermitTalentTests.earnedFourPointBuildAffectsLaterBattles覆盖Q10—20：合法4点（诡术0/1、幻身0/1）禁止第5点；同敌同技能伤害高于未分配基线；假面提供30盾/2次幻影；新战斗保留分配但清空盾和幻影临时状态。/tmp/four-point-talent-tests.log 5项测试含11关参数样例通过。此为规则层证据，不冒充4点配置逐关装机；未改天赋预算、正式数值或未批准的后续成长。测试原文件备份backups/four-point-talent-verification。

天赋技能名对齐：HermitTalents三条秘兆说明与CharacterProfile秘兆指引将伪造证据/荒诞终幕改为正式伪证烙印/荒谬归结，未改效果。备份backups/talent-skill-name-alignment，96930构建成功/tmp/talent-skill-name-build.log；安装62146成功、启动80921。装机角色页20/20、旧版战斗可用4点，点击进入S9独立预览（明确战斗未接入、沙盘30点）。源码.fullScreenCover在DEBUG选HermitTalentTreeView，Release选LegacyHermitTalentTreeView；因此本次正式天赋文案仅有源码/构建证据，不能把预览显示当正式天赋装机验收。预览数据/路由未改，正式4点预算未改。当前停独立预览页，无运行构建或录像。

晋阶就绪条件对齐：原chapterAdvancementIsReady只检查当前地图20关与材料，performAdvancement却要求mist-crown-20。现就绪条件也检查selectedDistrict mist-crown与该最终关完成；角色页不再因旧城区20/20宣称第十三声完成且可晋升8，改为本区完成继续调查，只有实际就绪才提示仪式。未改晋阶操作门槛或数值。备份backups/advancement-readiness-alignment；83182构建成功/tmp/advancement-readiness-build.log，安装3868成功、启动84545。AX与截图q20-advancement-prompt-fixed.png确认20/20、序列9、战力915，正确提示继续调查。当前角色情报页，无构建/录像运行。

遗落物图像审计：角色页实际显示纸人已选、名牌/三证环/无主印章可选；后三件均RewardMaterial蓝晶占位。未找到现有专属原画。内置image_gen生成裁去的名牌独立位图，已检查透明alpha和刮名金属轮廓，保存IconRelicTrimmedNameplate.imageset/nameplate.png并接CharacterProfile遗落物栏。完整提示词NAMEPLATE_ART_PROMPT.md，备份backups/nameplate-art。45091 /tmp/nameplate-art-build.log构建退出0；尚未安装，三证环/印章仍蓝晶占位，不能称遗落物视觉全部完成。

名牌原画装机验收：安装2328退出0、启动88179；角色遗落物栏实际显示刮名金属牌，alpha正常，无蓝晶占位；纸人仍已选，名牌/三证环/印章仍可选，未改变装备。截图output/levels01-20/nameplate-art-installed.png。三证环在同屏仍蓝晶占位，印章也未制作；本次只确认名牌角色栏原画，不扩展为战斗栏和行囊均完成。当前停角色遗落物栏，无构建/录像运行。

三证环与无主印章专属原画：内置image_gen分别生成三交错金属环与空白印面握柄章，完整提示RING_SEAL_ART_PROMPTS.md。PNG已目视检查与sips alpha确认，保存IconRelicThreeProofRing/IconRelicNamelessSeal.imageset并接角色栏，备份backups/ring-seal-art。97110构建成功/tmp/ring-seal-art-build.log，安装21553成功、启动91640。角色栏实际三证环图已替换蓝晶，名牌保持正常；截图ring-art-installed.png。印章位于右侧未滚入视口，只有生成图/资源构建证据，不能称实际缩略图已验收。持有/装备仍纸人已选其余可选，规则未改。当前角色遗落物栏，无运行构建/录像。

遗落物多入口原画接入：SceneViews.InventoryDisplayItem.artName补名牌/三证环/无主印章；ChapterOneTestView.relicArtName同样补齐，角色页已接。备份backups/relic-art-all-surfaces。29394构建成功/tmp/relic-art-surfaces-build.log，安装3449成功。此为资源映射/构建证据，行囊及战斗栏实际截图尚待补齐；未改装备或效果规则。

行囊多原画实际验证：94900版打开全部22种、遗落物4件，四件均独立原画；印章详情图正确，截图relic-inventory-art-verified.png。未装配任何新遗物。发现来源均泛称已获得，现SceneViews按mission.encounterID和firstClearRelicID反查首通来源（15/17/20），纸人剧情交付特殊来源保留。备份backups/relic-inventory-source；84189 /tmp/relic-inventory-source-build.log构建成功，来源版尚未安装。印章旧效果文案仍与运行时不符，等待候选规则确认，不因原画完成称效果完成。当前行囊遗落物页，无运行构建/录像。

来源版装机实际补证：启动98635，行囊逐一点击印章/名牌/三证环，AX分别确认第20关·唯一正确的名字、第17关·被删掉的人、第15关·归属标签·首通获得。截图relic-source-progress-verified.png。持有4件、金币1205、20/20保持，未装配或改效果。印章旧效果说明仍待规则对齐，不能据来源和原画正确称正式效果已完成。

遗落物代价显示修复：行囊原先只拼接mechanism/story漏cost，现完整显示；战斗详情Text原字面量(relic.cost)改插值；胜利奖励三件专属原画补映射。备份backups/relic-cost-reward-display。80866构建退出0 /tmp/relic-cost-display-build.log，安装退出0、启动2476。实际行囊名牌AX/截图nameplate-cost-visible.png确认下一次治疗减少30%与第17关来源完整展示。战斗详情及奖励图仅构建/源码证据，尚未实际打开验证；未改正式机制，纸人/三证环/印章规则缺口仍在。

名牌战斗栏实际补证：2476版行囊装配名牌（原纸人保留），正常地图重演Q20，空编排未开战。nameplate-battle-dock-verified.png确认名牌独立原画、纸人并列、原单面板与中央偏上开始文字。点击名牌无详情，源码paperRelicDockSection为展示HStack，ChapterRelicDetailSheet当前没有调用入口，因此此前详情插值修复不可称实际入口已验收。toggleCampaignRelic允许多件装备，当前横排无滚动，后续须验证四件全装的宽度适配。停Q20战前，未开战/发奖，无构建录像运行；测试装配现为纸人+名牌。

四件全装布局发现并修复：2476实际Q20战前四件+止痛膏把名称挤成竖列。paperRelicDockSection改横向ScrollView、内容保持自然宽度，原46高度/卡牌位置不变，备份backups/relic-row-overflow。58415构建退出0，安装退出0启动5784；four-relic-row-width-fixed.png实际前三件名称横排完整、第四件露出右边，卡牌和开始文字正常。横向手势尚未实际验证，不声称尾端补给已触达。当前隔离验证档四件全装、Q20战前空编排，未开战无发奖。

遗落物末端可达修复闭环：5784版实际drag与scroll均未移动（不能把ScrollView编译通过算手势验收）；沿现有卡牌栏方式增加超过2件时的左右ScrollViewReader按钮。备份backups/relic-row-navigation；90171构建成功/tmp/relic-navigation-build.log，安装73448退出0启动9174。实际点击右按钮，印章/三证环/止痛膏完整出现，relic-navigation-end-verified.png；点击左按钮返回纸人/名牌。原单面板、卡牌和中央开始文字保持。尚未开战点击止痛膏验证实际消耗；当前四件全装Q20战前、无构建录像。

末端止痛膏实际操作补证：9174版四件全装Q20空编排开战，右按钮到末端，受伤后点击止痛膏，补给项消失；主动退出返回主城。relic-row-consumable-combat.mov已停止保存，实帧31.007使用前血条约28%、32.022使用后虽又受27伤仍约45%，确认回血可见。relic-salve-inventory.json存档止痛膏1→0、金币1205不变。此为补给操作专项，不是Q20通关或满装备机制验收；当前主城，无录像构建。

人物成长运行时核对补证：combatPower旧加分与正式session没有数据连接；campaign.party默认1000生命，未找到逐关playerMaxHP修改路径。形成LEVELS_01_20_GROWTH_RUNTIME_AUDIT.md，已异步问固定基础属性/已有属性成长表，尚未答复，未擅加数值。不能用20/20战力915当实际强度完成证据。

记忆丝来源核对：item_memory_filament（Q2/15、上限99、配置false）与material_memory_filament（Q8/11/17、上限999、配置true）为不同目录物品，不能无批准合并库存。行囊原只取第一个来源，改显示已完成关卡中的全部来源，避免漏后期所得及揭示未通关来源。备份backups/inventory-repeat-sources。38625构建中/tmp/inventory-repeat-sources-build.log，尚未装机验证。

重复物品来源版38625构建成功；安装76690退出0、启动12811。实际AX确认记忆丝item来源Q2/15、material来源Q8/11/17，数量2/3未变；素材筛选后完整详情截图memory-filament-sources-verified.png。全部21项列表下详情初始超出屏幕，CUA drag/scroll均未移动，不能称全列表滚动已验收；分类入口可完整查看。当前素材筛选、20/20金币1205，无构建录像运行。

行囊详情可达修复：全部21项时详情在屏幕下方，保留原排版，通过外层ScrollViewReader在点击物品后定位底部详情；独立请求计数允许重复点击同一项再次定位，不在初次进入或切分类时自动滚动。备份backups/inventory-detail-reveal。63630构建中/tmp/inventory-detail-reveal-build.log，尚未装机验证。

行囊自动定位装机闭环：63630构建成功/tmp/inventory-detail-reveal-build.log，安装65371退出0启动16028。全部21项中点击记忆丝×3，页面实际上移、详情完整进入屏幕，含三关来源与数量。截图inventory-detail-auto-reveal-verified.png。未改数量或装备；此项验证程序定位有效，不代表CUA拖动已验证。当前完整行囊选中记忆丝，无构建/录像运行。

镜银药膏原画闭环：内置image_gen生成ItemMirrorSalve透明PNG，sips hasAlpha yes，完整提示MIRROR_SALVE_ART_PROMPT.md。26363构建退出0/tmp/mirror-salve-art-build.log，安装73956退出0启动19544。实际补给分类缩略图/详情图均正常，无原画待补字样，截图mirror-salve-art-verified.png；100护盾说明、第12关来源、持有1保持。盐茶等其余缺图仍待补，不宣称全部美术完成。当前补给分类，无构建/录像。

盐茶原画闭环：内置image_gen生成ItemSaltTea透明PNG，alpha已确认，完整提示SALT_TEA_ART_PROMPT.md，备份backups/salt-tea-art。29898构建退出0/tmp/salt-tea-art-build.log，安装86267退出0启动22920；实际补给栏缩略图及详情图显示，来源第16关街区封锁、恢复20%最大生命、持有1正确，salt-tea-art-verified.png。未改效果，当前补给盐茶详情，无构建录像。

正式补给入口缺口修复：此前只显示止痛膏，镜银药膏/盐茶核心已有实现却无按钮。现三种按实际库存显示位图，复用onConsumeSupply保存；满生命禁用治疗、盾满禁用药膏；导航条件计入补给数量。备份backups/all-earned-battle-supplies。84216构建成功，安装79506成功启动26531。mirror-tea-battle-supplies.mov开场点盐茶未扣、药膏1→0，实际首次106攻击显示扣6；之后普攻失败，盐茶仍1。再次正常进入Q20药膏未恢复，受伤后盐茶点击消失并1→0，salt-tea-battle-retry.mov、mirror-tea-after-use.json。回血瞬间尚待抽帧，不以消耗代替数值验证。已主动退出主城，录像均停，无构建运行。
