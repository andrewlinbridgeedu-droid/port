# 第1—10关敌人差异与资产缺口

本文是关卡导演用的短执行表。`已有事实`来自当前 `ChapterOneContent.swift`、交接报告及 `UnityBattleSource/Assets` 文件名；`建议`是后续制作选项，尚未视为批准实现。数值与规则仍以战斗核心为准。

## 逐关差异表

|关卡|当前敌人/已有攻击状态|建议的可辨识变化（复用现有攻击/状态）|已有资产与当前可见性|缺口/验收重点|
|---|---|---|---|---|
|1 雨夜醒来|1×空壳守卫（`strike`、`guard`）；单牌教学、解除封印|保持单体；让`guard`时胸口身份牌亮起，`strike`时短促抬臂，作为“读意图”基准|`ClockGuard`模型及 Combat Stance、Axe Spin、Charged Axe Chop、Parry、Walking/Running FBX 已有；守卫已用于战斗|建议只做姿态/灯光差异；需确认教学状态与模型动作同步|
|2 雾都幽灵|2×雾都幽灵，同一敌人定义；两种独立攻击：`fog-ghost-chime`、`fog-ghost-wisp`|两只保持同一模型，左侧固定冷青/雾钟震魂，右侧固定淡紫/幽雾追魂；施法前分别显示钟纹/三缕追魂雾|`FogGhost/Ghost.fbx`、贴图及两个 projectile registry 已有；颜色和施法脚本已有记录|不新增模型；需验证两只目标、颜色、攻击来源不会串位|
|3 循名而来的猎犬|1×失名猎犬；首次追猎，规则标签`hell_hound`/`stolen_name`|使用同一猎犬的“远处锁定→短扑→撤回”节奏；以`memory_breath`作为威胁预告但不提前引入第4关完整连段|`HellHound` Emberwolf FBX（含 Walking）、`HellHoundModel.prefab`/profile、火球资源已有；交接称已接入但火球最终美术仍待回归|同犬连续性必须保持；需确认首次击退与退场淡出|
|4 猎犬试探|同一只猎犬；`bite`→`charge`→`memory_breath`，假面/误认反制|把`bite`做成近身扑咬，`charge`做明显停顿与口部蓄光，`memory_breath`沿已有火球轨迹喷出；三拍固定成识别点|猎犬模型、扑近协程、`HellHoundEffekseerFireball`及 FireBall/FireOnly 资源已有|蓄力接触回调曾导致卡住，需实测动作、回调和火球轨迹；不另造“新猎犬”|
|5 纸人之夜|仍是同一只猎犬；纸人代身一次性致命保护；`defensiveResponse`|猎犬沿用第4关三拍但首次认定纸人时转向纸人/纸屑；纸人破碎是本关视觉标签，不能变成新敌人|猎犬已有；纸人是规则/遗落物（`relic_paper_raincoat`），未见独立纸人敌方模型资产|纸人发动形态的视觉来源和一次性回调需验收；不重复发放遗落物|
|6 犬吠中的名字|同一只猎犬收尾；`bite`/`name_hunt`，假面承接后兑现破绽；解除追猎|将`name_hunt`固定为低血目标锁定并连续扑杀预告；命中后短暂暴露追索印记，作为“解除追猎”的结束符|同一 HellHound 资产；`ClockHoundReverseTideVFX.cs`等猎犬特效脚本已有；独立认名扑杀动作未见资产|需确认第6关不再出现记忆蛭；破绽只消耗一次，剧情与退场一致|
|7 空白身份牌|2×空壳守卫 + 1×寄忆核心；守卫`strike`/`guard`，核心有`memory_strike`、`archive_repair`、`calibrate`、`transfer`；目标核心优先|守卫做左右“护栏”站位并优先`guard`；核心固定后排，施放`archive_repair`时发出记忆眼/写入光；玩家点核心后必须明确选中核心|守卫、`ClockCore`（Egg FBX、prefab/profile）、`target-memory-eye`贴图已有；透明目标按钮与选中环已加但第7关主动切换待回归|需实测核心点击区域、受伤对象和核心/守卫攻击来源一致；不把核心写成新模型|
|8 不属于我的名字|1×记忆蛭 + 1×空壳守卫；记忆蛭`parasite`/`transfer`/`bite`，两格身份错置教学|记忆蛭悬浮、低位游移并优先`transfer`；守卫承担可读的`guard`；达到4层误认后以`错位`延迟其下一次行动，视觉上用蛭短暂停滞区分|`MemoryLeech/MemoryLeech.fbx`、`MemoryLeechModel.prefab`/profile及 Idle/Cast/Hit/Death 运行时别名修复已存在；交接报告称最新导出未重测|必须重测模型显示、动画、Cast/Death、绿色弹道、死亡缩小/脓水和1秒渐隐；两格选择上限仍需修复|
|9 被改写的证词|1×抄录傀儡 + 1×寄忆核心；傀儡`fortify`/`calibrate`/`slam`，核心支援/转存；两格|先打核心的读图关系：核心施放支援时亮“寄忆”光，傀儡`fortify`显示护甲环，`calibrate`显示校准刻线，`slam`显示重锤落点；这三种已有意图作为傀儡识别链|核心已有；抄录傀儡当前复用机械守卫（交接报告）；未见独立 puppet 模型|独立傀儡模型缺；第9关4点正式天赋也未实现，不能用沙盒天赋替代；需标注复用模型为临时|
|10 失踪者名单|1×猎犬 + 1×抄录傀儡；规则标签`K04`/`four_slots`；当前 Unity 编排为猎犬右侧+守卫左侧|猎犬保留第6关“锁定/扑杀”但加入第4关火球预告；傀儡固定承担`fortify`→`calibrate`→`slam`，形成“猎犬追索、傀儡改写”的交替威胁；两敌血条/选中环颜色分开|猎犬、守卫复用编排（`UseLateEscort(true)`）已有；抄录傀儡仍无独立模型；四格目前有规则测试证据，UI未验收|需录像确认默认目标、contact、先后死亡与真实胜利；四格扩容和第10关前置对白需实机验收；“另一只猎犬”是剧情事实，模型可复用但不应声称新资产|

## 现有资产清单（仅本批涉及）

- 守卫：`UnityBattleSource/Assets/Models/ClockGuard/`，已生成 `ClockGuardModel.prefab`、`ClockGuardVisualProfile.asset`。
- 雾灵：`UnityBattleSource/Assets/Models/FogGhost/`；攻击 registry 为 `projectile-ghost-wisp-v1` 等。
- 猎犬：`UnityBattleSource/Assets/Models/HellHound/Meshy_AI_Emberwolf_quadruped/`，已生成 `HellHoundModel.prefab`、`HellHoundVisualProfile.asset`；已有 HellHound 火球资源。
- 记忆蛭：`UnityBattleSource/Assets/Models/MemoryLeech/MemoryLeech.fbx`，已生成 `MemoryLeechModel.prefab`、`MemoryLeechVisualProfile.asset`。
- 寄忆核心：`UnityBattleSource/Assets/Models/ClockCore/`，已生成 `ClockCoreModel.prefab`；另有记忆眼目标贴图。
- 抄录傀儡：没有独立模型文件；当前使用守卫外观/编排，是临时复用事实。

## 给 Meshy 的抄录傀儡规格（建议，待用户确认）

用途：替换第9、10关中当前复用的守卫外观，表达“正在把证词校准成统一版本”的机械抄录执行体。它不是新敌人规则；继续承载已有 `fortify`、`calibrate`、`slam` 三种意图。

造型：人形机械抄录员，窄肩、厚胸腔、两臂不对称；一侧为刻字/校准臂，另一侧为沉重落锤臂；胸前有可发光的竖向记录板，脸部用无表情的黑色空面配一条水平校准缝。齿轮、纸页/金属条只作轮廓细节，避免长披风和细小悬空件。

尺寸与坐标：站立高度约 1.8 m，脚底到头顶；战斗占地宽约 0.75 m、深约 0.55 m。原点在双脚地面中点，模型前方朝 Unity `-Z`，统一人形比例；提供可缩放的单一根节点，不在导出文件中烘焙偏移。

动作：必须提供 `Idle`、`Hit`、`Death`、`Fortify`（护甲板闭合/亮起）、`Calibrate`（刻字臂扫描校准线）、`Slam`（落锤下砸）五组可循环/可单次播放动作；建议另附 `Walk` 作为入场动作。动作根骨骼和命名要稳定，避免只交付一段合并动画。

挂点：`TargetAnchor` 位于胸前记录板中心；`AttackOrigin` 位于刻字臂末端（`Calibrate`）并允许落锤臂末端（`Slam`）单独取点；`HitRoot` 位于胸腔；脚底提供 `GroundAnchor`。挂点需随动画骨骼移动，便于原生血条、选中环和接触回调对齐。

交付建议：一份带骨骼的 FBX 或 GLB、独立贴图（BaseColor/Normal/Roughness/Metallic，必要时 Emission）、动作列表及一张正面/侧面预览。以上是资产请求规格，不代表用户已批准制作或已纳入当前版本。
