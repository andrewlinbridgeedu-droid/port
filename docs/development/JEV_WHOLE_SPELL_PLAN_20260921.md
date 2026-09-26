# 全游戏法术整招梳理 · Jev审核计划

## 结论

Jev已实际接通，返回模型 `jev-1.13.0`。本次计划覆盖 **89项整招/状态/附效**：79项既有基线（主角8、正式塔14、主线31、通缉11、白名单遗落物10、独立试演3、保留库2）＋另一任务正在接入的D07–D11新增10招。不是89个已完成攻击技能。
原102条审计记录全部映射；85段现有总览MP4全部归位。旧目录27项单列附录，不重新开放。

优先：B04覆写 → B06锁甲厚度 → B06飞行中段。B02最新金纹版作为保护基准；B06认可爆炸、翠焰认可蓄力、错步认可残影、D02盐晶主体保留。

本次是制作计划，不改Unity/Swift、不构建或装机。候选创作由主agent撰写，Jev审核文字契约、处理路线和已知缺口；Jev没有看视频像素，不提供视觉合格率。

[交互总表与实录](../../output/jev-spell-plan-20260921/index.html) · [完整数据和逐项Jev回执](../../output/jev-spell-plan-20260921/review.json)

## 最新用户约束 · 2026-09-21

> 不准有这种规则的几何图形

全部89项，从身体蓄力、飞行、命中、生效/持续到收势均适用。

本条覆盖旧方案中冲突的轮廓保留要求；伤害、目标、真实contact不变。其它已认可视觉不因此一律推倒，仍须检查是否出现禁用外形。

- 禁用：直边方框、矩形光板/光毯，以及能一眼看出平面边界的发光贴片。
- 禁用：完整规整圆环、规整多边形、等距扇骨/平行光条、机械重复的锯齿等图元式能量主体。
- 禁用：给规则壳体加纹理、噪点、碎光，或仅随机移动顶点后仍保留规则大轮廓。

制作方向：用各招自身的墨锋、金纹、火焰、裂口等身份组织少量可读主体：不等宽、不等长、非镜像的轮廓，沿运动方向卷曲、前后错层，亮暗和厚薄连续变化；边缘自然分岔、撕散或蚀散。保留强度、范围和命中撑开，不统一变成烟雾或碎屑。

验收补充：

- 全景与近景均检查蓄力、飞行、接触峰值、持续、退场，不只挑峰值截图。
- 正常速度与关键帧中不得出现方框、齐边光板、等距骨架或规则封闭外轮廓。
- 边缘扰动后仍须读出该招独有主体、运动和体积，不能靠过曝、烟雾或密集粒子遮住问题。

[用户否定的截图](../../output/jev-spell-plan-20260921/feedback/user-rejected-regular-geometry.png)。用户截图反馈对应B04计划页。截图确立外观禁令；未仅凭截图断言具体网格、粒子节点或着色器根因。

新增用户几何禁令、B04修订及普攻优化追加未重新请求Jev；既有19次回执只对应之前的原始文字方案，不能用于证明新方案已审或视觉通过。

本轮只更新计划、页面与项目约束；未修改Unity/Swift，未构建、装机或重录。

## 普攻追加优化

> 普攻也可以优化一下

主角秘仪飞牌从仅保留核对改为明确精修；敌方已有普通/试探攻击按自身武器与身体核对，不给每只怪新编通用普攻。

- 动作先有短蓄势，肩肘带动翻腕出牌，衣袖跟随；不增加长蓄力，不拖慢攻速。
- 飞牌看得到牌面细节、转动侧边和前后遮挡，尾迹短而渐细、不等宽；不铺规则光板、闭环或整屏牌云。
- 命中沿实际切入方向短促撑裂，少量金紫碎光迅速散去；保持打击感，但亮度、面积与持续时间低于大招。
- 连打时每次主形清楚，上一击尾效及时退净；不加每次普攻重停顿或大幅震屏。

主角现行0.58秒contact保持，55ms局部视觉缓冲只作旧版对照，不改全局时间、伤害、攻速、目标数或命中次数；错步保持独立效果。

敌方已有普通/试探条目同步核对：

- M01：空壳守卫赤弧斩：剑臂收放与刃口短裂连贯，不能只有赤色光片移动。
- M05：早犬普通火球：贴胸颈/嘴部短聚，熔核与焰壳有层次；持续步态、远处站位保留。
- M06：Q4试探小火球：紧凑短促，和双焰大火球拉开蓄力、尺寸及爆发级差。
- M17：记忆蛭三次试探：先补真实连续样本，按三次短促口器动作核对，不挪用吞名大蓄力。
- B03A：溺钟海盗普通打击：先核入口并补录，按当前武器/水刃做窄而短的送击和盐水碎光。
- B05A：赤丝裁衣人普通打击：两次短提腕、短丝划击、断丝退净；不能提前变成束缚笼。

普攻专项验收：

- 以现有攻速连续至少5次普攻，检查身体衔接、尾光叠加、轮廓清晰和面板遮挡。
- 单/双/四敌阵容中仍只命中本次有效目标；切换目标、目标途中退场不伪造改投或重复contact。
- 分别验证命中前取消、命中后取消、死亡、跨波和重试；保留当前伤害与接触契约。
- 交主角普攻旧/新同镜头实录，再与错步及大招并列看力度级差；不能用规则测试当视觉认可。

源码核对：[FoolBasicTarotVFX.cs](../../UnityBattleSource/Assets/Scripts/FoolBasicTarotVFX.cs) · [TarotNova.shader](../../UnityBattleSource/Assets/Resources/Effects/Fool/TarotNova.shader) · [BattlePrototype.cs](../../UnityBattleSource/Assets/Scripts/BattlePrototype.cs)

## Jev实际结果与复核（新反馈之前的原始方案）

既有79项审核16次请求/237个判断，源码核对后3项定向重审1次/9个判断；新增塔怪10招2次/30个判断。合计19次审核请求/276个判断，均HTTP 200。另有1次连接探针，不算进计划审核。
审核用量：input 125,989 / output 8,988 tokens；原请求/响应无凭证落盘。

|Jev原始最高概率路线|项数|解释|
|---|---:|---|
|先核对整招|64|处理建议，不是视觉结论|
|保留与回归|6|处理建议，不是视觉结论|
|沿主体精修|6|处理建议，不是视觉结论|
|局部重做|2|处理建议，不是视觉结论|
|保留库／暂不接入|11|处理建议，不是视觉结论|

54项路线置信度低于0.8，保留完整概率而非包装成通过。证据不足项先核对已有实录/补录；保护项服从用户要求；试演和旧库不因此开放。
缺口分数0–3衡量文字里已知问题，不是画面分数，也不是本次测试通过率。没有专项视频≠法术不存在或不合格。

源码复核与并行增量：

- M03/M04：按primary/secondary源码改正幽灵录像映射，不按赤红颜色判法术。
- M10：补Q19 recover降档，不能复制Q5单调递增或误报固定三跳。
- 三项修订已重新请求Jev；其它76项基线输入与原回执逐字段一致。
- 终检发现任务“接入教会塔小怪与法术”并行写入D07–D11：另增10招并补跑Jev，不将旧六怪基线外推为当前全部源码。

## 完整法术的统一口径

- 本次只交全法术计划：蓄力/准备、出手、命中、持续与收势属于同一招；录像片段数不等于技能数。
- 保留伤害、冷却、段数、目标数、真实contact和已认可视觉；只有明确未解决部分优先重做。
- 当前记录只是文字证据，Jev未看视频像素；不能输出画面好坏验收、不能将API成功称视觉通过。
- 攻击短停—极速撑开—快速收回；状态/防御/治疗只用对应生效语义，禁止伤害爆炸。
- 主体少而大片，原画细节沿曲面走，贴身蓄力与身体动作结合；不统一绿焰，不裸线/贴片/旋转换色交差。
- 每个真实目标完整独立实例；稳定ID绑定，公共contact/镜头冲击不倍增；目标退场不改投。环境雾不按敌数复制。
- 局部视觉clock不改全局时间/Animator/伤害时钟；每招验证取消、死亡、跨波、重试恢复。
- 历史审计source_facts只供溯源，current/locked的最新覆盖优先；候选改法不能反推当前缺陷。
- 原102项/85录像基线塔为D01-D06；新增D07-D11由另一任务并行接入，本表另列制作中增量，D00不加回。10项遗落物白名单实际开启，不能因relicsEnabled=false说全部停用。

## 制作批次

|批次|范围|实际工作|完成门槛|
|---|---|---|---|
|A 先完成通缉样板|B04 → B06 锁甲 → B06 飞行；B02 作保护基准|B04先移除用户否定的规则几何轮廓，再解决主体/中段厚度；同一招交完整起手至收势视频，不改已认可命中。|全阶段无规则几何图元式轮廓；B04不规则卷墨、B06立体锁甲/锚芯飞行可读；B02不回退；正常/取消回调与持续handle清理通过。|
|B 主角完整施法|7张正式技能＋手动假面（普攻单列D批精修）|沿牌、面具、印章、双影、幕布身份精修；错步和无名优先验证真实目标集合。|1/2/3/4敌阵容下目标正确；错步最多2敌、追猎同敌2段、全体宣告无伤害；无多实例回调倍增。|
|C 塔与状态型样板|六塔恶魔、剩余通缉；翠焰/机械盾|身体蓄力附着、材质细节、攻击瞬间撑开；治疗、强化、防护使用自身语义。|D04/D06三招仍有不同姿态和轮廓；D03/D05固定受益者退场取消；持续状态不反复播放命中爆炸。|
|D 普攻精修与主线全覆盖|H00秘仪飞牌优先；幽灵、早/晚犬、核心、维娅、机械敌与Boss|普攻明确打磨动作、飞牌厚度、局部短命中与收势；敌方普通/试探攻击按身份核对，再补主线完整施法与缺漏路由。|连续5次普攻不叠满屏尾效，单/双/四敌只中当前目标；原伤害/攻速/0.58秒contact保持。另验证双焰两次接触、飞臂装回、Q5/Q19毒雾分支及Boss退场。|
|E 遗落物真实反馈|其余9项白名单附效|先核对原生事件与Unity桥，再补局部生效反馈；不把数值被动包装成伤害技能。|触发、落空、清算、受益/攻击来源绑定正确；停用旧物不开放。|
|F 试演与旧库隔离|虹翼/霜雷/裂界＋隐藏/未解锁技能|保留并完善对照；三招正式目标/槽位未决定，不擅自替换现有技能。|作为可回看试演交付；正式接入需有明确规则，不能用模拟拍点当已上线。|
|G 并行新增塔小怪|D07–D11共10招；另一任务负责制作|本计划补齐当前first/second方案与整招验收边界；不修改另一个任务的源码。|等待该制作批自己的全景/近景、回调/取消/死亡/重试回执；当前只做增量计划，不能当完成。|

## 每招交付与验收

1. 开工前备份当前源码、原画、已有视频；记录该招唯一修改负责人。
2. 同一条视频从身体起手/蓄力开始，到释放、contact、生效/持续和收势结束。持续状态另给足够长样本验证不重复爆炸，但仍属于同一行。
3. Unity全景与近景实际录制；旧/新同机位同拍点对比，附正常速度/半速与接触前、保持、撑开、回收关键帧。GIF由实录转出，不代替MP4细节。
4. 保留真实contact与数值；测试正常一次回调、contact前取消零迟到回调、contact后取消不重打、死亡/跨波/重试恢复；骨骼、材质、网格、粒子handle清理。
5. 目标测试：单/双/三/四敌场景验证真实集合；状态不伪造伤害，固定受益者离场不改投；共享镜头/震动只一次。
6. 先完成整组定向检查与实录，不每招停下来问继续。规则通过、Unity表现、用户视觉认可、原生构建和iPhone 13验收分列记录。

## 逐招候选方案

### B02 · B02 背架收尸人·金纹束缚

通缉 / 正式/源码可达 / 批次A / 主角1人；直伤后有限2跳

- 原始证据：最新binding-detail版：已按用户要求加宽约25%、增加错层短纹和细节；8项录制/17项安全检查通过。视觉待复核，旧棕带/裸线否定不能套到最新版。
- 保护边界：保留金色镂空纹理、2条细分曲面、5帧/45ms节奏和当前面积；不回退棕带/裸光线，不让持续状态重复炸。
- 当前候选改法：保留最新金色镂空曲面；起手到持续状态用同一纹样语言，不继续叠中央白光。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留与回归，路线置信度 0.50；缺口 1.00/3；文字矛盾概率 0.11。
- 执行判断：保留与回归。优先服从最新用户保护边界；已认可阶段保留，未认可衔接按本行候选复核，不外推整招认可。

|阶段|本招方案|
|---|---|
|起手与蓄力|金纹贴背架/手臂卷聚，准备属于本招|
|主体与运动|两条细分金纹曲面缠入目标|
|接触或生效|保留5帧停顿、45ms撑开、22主碎光/36细金屑/9二闪|
|持续阶段|保留加宽25%的释放和更大持续覆盖；持续只游走收紧，不重复爆炸|
|收势与退场|金纹按纹理蚀散，绑定源退场及时解除|

实录：[bounty-b02-bind](../../output/all-spells-polish-20260921/bounty-b02-bind.mp4) · [bounty-bindings-state](../../output/all-spells-polish-20260921/bounty-bindings-state.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-13.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchSpellVisual20260917.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2508`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchBounties.swift:105`；`docs/development/BINDING_DETAIL_20260921.md`

### B04 · B04 铜笔伪造者·覆写

通缉 / 正式/源码可达 / 批次A / 主角1人；依最近技能重复情况结算

- 原始证据：金属块方案已被用户否定并停用；当前Effekseer素材试配仍偏轻薄，未达到原画厚度。B06命中爆炸已获认可，未解决的是飞行中段/锁甲。
- 保护边界：保留铜笔/覆写身份、铜绿色调、真实单目标与原contact；不恢复金属块，不以泛用烟团替代。此前保护项若与本次明确禁令冲突，以禁令为准。
- 当前候选改法：重做规则轮廓：铜绿墨锋改为不等宽、不等长的错层卷曲主体，浓淡墨纹沿曲面流动、边缘自然撕散；不再用方框、光板或完整规整印层。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：局部重做，路线置信度 0.60；缺口 1.96/3；文字矛盾概率 0.13。
- 执行判断：局部重做。用户已明确否定截图所示规则几何形状，不是仅偏轻薄。原方案中仅补厚/加印层的描述不足，新轮廓必须满足全阶段禁令。

|阶段|本招方案|
|---|---|
|起手与蓄力|流光沿铜笔关节、笔端汇聚，贴合身体动作形成不等长的卷墨；不围身体生成方框或规整圆环。|
|主体与运动|少量厚薄不同的铜绿墨锋前后错层翻卷推进，轮廓偏斜、断续且不等宽；看不到矩形边界、等距肋条或匀速整板平移。|
|接触或生效|真实contact处墨锋压入后不对称撑开，沿原纹理撕成有主次的短裂片；不出现完整方印、规则轮盘，不改伤害结算。|
|持续阶段|保留局部不规则墨痕与细碎余光，浓淡变化后收紧；无矩形地毯、闭合几何框，也不新增持续攻击。|
|收势与退场|主体从薄边、分岔逐处蚀散，少量碎墨跟随原运动方向回收；不整块平板淡出，清理所有粒子handle。|

最新状态：截图所示规则几何轮廓已被用户否定；新方案待制作

已有旧版实录，仅作问题对照；用户已否定截图中的规则几何轮廓。不是新方案效果。

此前送Jev的原方案（仅溯源，受最新反馈覆盖）：优先重做仍轻薄的飞行/主体：用现有Effekseer铜绿墨锋和覆写印层，加雕纹透明原画作内部细节。

实录：[bounty-b04-overwrite](../../output/all-spells-polish-20260921/bounty-b04-overwrite.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-14.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchSpellVisual20260917.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2508`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchBounties.swift:105`；`UnityBattleSource/Assets/Scripts/BountyEffekseerTravel20260921.cs`

### B06G · B06 无灯押船人·锁甲

通缉 / 正式/源码可达 / 批次A / 自身防御

- 原始证据：金属块方案已被用户否定并停用；当前Effekseer素材试配仍偏轻薄，未达到原画厚度。B06命中爆炸已获认可，未解决的是飞行中段/锁甲。
- 保护边界：使用现有Effekseer素材打磨；禁止恢复BountyForgedSpell金属板/裸方块。B06攻击只改飞行等未认可段，保留AnchorRupture命中。
- 当前候选改法：优先补厚度：三层错位的蓝灰能量甲沿肩/胸/前臂贴合，Effekseer担当流光而非整片薄罩。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：沿主体精修，路线置信度 0.44；缺口 1.93/3；文字矛盾概率 0.10。
- 执行判断：沿主体精修。Jev精修/重做概率接近；落到具体动作是保留Effekseer并重建贴甲体积/前后层，不恢复金属块。

|阶段|本招方案|
|---|---|
|起手与蓄力|双臂内收，甲缝分区充能|
|主体与运动|能量甲曲面有前后遮挡和边缘厚度|
|接触或生效|防御成立时内扣亮起，禁止伤害爆炸|
|持续阶段|分区旋流与星闪持续播放，不播完空白|
|收势与退场|防御解除依部位退光，骨骼/材质恢复|

实录：[bounty-b06-guard](../../output/all-spells-polish-20260921/bounty-b06-guard.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-15.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchSpellVisual20260917.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2508`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchBounties.swift:105`；`UnityBattleSource/Assets/Scripts/BountyEffekseerTravel20260921.cs`

### B06H · B06 无灯押船人·重锚冲击

通缉 / 正式/源码可达 / 批次A / 主角1人

- 原始证据：金属块方案已被用户否定并停用；当前Effekseer素材试配仍偏轻薄，未达到原画厚度。B06命中爆炸已获认可，未解决的是飞行中段/锁甲。
- 保护边界：使用现有Effekseer素材打磨；禁止恢复BountyForgedSpell金属板/裸方块。B06攻击只改飞行等未认可段，保留AnchorRupture命中。
- 当前候选改法：只重做起手到飞行中段的体积/纹样与惯性；接触AnchorRupture保留。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：局部重做，路线置信度 0.64；缺口 1.88/3；文字矛盾概率 0.09。
- 执行判断：局部重做。最新记录明确当前轻薄问题尚未解决；只重做未认可阶段。与Jev最高概率建议一致。

|阶段|本招方案|
|---|---|
|起手与蓄力|重锤/船锚身份聚能，身体承担重量|
|主体与运动|非金属方块的深蓝旋流包裹锚形主芯，前后厚薄明显|
|接触或生效|沿用用户认可AnchorRupture爆炸，不换主体|
|持续阶段|沿原爆炸节奏快速退光，不持续增亮|
|收势与退场|飞行和爆炸owner统一清理，取消不迟到contact|

实录：[bounty-b06-heavy_strike](../../output/all-spells-polish-20260921/bounty-b06-heavy_strike.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-15.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchSpellVisual20260917.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2508`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchBounties.swift:105`；`UnityBattleSource/Assets/Scripts/BountyEffekseerTravel20260921.cs`

### H01 · 错步穿行

主角 / 正式/源码可达 / 批次B / 最多2敌；每目标2个完整主角残影

- 原始证据：用户曾认可双目标新版；9/21已拆独立目标实例并录单/双目标，新微调仍需对照。
- 保护边界：不回退成一路三个残影；不减掉既有绚丽范围；次目标50%文案与代码差异只核对，不能借视觉任务改数值。
- 当前候选改法：保留已认可紫金裂隙和较淡残影；补整招与1/2目标对照，不重画主体。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留与回归，路线置信度 0.68；缺口 0.74/3；文字矛盾概率 0.09。
- 执行判断：保留与回归。优先服从最新用户保护边界；已认可阶段保留，未认可衔接按本行候选复核，不外推整招认可。

|阶段|本招方案|
|---|---|
|起手与蓄力|低身化影、贴身细裂光|
|主体与运动|一目标一路两完整残影；两目标独立两路|
|接触或生效|每目标各自裂开；保留105ms/42ms现有样本，公共contact一次|
|持续阶段|仅短裂隙尾迹，不增加攻击|
|收势与退场|各owner独立淡出并恢复主角|

实录：[hero-01](../../output/all-spells-polish-20260921/hero-01.mp4) · [hero-01-dual](../../output/all-spells-polish-20260921/hero-01-dual.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-01.response.json)

源码/记录：`docs/development/TARGET_INSTANCES_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700`

### H04 · 身份错置

主角 / 正式/源码可达 / 批次B / 选中1敌；按真实条件发生状态或伤害

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：双身份面保持对向错开；补面具浮雕、薄厚和不对称卷边，以错位而不是通用爆炸表达。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.51；缺口 0.99/3；文字矛盾概率 0.09。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|手指翻转身份面，掌侧亮起|
|主体与运动|两张身份面前后错层交叠|
|接触或生效|真实状态生效时错开；只有实际伤害才允许伤害反馈|
|持续阶段|短身份裂纹附着原目标|
|收势与退场|身份面溶边回卷，不残留选敌标记|

实录：[hero-04](../../output/all-spells-polish-20260921/hero-04.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-01.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700`

### H05 · 伪证烙印

主角 / 正式/源码可达 / 批次B / 选中1敌；后续烙印不扩目标

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：把印纹压入感做清楚；11张证据碎片用纤维/焦边细节，保持印面可读。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.45；缺口 1.00/3；文字矛盾概率 0.08。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|压腕聚印，金纹沿印章轮廓汇聚|
|主体与运动|单枚立体证印向目标压落|
|接触或生效|现有85ms缓冲后压痕横撑、碎证侧喷|
|持续阶段|烙印弱脉动由实际状态驱动|
|收势与退场|碎证回收淡出，印痕随状态清除|

实录：[hero-05](../../output/all-spells-polish-20260921/hero-05.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-01.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700`

### H06 · 错影追猎

主角 / 正式/源码可达 / 批次B / 同一敌人2段；不是2个目标

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：保留原衣装与立体明暗；两次穿行分拍，紫/青边光区分，不把人影涂成平面色块。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.39；缺口 0.99/3；文字矛盾概率 0.08。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|两侧影像随肩腰分离|
|主体与运动|同一目标前后两次穿透，衣摆有纵深|
|接触或生效|各段贴其真实结算；不因两残影重复回调|
|持续阶段|第二道尾流短于第一道，层次交错|
|收势与退场|完整人影渐退并收回主角位置|

实录：[hero-06](../../output/all-spells-polish-20260921/hero-06.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-01.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700`

### H07 · 荒谬归结

主角 / 正式/源码可达 / 批次B / 选中1敌；基础与条件追加都在此目标

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：保留高清牌面与实体边；把牌面纹理、卷边碎片和落切动作连成一个强拍点。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.89；缺口 0.99/3；文字矛盾概率 0.09。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|双手托起巨牌，牌沿聚光但不遮脸|
|主体与运动|巨牌带重量落切，侧面保持可见|
|接触或生效|沿切口释放14块错深度牌片；140ms/45ms只作现有对照|
|持续阶段|短牌纹余辉，不增加额外目标|
|收势与退场|碎片快速回收；检查面板和敌人未被大片白光盖住|

实录：[hero-07](../../output/all-spells-polish-20260921/hero-07.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-02.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700`

### H08 · 反客为主

主角 / 正式/源码可达 / 批次B / 1敌；驱散/误认状态，返回伤害0

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：做成被反拉的幕布与翻转舞台边界；让驱散可读，不用爆伤闪光。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.93；缺口 1.00/3；文字矛盾概率 0.08。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|手掌外翻拉起两侧卷幕|
|主体与运动|两片厚薄不同曲幕向外反转|
|接触或生效|在真实状态拍点撕开窄窗口；无伤害爆炸|
|持续阶段|敌人中心保持清楚，只留弱状态边缘|
|收势与退场|卷幕沿折线收回，不遮全屏|

实录：[hero-08](../../output/all-spells-polish-20260921/hero-08.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-02.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700`

### H10 · 无名宣告

主角 / 正式/源码可达 / 批次B / 本次全体存活敌人；状态而非直接伤害

- 原始证据：9/21正式逐目标改造已含1/2/4目标检查；不是固定三人，四目标过亮已做过首轮修正。
- 保护边界：全体不裁成3敌；不向新分裂目标临时补投；不把状态声明改伤害技能。
- 当前候选改法：每个实际目标完整面具/幕布实例；优先保留四目标降亮度后的可读性。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.35；缺口 0.95/3；文字矛盾概率 0.09。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|主角展开宣告姿态，一次公共起手|
|主体与运动|各稳定ID独立面具贴近，不把三面具当三目标|
|接触或生效|一次公共contact，所有真实收件人状态同步|
|持续阶段|目标各自保留轻状态纹，不放伤害跳字|
|收势与退场|退场只清自身实例，其余继续|

实录：[hero-10](../../output/all-spells-polish-20260921/hero-10.mp4) · [hero-10-all-four](../../output/all-spells-polish-20260921/hero-10-all-four.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-02.response.json)

源码/记录：`docs/development/TARGET_INSTANCES_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700`

### R01 · 手动假面

遗落物附效 / 正式白名单附效 / 批次B / 自身；4秒最多挡2次直伤、18秒冷却；持续伤害不占次数

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：十道裂纹第十次正常生效后失效；Q3/Q4豁免；不复用旧12秒规则。
- 当前候选改法：保留实体瓷面、完整幻影与17枚破片；使用、拦截、失效合成一行。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.69；缺口 0.99/3；文字矛盾概率 0.11。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|由手动点击升起瓷面|
|主体与运动|幻影在主角防护位置稳定成形|
|接触或生效|每次实际拦截才后退回弹和短金闪|
|持续阶段|按真实剩余次数/4秒显示；每次使用永久裂纹由账本决定|
|收势与退场|结束瓷面裂解；不对敌人制造受伤|

实录：[manual-mask](../../output/all-spells-polish-20260921/manual-mask.mp4) · [manual-mask-hit](../../output/all-spells-polish-20260921/manual-mask-hit.mp4) · [manual-mask-break](../../output/all-spells-polish-20260921/manual-mask-break.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-02.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:268`

### B01 · B01 缺齿剑·伏击

通缉 / 正式/源码可达 / 批次C / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：剑口缺齿与斜切主体关联；起手不套通用蓄力环。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.86；缺口 1.00/3；文字矛盾概率 0.08。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|压肩伏势，刃口逐段点亮|
|主体与运动|一条不规则缺齿剑痕突进|
|接触或生效|缺齿处错位爆开，短金属火花侧喷|
|持续阶段|少量剑痕碎屑|
|收势与退场|收剑回位，不留持续攻击|

实录：[bounty-b01-ambush](../../output/all-spells-polish-20260921/bounty-b01-ambush.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-13.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchSpellVisual20260917.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2508`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchBounties.swift:105`

### B03A · B03 溺钟海盗·普通打击

通缉 / 正式/源码可达 / 批次C / 主角1人

- 原始证据：源码/规则有此项；85段总览缺少本项独立完整证据，先核对路由与当前整招。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：现有85段只录重击；先补普通strike，控制强度与动作不盖过重击。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 1.00；缺口 1.11/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。

|阶段|本招方案|
|---|---|
|起手与蓄力|海蓝躯壳短聚|
|主体与运动|窄水刃/当前实际武器短送|
|接触或生效|小范围盐水碎光|
|持续阶段|无额外持续层|
|收势与退场|回位；按源码实际路由决定是否可与重击共享材质|

普通/试探攻击追加核对：溺钟海盗普通打击：先核入口并补录，按当前武器/水刃做窄而短的送击和盐水碎光。

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-14.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchSpellVisual20260917.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2508`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchBounties.swift:105`

### B03B · B03 溺钟海盗·重击

通缉 / 正式/源码可达 / 批次C / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：海蓝水墙要有翻卷纵深、断浪和盐沫，不能是透明矩形。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.77；缺口 1.00/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|身体压低，水纹沿躯壳翻起|
|主体与运动|一片不对称厚浪定向扑出|
|接触或生效|浪头断裂大片外撑，细沫穿插|
|持续阶段|低位薄水雾迅速退去|
|收势与退场|水墙塌缩消散，身体复原|

实录：[bounty-b03-heavy_strike](../../output/all-spells-polish-20260921/bounty-b03-heavy_strike.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-14.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchSpellVisual20260917.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2508`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchBounties.swift:105`

### B03E · B03 护航亡魂·攻击

通缉 / 正式/源码可达 / 批次C / 主角1人；各护航实例独立

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：保留独立护航攻击并验证多施法者不串owner；不把护盾状态当攻击起手。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.99；缺口 0.99/3；文字矛盾概率 0.09。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|各亡魂自身聚能|
|主体与运动|自身窄雾流朝主角推出|
|接触或生效|真实命中对应施法者短旋散|
|持续阶段|小段尾雾不叠全屏光|
|收势与退场|各自回位、各自清理|

实录：[bounty-escort-attack](../../output/all-spells-polish-20260921/bounty-escort-attack.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-15.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchSpellVisual20260917.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2508`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchBounties.swift:105`

### B03S · B03 护航关系·持续护卫

通缉 / 正式附效 / 批次C / 被护卫的固定敌方实例

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：列为护卫关系附效，不伪装主动攻击法术；关系变化时平滑退盾。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.99；缺口 1.00/3；文字矛盾概率 0.09。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|关系建立时海蓝鳞光靠近受护者|
|主体与运动|贴体盾片有深度间隙|
|接触或生效|保护成立只内收亮起|
|持续阶段|根据实际escort状态续播，不能自行授予护盾|
|收势与退场|护卫消失/关系解除时退去|

实录：[bounty-escort-state](../../output/all-spells-polish-20260921/bounty-escort-state.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-15.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchSpellVisual20260917.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2508`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchBounties.swift:105`

### B05A · B05 赤丝裁衣人·普通打击

通缉 / 正式/源码可达 / 批次C / 主角1人；pattern两次strike

- 原始证据：源码/规则有此项；85段总览缺少本项独立完整证据，先核对路由与当前整招。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：补两次普通打击连续录像；强度低于赤丝束缚，沿现有模型动作打磨。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.99；缺口 1.22/3；文字矛盾概率 0.11。
- 执行判断：先核对整招。没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。

|阶段|本招方案|
|---|---|
|起手与蓄力|手臂短提，小银剪/丝端反光|
|主体与运动|短丝划击不长时间成笼|
|接触或生效|细小断丝短爆|
|持续阶段|段间短收，不能提前播放束缚状态|
|收势与退场|两次结束回位，再进入正式束缚蓄力|

普通/试探攻击追加核对：赤丝裁衣人普通打击：两次短提腕、短丝划击、断丝退净；不能提前变成束缚笼。

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-14.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchSpellVisual20260917.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2508`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchBounties.swift:105`

### B05B · B05 赤丝裁衣人·赤丝束缚

通缉 / 正式/源码可达 / 批次C / 主角1人；直伤后有限3跳

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：保留SilkTravel/SilkRupture有机绸面方向；补起手贴身与持续收紧的布料细节。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.37；缺口 0.99/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|丝端沿肩臂贴体流动|
|主体与运动|少量不对称绸流扭转前进|
|接触或生效|柔软错向撕裂，非白尖锥/锯齿硬片|
|持续阶段|实际绑定期间轻呼吸，不重复命中爆炸|
|收势与退场|丝纹逐段断开消退，不留规则圆环|

实录：[bounty-b05-silk_bind](../../output/all-spells-polish-20260921/bounty-b05-silk_bind.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-14.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchSpellVisual20260917.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2508`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchBounties.swift:105`

### M10 · 翠焰亡灵·环境毒雾

主线敌人 / 正式/源码可达 / 批次C / 环境单层；Q5持续递增，Q19恢复拍点降低浓度/伤害

- 原始证据：advanceEmeraldPoison按3秒增加伤害；Q19的recover将浓度重置1、每跳伤害降为基础最大HP的1%。Q5无此恢复降档分支。
- 保护边界：同一环境视觉的Q5/Q19是规则变体，分两场验证；不说Q19固定3跳，不把D02有限毒搬来。
- 当前候选改法：分近地浓雾、中层流动和稀疏亮点；浓度随实际状态增长，不每跳爆炸。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：沿主体精修，路线置信度 0.38；缺口 0.92/3；文字矛盾概率 0.11。
- 执行判断：沿主体精修。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|开场从亡灵下摆/脚下扩散|
|主体与运动|雾贴地铺开，轮廓有前后深度|
|接触或生效|持续伤害按实际跳点，毒跳不震屏|
|持续阶段|依实际场景持续：Q5逐渐增强；Q19到recover时视觉同步降浓度，不复制Q5的单调增长。|
|收势与退场|停战清全部环境层，不污染下一关|

实录：[emerald-poison-field](../../output/all-spells-polish-20260921/emerald-poison-field.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060325414234Z/batch-01.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2024`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2120`

### M11 · 翠焰亡灵·蓄焰重击

主线敌人 / 正式/源码可达 / 批次C / 主角1人；蓄力属于同一招

- 原始证据：用户明确认可全身绿色/金白蓄焰为特效典范。当前释放与命中有实录，但不能外推整招均获认可。
- 保护边界：保护已认可蓄力：贴身体、向上流动、亮暗层次与身体可读。只补衔接，不换成全屏光团。
- 当前候选改法：以用户认可全身蓄焰为保护基准，补到释放/命中的连续性，不改已有蓄力造型。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留与回归，路线置信度 0.43；缺口 0.84/3；文字矛盾概率 0.10。
- 执行判断：保留与回归。优先服从最新用户保护边界；已认可阶段保留，未认可衔接按本行候选复核，不外推整招认可。

|阶段|本招方案|
|---|---|
|起手与蓄力|保留全身绿色/金白附着火焰、向上流动和可读身体|
|主体与运动|全身能量随着发力收束释放|
|接触或生效|真实接触时蓄积焰层炸开并快速回收|
|持续阶段|不重复释放环境毒雾|
|收势与退场|身体绿焰退回待机亮度，死亡/取消恢复|

实录：[emerald-charge](../../output/all-spells-polish-20260921/emerald-charge.mp4) · [emerald-burst](../../output/all-spells-polish-20260921/emerald-burst.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-09.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2589`

### M12 · 档案守卫·封存装甲

主线敌人 / 正式/源码可达 / 批次C / 自身防御

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：保留新增旋转和纹路流光；盾要有薄厚、转动遮挡和局部反光，不加固定平面光盘。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.78；缺口 1.00/3；文字矛盾概率 0.09。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|前臂合拢，关节蓝白光接合|
|主体与运动|机械盾分层展开，随身体转动|
|接触或生效|防御激活内收短亮，不伤害爆闪|
|持续阶段|持续旋转、错落星闪，盾后身体仍可辨|
|收势与退场|盾分片退回并恢复本体|

实录：[archive-shield](../../output/all-spells-polish-20260921/archive-shield.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-09.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2549`

### T11 · D01 盾颚·锁甲

正式塔 / 正式/源码可达 / 批次C / 自身防御

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：已按用户否定移除身体中心圆圈；保留该方向。
- 当前候选改法：甲缝流光贴合上臂/前臂，检查持续防御的呼吸感。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.87；缺口 1.01/3；文字矛盾概率 0.08。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|收臂低头，沿甲缝聚光|
|主体与运动|短分段甲光随骨骼运动|
|接触或生效|真实防御成立时向内扣合，不爆伤|
|持续阶段|保持甲缝亮暗交替，禁止身体中心圆圈|
|收势与退场|张臂退光，恢复全部骨骼|

实录：[stonehide-guard](../../output/all-spells-polish-20260921/stonehide-guard.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-04.response.json)

源码/记录：`docs/development/TOWER_COMPLETE_DELIVERY_20260920.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521`

### T12 · D01 盾颚·重砸

正式塔 / 正式/源码可达 / 批次C / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：不回退身体中心圆环；不把全招等比放大。
- 当前候选改法：保留过顶砸地和48道火星；补石层侧壁明暗，让火星从真实落点喷出。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：沿主体精修，路线置信度 0.37；缺口 1.01/3；文字矛盾概率 0.11。
- 执行判断：沿主体精修。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|双臂过顶，甲缝能量向拳部集中|
|主体与运动|躯干压低、拳体前下砸落|
|接触或生效|地裂少而大片向外撑；保留48道不同轨迹火星|
|持续阶段|碎石短落地不反复爆炸|
|收势与退场|手臂收回，尘层退去，不残留亮片|

实录：[stonehide-archive_slam](../../output/all-spells-polish-20260921/stonehide-archive_slam.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-04.response.json)

源码/记录：`docs/development/TOWER_COMPLETE_DELIVERY_20260920.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521`

### T21 · D02 盐囊·有限毒息

正式塔 / 正式/源码可达 / 批次C / 主角持续伤害；当前规则3跳有限毒

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：塔毒有限、Q5环境毒不同；同段公共状态片也展示D05强化。
- 当前候选改法：与盐晶实体刺分开：囊体鼓胀、薄厚毒息沿弯曲通道喷吐，落下为有限状态。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.53；缺口 0.98/3；文字矛盾概率 0.11。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|胸颈/囊体鼓起、黏液亮纹贴身|
|主体与运动|一股有厚薄的毒息随扭身喷出|
|接触或生效|施毒生效用侵染边缘，不假装直接爆伤|
|持续阶段|有限毒层受权威状态驱动；不复制Q5无限雾|
|收势与退场|囊体瘪回，状态结束彻底清掉|

实录：[saltmaw-charge](../../output/all-spells-polish-20260921/saltmaw-charge.mp4) · [saltmaw-tower_poison](../../output/all-spells-polish-20260921/saltmaw-tower_poison.mp4) · [tower-persistent-status](../../output/all-spells-polish-20260921/tower-persistent-status.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-05.response.json)

源码/记录：`docs/development/TOWER_COMPLETE_DELIVERY_20260920.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521`

### T22 · D02 盐囊·盐晶刺

正式塔 / 正式/源码可达 / 批次C / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：盐晶刺当前方向曾获认可；不恢复规则圆环或密小碎屑。
- 当前候选改法：保留认可实体盐晶、九宽片主体；重点核对胸腰发力到刺体崩开的衔接。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留与回归，路线置信度 0.56；缺口 0.81/3；文字矛盾概率 0.14。
- 执行判断：保留与回归。优先服从最新用户保护边界；已认可阶段保留，未认可衔接按本行候选复核，不外推整招认可。

|阶段|本招方案|
|---|---|
|起手与蓄力|胸腰扭转、盐晶棱面依次点亮|
|主体与运动|实体刺旋转前推，主辅流光错层|
|接触或生效|接触短收紧后不规则大片碎晶炸开|
|持续阶段|只留少量晶屑和亮芯短尾|
|收势与退场|刺体退光、囊体回位|

实录：[saltmaw-charge](../../output/all-spells-polish-20260921/saltmaw-charge.mp4) · [saltmaw-tower_salt_spike](../../output/all-spells-polish-20260921/saltmaw-tower_salt_spike.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-05.response.json)

源码/记录：`docs/development/TOWER_COMPLETE_DELIVERY_20260920.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521`

### T31 · D03 背囊·恢复

正式塔 / 正式/源码可达 / 批次C / 固定1名受伤友军；排除背囊/核心

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：治疗最多次数/选友规则不变。
- 当前候选改法：治疗做挤囊—输送—吸收，膜纹随体积呼吸；不使用伤害爆炸。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.50；缺口 1.00/3；文字矛盾概率 0.08。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|压低前身挤动背囊，膜纹亮起|
|主体与运动|一股有体积的恢复物向固定友军输送|
|接触或生效|真实受疗端向内绽开并显示实际治疗|
|持续阶段|弱余辉附着受益者，不扩全队|
|收势与退场|收囊回位；受益者退场即取消，不改投|

实录：[shellback-charge](../../output/all-spells-polish-20260921/shellback-charge.mp4) · [shellback-tower_mend](../../output/all-spells-polish-20260921/shellback-tower_mend.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-05.response.json)

源码/记录：`docs/development/TOWER_COMPLETE_DELIVERY_20260920.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521`

### T32 · D03 背囊·短扑

正式塔 / 正式/源码可达 / 批次C / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留当前短扑设计，非重做物种。
- 当前候选改法：突出身体压缩后短扑压碎，与挤囊恢复分姿态。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留与回归，路线置信度 0.70；缺口 0.80/3；文字矛盾概率 0.08。
- 执行判断：保留与回归。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|后躯收缩、前肢压低|
|主体与运动|短距压身发力，膜褶受惯性拉伸|
|接触或生效|扁宽压裂与低喷甲屑，不做治疗花|
|持续阶段|低位薄尘迅速散去|
|收势与退场|按已确认站位回位，不让位移累积|

实录：[shellback-tower_short_pounce](../../output/all-spells-polish-20260921/shellback-tower_short_pounce.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-05.response.json)

源码/记录：`docs/development/TOWER_COMPLETE_DELIVERY_20260920.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521`

### T41 · D04 剪肢·第一快切

正式塔 / 正式/源码可达 / 批次C / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：四倍爆发方向保留；最新区别版待复核。
- 当前候选改法：保留右臂高举斜劈与单束斜裂；刃体纹理顺切向流动。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留与回归，路线置信度 0.61；缺口 0.99/3；文字矛盾概率 0.10。
- 执行判断：保留与回归。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|右臂独立高举，能量贴刃根|
|主体与运动|单束高速斜切，保留实体弯刃|
|接触或生效|一条窄斜裂快速撑开，碎光顺法线喷|
|持续阶段|短细刃尾不组成同心环|
|收势与退场|右臂自然回落，恢复原骨骼|

实录：[ironclaw-charge](../../output/all-spells-polish-20260921/ironclaw-charge.mp4) · [ironclaw-tower_cut_first](../../output/all-spells-polish-20260921/ironclaw-tower_cut_first.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-05.response.json)

源码/记录：`docs/development/TOWER_COMPLETE_DELIVERY_20260920.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521`

### T42 · D04 剪肢·第二反切

正式塔 / 正式/源码可达 / 批次C / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：绿刃、爆发强度与独立身体动作保持。
- 当前候选改法：保留左臂横展转腰与宽弧回扫；不把第一刀旋转来替代。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.33；缺口 1.00/3；文字矛盾概率 0.09。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|左臂横展、转腰蓄力|
|主体与运动|宽弧横扫，内外缘速度和厚度不同|
|接触或生效|横向碎光与弧裂错层展开|
|持续阶段|弧尾被拉断，非完整规则扇面|
|收势与退场|左臂与腰依次回位|

实录：[ironclaw-tower_cut_second](../../output/all-spells-polish-20260921/ironclaw-tower_cut_second.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-06.response.json)

源码/记录：`docs/development/TOWER_COMPLETE_DELIVERY_20260920.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521`

### T43 · D04 剪肢·双刃重切

正式塔 / 正式/源码可达 / 批次C / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：现有快切/反切/重切三种轮廓不可互换。
- 当前候选改法：双刃合剪交叉爆开，强化刃面高光与接触停顿；不退回三刀同形。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.56；缺口 1.01/3；文字矛盾概率 0.12。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|双臂过顶，两刃分开聚能|
|主体与运动|刃体合剪而非平行推进|
|接触或生效|交叉中心短压后四向错片喷开|
|持续阶段|交叉余痕快速拉回，避免整屏亮团|
|收势与退场|双臂不同步自然放下，取消恢复|

实录：[ironclaw-tower_heavy_cut](../../output/all-spells-polish-20260921/ironclaw-tower_heavy_cut.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-06.response.json)

源码/记录：`docs/development/TOWER_COMPLETE_DELIVERY_20260920.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521`

### T51 · D05 蛇冠·展冠强化

正式塔 / 正式/源码可达 / 批次C / 固定1名存活非蛇冠友军

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：不是全队buff；治疗/强化不能用通用伤害爆炸。
- 当前候选改法：强化表现为冠瓣展鳞与能量交付；受益者显示稳定小冠纹而非攻击爆闪。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.50；缺口 1.00/3；文字矛盾概率 0.08。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|抬头展冠，鳞缘逐片亮起|
|主体与运动|冠状能量绕身后向单友军交付|
|接触或生效|实际强化生效时受益端内聚|
|持续阶段|受益者稳定ID冠纹轻呼吸|
|收势与退场|施法者收冠；受益者退场清自身状态|

实录：[frilled-naga-charge](../../output/all-spells-polish-20260921/frilled-naga-charge.mp4) · [frilled-naga-tower_empower](../../output/all-spells-polish-20260921/frilled-naga-tower_empower.mp4) · [tower-persistent-status](../../output/all-spells-polish-20260921/tower-persistent-status.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-06.response.json)

源码/记录：`docs/development/TOWER_COMPLETE_DELIVERY_20260920.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521`

### T52 · D05 蛇冠·声矢

正式塔 / 正式/源码可达 / 批次C / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：与展冠强化运动和受益端完全不同。
- 当前候选改法：声矢保留定向纵深，像压缩鸣声穿出冠口，不做一个旋转圆圈。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.35；缺口 1.01/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|冠瓣向前收束，颈部发力|
|主体与运动|细长声矢带错距弧形波前|
|接触或生效|目标处不对称声纹迅速撑裂|
|持续阶段|短余音层强弱递减|
|收势与退场|冠瓣回位，去掉尾端循环亮圈|

实录：[frilled-naga-tower_sound_arrow](../../output/all-spells-polish-20260921/frilled-naga-tower_sound_arrow.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-06.response.json)

源码/记录：`docs/development/TOWER_COMPLETE_DELIVERY_20260920.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521`

### T61 · D06 骨爪·穿刺

正式塔 / 正式/源码可达 / 批次C / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留旧质感；不要重启被否定的实体骨锥替换版。
- 当前候选改法：保持冰蓝窄裂、细密纵纹与单臂斜刺；只沿已有形态补细节。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：沿主体精修，路线置信度 0.57；缺口 1.01/3；文字矛盾概率 0.09。
- 执行判断：沿主体精修。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|单臂后拉，亮纹沿骨爪汇到尖端|
|主体与运动|一个冰蓝窄裂口贯穿，不是三根光柱|
|接触或生效|纵裂短爆后回缩，保留最新峰值|
|持续阶段|细冷光快速退去|
|收势与退场|骨爪和肩腰回位|

实录：[boneclaw-charge](../../output/all-spells-polish-20260921/boneclaw-charge.mp4) · [boneclaw-tower_piercing_claw](../../output/all-spells-polish-20260921/boneclaw-tower_piercing_claw.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-06.response.json)

源码/记录：`docs/development/TOWER_COMPLETE_DELIVERY_20260920.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521`

### T62 · D06 骨爪·尾扫

正式塔 / 正式/源码可达 / 批次C / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：等距扇骨/完整扇形和重复放大贴片46/48已被否定。
- 当前候选改法：保持六片不等长错位青绿弧裂；逐帧复核脚前残块不回归。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.54；缺口 1.00/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|转腰带尾链，纹光沿尾根走向尾端|
|主体与运动|六片错位弧裂扫过，不封成完整扇面|
|接触或生效|命中瞬间扩大后迅速回收，碎屑加速|
|持续阶段|断纹尾迹有空隙，不留独立绿块|
|收势与退场|腰尾归位，低位贴片彻底退光|

实录：[boneclaw-tower_tail_sweep](../../output/all-spells-polish-20260921/boneclaw-tower_tail_sweep.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-07.response.json)

源码/记录：`docs/development/TOWER_COMPLETE_DELIVERY_20260920.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521`

### T63 · D06 骨爪·重爪

正式塔 / 正式/源码可达 / 批次C / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：最新5.5倍峰值样本供复核，不字面宣称主观提升倍数。
- 当前候选改法：保持紫金中心放射与块状爆裂；纹理粗分叉，不能只换穿刺的颜色。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.41；缺口 1.01/3；文字矛盾概率 0.15。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|双爪过顶，肩背蓄劲|
|主体与运动|错落宽裂随双爪前下砸|
|接触或生效|中心放射/块状光裂极速外撑再缩|
|持续阶段|粗细骨纹余辉短暂错时熄灭|
|收势与退场|双爪收回，恢复尾链和材质|

实录：[boneclaw-tower_heavy_claw](../../output/all-spells-polish-20260921/boneclaw-tower_heavy_claw.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-07.response.json)

源码/记录：`docs/development/TOWER_COMPLETE_DELIVERY_20260920.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521`

### H00 · 普通攻击

主角 / 正式/源码可达 / 批次D / 1名有效敌人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：伤害、攻速、单目标及0.58秒contact不变；55ms局部视觉缓冲作为旧版对照，不照搬大招停顿。与错步独立，不新增自动选敌、伤害段数、附效或强震屏。
- 当前候选改法：普攻由仅核对改为明确精修：翻腕出牌更利落，飞牌有材质和转动侧边；短弯尾迹跟随牌势，接触点沿切向短撑裂后迅速收净，不铺整屏碎光。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.81；缺口 0.98/3；文字矛盾概率 0.07。
- 执行判断：沿主体精修。用户追加普攻优化，不能继续仅列为保留回归。保持短促牌击身份，把动作、飞行主体、局部命中与收势完整打磨；不是将普攻升级成大招。

|阶段|本招方案|
|---|---|
|起手与蓄力|肩肘短收带动翻腕，手中牌面先压出角度、衣袖自然跟随；能量只沿出牌侧聚起，不加长蓄力或身体光环。|
|主体与运动|沿当前单目标线路掷出一枚主牌，翻转时能读到牌面细节与侧边厚度；金紫短尾迹渐细、自然撕散，避免矩形光板或全程匀速滑片。|
|接触或生效|对齐原0.58秒真实contact，切入点短亮芯沿牌势不对称撑开，少量碎金光定向弹出；小而清楚，不放完整圆环或大招爆云，不重复触发受击。|
|持续阶段|普攻没有额外持续伤害。只留短切痕和少量渐暗碎屑，收掉散到整屏的星点/雾层；多次连打不积成常亮底幕。|
|收势与退场|腕、肘、肩顺势回待机，短尾迹从薄边逐段消散；取消、死亡与切场清当前实例，不让上一击残光拖进下一击。|

最新状态：用户追加普攻优化；精修方案待制作

已有普攻实录，用于精修前对照；用户要求优化不等于旧版整招被否定。新方案尚未制作或重录。

此前送Jev的原方案（仅溯源，受最新反馈覆盖）：保持短促牌击；只检查飞牌立体侧边和命中前后的能量连贯，不与大招争亮度。

实录：[hero-basic](../../output/all-spells-polish-20260921/hero-basic.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-01.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift`

### M01 · 空壳守卫·赤弧斩

主线敌人 / 正式/源码可达 / 批次D / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：强化剑臂带动赤弧的因果；普通/第二次录像属于同一招，不算两招。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.77；缺口 1.02/3；文字矛盾概率 0.12。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|肩肘收剑，刃缘点亮|
|主体与运动|赤弧从真实剑刃扫出|
|接触或生效|斜向短裂与刃火弹开|
|持续阶段|短赤痕不遮主角|
|收势与退场|剑臂收回，保持敌人远处站位|

普通/试探攻击追加核对：空壳守卫赤弧斩：剑臂收放与刃口短裂连贯，不能只有赤色光片移动。

实录：[enemy-default-1](../../output/all-spells-polish-20260921/enemy-default-1.mp4) · [enemy-default-2](../../output/all-spells-polish-20260921/enemy-default-2.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-07.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2711`

### M02 · 空壳守卫·重甲架势

主线敌人 / 正式/源码可达 / 批次D / 自身防御

- 原始证据：源码/规则有此项；85段总览缺少本项独立完整证据，先核对路由与当前整招。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：先补完整状态证据；候选为胸甲/肩甲接缝相互扣紧。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 1.00；缺口 1.72/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。

|阶段|本招方案|
|---|---|
|起手与蓄力|收臂压肩|
|主体与运动|能量贴甲缝合拢|
|接触或生效|防御成立只内收闪|
|持续阶段|低亮甲纹呼吸，不造攻击|
|收势与退场|解除时按部位退光、回待机|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-07.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2549`

### M03 · 幽灵·雾钟震魂

主线敌人 / 正式/源码可达 / 批次D / 主角1人；普通/赤红是模型变体

- 原始证据：源码PresentFogGhostCast按primary/secondary实例选择法术，非按颜色。普通/赤红primary的两次录制均为雾钟路径；颜色不新增技能。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：雾钟弧波保留纵深，补钟口内外层和身体舒张；不按颜色拆新技能。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：沿主体精修，路线置信度 0.77；缺口 0.62/3；文字矛盾概率 0.09。
- 执行判断：沿主体精修。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|躯壳收缩、钟口内亮外暗|
|主体与运动|厚薄弧波分前后推出|
|接触或生效|弧波压缩后不等距张开|
|持续阶段|少量雾片随波纹退去|
|收势与退场|躯壳舒展回悬浮待机|

实录：[enemy-fog-ghost-1](../../output/all-spells-polish-20260921/enemy-fog-ghost-1.mp4) · [enemy-fog-ghost-2](../../output/all-spells-polish-20260921/enemy-fog-ghost-2.mp4) · [enemy-crimson-ghost-1](../../output/all-spells-polish-20260921/enemy-crimson-ghost-1.mp4) · [enemy-crimson-ghost-2](../../output/all-spells-polish-20260921/enemy-crimson-ghost-2.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060325414234Z/batch-01.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2713`；`UnityBattleSource/Assets/Scripts/BattlePrototype.cs:2051`

### M04 · 幽灵·幽雾追魂

主线敌人 / 正式/源码可达 / 批次D / 主角1人；包含赤红与secondary实例

- 原始证据：secondary实例走projectile-ghost-wisp-v1；专用ghost-wisp-secondary是该招证据。不能把赤红primary录像误当追魂。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：追魂螺旋与雾钟波前区分；尾迹浓淡体现近远，不做平面白柱。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：沿主体精修，路线置信度 0.39；缺口 0.78/3；文字矛盾概率 0.09。
- 执行判断：沿主体精修。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|幽体向一侧卷聚|
|主体与运动|不等半径雾丝绕行追向主角|
|接触或生效|细雾束卷紧后向外旋散|
|持续阶段|弯曲残雾迅速变薄|
|收势与退场|各施法者只清自己的尾迹|

实录：[ghost-wisp-secondary](../../output/all-spells-polish-20260921/ghost-wisp-secondary.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060325414234Z/batch-01.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2713`；`UnityBattleSource/Assets/Scripts/BattlePrototype.cs:2051`

### M05 · 早期地狱犬·普通火球

主线敌人 / 正式/源码可达 / 批次D / 主角1人；早犬独立模板

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：保持早犬火球；火源随嘴部，起手贴胸颈，不改为后期地火。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.73；缺口 1.00/3；文字矛盾概率 0.09。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|四脚持续步态中胸颈蓄火|
|主体与运动|熔核火球离口，壳层向后流动|
|接触或生效|抵达主角才焰舌外翻|
|持续阶段|短火星和烟屑|
|收势与退场|继续步态，取消清火球不换犬模型|

普通/试探攻击追加核对：早犬普通火球：贴胸颈/嘴部短聚，熔核与焰壳有层次；持续步态、远处站位保留。

实录：[early-hound](../../output/all-spells-polish-20260921/early-hound.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-08.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2599`

### M06 · Q4 早犬·试探小火球

主线敌人 / 正式/源码可达 / 批次D / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：小火球与双焰在尺寸、蓄力和命中权重上有级差。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.86；缺口 1.00/3；文字矛盾概率 0.11。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|口中短聚火，不附加2秒双焰预警|
|主体与运动|单颗紧凑火球飞出|
|接触或生效|小型短促爆芯，不能抢大招观感|
|持续阶段|少量短火屑|
|收势与退场|回持续步态|

普通/试探攻击追加核对：Q4试探小火球：紧凑短促，和双焰大火球拉开蓄力、尺寸及爆发级差。

实录：[q4-probe](../../output/all-spells-polish-20260921/q4-probe.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-08.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2582`

### M07 · Q4 早犬·双焰追索

主线敌人 / 正式/源码可达 / 批次D / 主角1人，先后两颗大火球；2秒预警

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：将预警和两颗火球拼成一招连续证据；两次命中/假面拦截分别清楚。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.89；缺口 1.00/3；文字矛盾概率 0.13。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|2秒双焰预警贴胸颈和嘴部，四脚仍动|
|主体与运动|两颗追索大火球分拍飞出，保持远处站位|
|接触或生效|每颗到达时独立爆开；幻影承接才出现挡击|
|持续阶段|正确双挡的3秒易伤只按规则显示|
|收势与退场|两颗均终结后退去，失败/重试不留弹体|

实录：[q4-charge](../../output/all-spells-polish-20260921/q4-charge.mp4) · [q4-first](../../output/all-spells-polish-20260921/q4-first.mp4) · [q4-second](../../output/all-spells-polish-20260921/q4-second.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-08.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2583`

### M08 · 铠甲犬·脚下熔火

主线敌人 / 正式/源码可达 / 批次D / 主角1人；新铠甲犬非早犬

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：咆哮引发主角脚下窜火，保留烧黑地面与旋转收小方向。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.68；缺口 1.00/3；文字矛盾概率 0.12。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|背毛/喉部聚能，低头咆哮|
|主体与运动|地下能量传到主角脚下，不飞火球|
|接触或生效|火焰从脚下高喷后旋转缩小|
|持续阶段|烧黑地面保持短余热层|
|收势与退场|火柱收小消失，不留方形地板|

实录：[armored-hound-1](../../output/all-spells-polish-20260921/armored-hound-1.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-08.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2599`

### M09 · 铠甲犬·低位卷火

主线敌人 / 正式/源码可达 / 批次D / 主角1人；第二视觉变式

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：保持用户后续脚下出火方向；用低位翻卷和不同起手区别高喷发，不恢复方形火潮。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.90；缺口 1.00/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|压肩拧身，热纹沿前肢下行|
|主体与运动|主角脚下低位卷火旋起|
|接触或生效|宽而低的焰沿短撑开|
|持续阶段|旋转同时缩小，地面焦边可读|
|收势与退场|热流变薄退尽，原站位不动|

实录：[armored-hound-2](../../output/all-spells-polish-20260921/armored-hound-2.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-09.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2599`

### M13 · 档案守卫·飞臂重击

主线敌人 / 正式/源码可达 / 批次D / 主角1人；前臂连掌发射后归位

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：保留真正飞臂与掌心实体；飞行时肩腕光路连贯，接触后返回装回。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.66；缺口 0.99/3；文字矛盾概率 0.09。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|前臂/掌关节先充能解锁|
|主体与运动|前臂连手掌脱离，蓝白流光沿机械缝流动|
|接触或生效|真实掌击触发contact；错落机械火花定向喷出|
|持续阶段|返回途中亮度递减，不再攻击|
|收势与退场|准确装回本体，跨关/死亡/重试恢复手臂|

实录：[enemy-archivist-1](../../output/all-spells-polish-20260921/enemy-archivist-1.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-09.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2549`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2551`

### M14 · 档案守卫·机械阵列

主线敌人 / 正式/源码可达 / 批次D / 主角1人；独立于飞臂的第二视觉

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：少量实体机械刃有序旋转后合击；不回退旧大块黑片或噪点。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.96；缺口 1.01/3；文字矛盾概率 0.18。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。 另复核该行0.18的矛盾概率：提案明确保留单目标/原contact，机械阵列是已存在第二视觉；无据改变战斗规则。

|阶段|本招方案|
|---|---|
|起手与蓄力|两臂不同于飞臂的外展蓄力|
|主体与运动|分段机械件成错层刃阵推进|
|接触或生效|定向合击后沿金属边缘短炸开|
|持续阶段|碎光退去，零屏幕噪点|
|收势与退场|机械件收回；不与第一招共用裸光线|

实录：[enemy-archivist-2](../../output/all-spells-polish-20260921/enemy-archivist-2.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-10.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2549`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2551`

### M15 · 寄忆核心·记忆冲击

主线敌人 / 正式/源码可达 / 批次D / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：让核心局部脉动连到记忆波，增加内外壳层差而非整体机械摇摆。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.79；缺口 1.00/3；文字矛盾概率 0.09。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|核心局部收缩、内部亮起|
|主体与运动|层叠记忆波沿目标方向推出|
|接触或生效|接触处记忆裂片短撑开|
|持续阶段|少量记忆碎光减速|
|收势与退场|核心脉动回正常频率|

实录：[core-memory-strike](../../output/all-spells-polish-20260921/core-memory-strike.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-10.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2559`

### M16 · 寄忆核心·定向修复

主线敌人 / 正式/源码可达 / 批次D / 固定1名受伤友军

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：完整展示核心输出与受疗端吸收；guard-heal是同一治疗的受益段，不另算技能。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.87；缺口 1.01/3；文字矛盾概率 0.13。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|核心打开输送瓣|
|主体与运动|单条有宽度变化的修复流去固定友军|
|接触或生效|真实修复接触后内聚、绿字为实际值|
|持续阶段|修补纹沿受益者甲缝流动|
|收势与退场|友军退场取消，不临时换人补血|

实录：[core-repair](../../output/all-spells-polish-20260921/core-repair.mp4) · [guard-heal](../../output/all-spells-polish-20260921/guard-heal.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-10.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2560`

### M17 · 记忆蛭·三次试探

主线敌人 / 正式/源码可达 / 批次D / 主角1人，3次试探

- 原始证据：源码/规则有此项；85段总览缺少本项独立完整证据，先核对路由与当前整招。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：先补连续三次实录；拟用三次小幅口器伸缩和窄记忆丝，不复用吞名大蓄力。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 1.00；缺口 1.41/3；文字矛盾概率 0.13。
- 执行判断：先核对整招。没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。

|阶段|本招方案|
|---|---|
|起手与蓄力|口器短促收缩|
|主体与运动|每次窄丝/短探前送|
|接触或生效|每次真实命中小幅短缩裂|
|持续阶段|段间回缩，不连成常亮光束|
|收势与退场|第三次后完整回待机|

普通/试探攻击追加核对：记忆蛭三次试探：先补真实连续样本，按三次短促口器动作核对，不挪用吞名大蓄力。

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-10.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2576`

### M18 · 记忆蛭·吞名

主线敌人 / 正式/源码可达 / 批次D / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：完整合并蓄力和吞名；口器褶皱与抽取流具有重量/厚度。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.77；缺口 1.02/3；文字矛盾概率 0.12。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|身体收紧、口器层层张开|
|主体与运动|记忆流被拉向口器，有渐细螺旋|
|接触或生效|目标端短压裂，接触不早于规则|
|持续阶段|流体收向口器而不是全场散射|
|收势与退场|口器闭合、体节松开|

实录：[leech-charge](../../output/all-spells-polish-20260921/leech-charge.mp4) · [enemy-leech](../../output/all-spells-polish-20260921/enemy-leech.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-10.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2576`

### M19 · 抄录傀儡·强化

主线敌人 / 正式/源码可达 / 批次D / 自身

- 原始证据：源码/规则有此项；85段总览缺少本项独立完整证据，先核对路由与当前整招。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：先核实当前强化触发和视觉入口，再做沿笔臂的符纹增亮。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 1.00；缺口 1.11/3；文字矛盾概率 0.09。
- 执行判断：先核对整招。没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。

|阶段|本招方案|
|---|---|
|起手与蓄力|笔臂向胸前收起|
|主体与运动|铭文沿关节上行|
|接触或生效|真实强化事件内聚点亮|
|持续阶段|少量刻纹呼吸，区别攻击|
|收势与退场|状态解除原位退光|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-11.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2593`

### M20 · 抄录傀儡·校准驱盾

主线敌人 / 正式/源码可达 / 批次D / 主角1人／状态

- 原始证据：源码/规则有此项；85段总览缺少本项独立完整证据，先核对路由与当前整招。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：先确认驱盾的真实表现与触发；候选为擦除盾面的一道笔痕，不制造伤害。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 1.00；缺口 1.20/3；文字矛盾概率 0.08。
- 执行判断：先核对整招。没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。

|阶段|本招方案|
|---|---|
|起手与蓄力|笔端朝盾面校准|
|主体与运动|窄墨痕沿受影响盾边扫过|
|接触或生效|只在真实驱散时擦除对应盾层|
|持续阶段|无额外负面/伤害层|
|收势与退场|墨痕收回，不伤及其它对象|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-11.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1974`

### M21 · 抄录傀儡·墨笔重击

主线敌人 / 正式/源码可达 / 批次D / 主角1人；两次动画是视觉变体

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：沿笔尖造型做厚薄不同的墨迹撕裂，保持与执行者金属刻痕不同。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.87；缺口 1.02/3；文字矛盾概率 0.08。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|笔臂收压，墨亮聚在笔端|
|主体与运动|浓淡分层墨锋前送|
|接触或生效|墨迹沿落笔方向短裂|
|持续阶段|细墨屑边缘快速散开|
|收势与退场|笔臂回收，墨迹全部清掉|

实录：[enemy-scribe-1](../../output/all-spells-polish-20260921/enemy-scribe-1.mp4) · [enemy-scribe-2](../../output/all-spells-polish-20260921/enemy-scribe-2.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-11.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2711`

### M22 · 精英守卫·校正重击

主线敌人 / 正式/源码可达 / 批次D / 主角1人

- 原始证据：源码/规则有此项；85段总览缺少本项独立完整证据，先核对路由与当前整招。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：先查实际路由/模型，不用默认守卫录像冒充；根据现用模型保留校正重击身份。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 1.00；缺口 1.71/3；文字矛盾概率 0.11。
- 执行判断：先核对整招。没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。

|阶段|本招方案|
|---|---|
|起手与蓄力|按实际武器收势蓄力|
|主体与运动|保持真实武器路径与远处站位|
|接触或生效|单方向校正压痕，不混入治疗光|
|持续阶段|短机械余烬|
|收势与退场|恢复武器/本体状态并补整招录制|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-11.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2711`

### M23 · 维娅·红绸绞笼

主线敌人 / 正式/源码可达 / 批次D / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：三条深红绸带有面料、厚薄、卷曲和错深度；禁止乱红线或硬红锯齿片。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.80；缺口 1.04/3；文字矛盾概率 0.11。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|肩臂牵动三条绸带，红纹沿布料流动|
|主体与运动|三条有序缎面围向目标，不构完整圆环|
|接触或生效|绸面收紧短停后错向撕散|
|持续阶段|少量丝屑，目标轮廓保留|
|收势与退场|绸带回收并清尾迹，非致命剧情状态保留|

实录：[enemy-matriarch-1](../../output/all-spells-polish-20260921/enemy-matriarch-1.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-11.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725`

### M24 · 维娅·短银针阵

主线敌人 / 正式/源码可达 / 批次D / 主角1人；短批次针雨非新群攻

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：分批俯冲短银针，针尖高光与红丝拉力不同步；避免一长排持续雨。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.89；缺口 1.00/3；文字矛盾概率 0.11。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|抬指牵针，银针逐簇反光|
|主体与运动|短针错时俯冲，路径有疏密|
|接触或生效|命中为细点闪与短刺纹，不复用绸带爆炸|
|持续阶段|数枚针尾迅速退光|
|收势与退场|手势解开，跨关清所有针体|

实录：[enemy-matriarch-2](../../output/all-spells-polish-20260921/enemy-matriarch-2.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-12.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725`

### M25 · 洛克／负契者·掌压冲击

主线敌人 / 正式/源码可达 / 批次D / 主角1人；两种起手变体

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：保留空手发力和衣装材质，掌压波层来自肩肘，而不是无源横线。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.68；缺口 1.00/3；文字矛盾概率 0.08。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|肩腰后收、手掌独立聚能|
|主体与运动|掌前厚薄压力膜定向推进|
|接触或生效|接触宽短压裂，细纹沿掌形喷出|
|持续阶段|余压层快速回卷|
|收势与退场|恢复空手待机；非致命退场不写成死亡|

实录：[enemy-rescue-1](../../output/all-spells-polish-20260921/enemy-rescue-1.mp4) · [enemy-rescue-2](../../output/all-spells-polish-20260921/enemy-rescue-2.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-12.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`

### M26 · 执行者·笔锋直划

主线敌人 / 正式/源码可达 / 批次D / 主角1人

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：真实Pen.R发力，铜金笔锋刻出窄裂；保留M12正式模型，不退回旧母版。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.73；缺口 1.00/3；文字矛盾概率 0.12。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|笔臂后收、笔缝刻纹亮起|
|主体与运动|直笔锋从Pen.R前送|
|接触或生效|窄刻痕接触后裂片沿笔向喷出|
|持续阶段|签记细屑分层退去|
|收势与退场|笔臂恢复原位，状态段并入整招|

实录：[enemy-executor-1](../../output/all-spells-polish-20260921/enemy-executor-1.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-12.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725`

### M27 · 执行者·回钩反印

主线敌人 / 正式/源码可达 / 批次D / 主角1人；第二视觉变式

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：弧线回钩与直划分清，反印用折返笔迹而非同一光束弯一下。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.78；缺口 1.00/3；文字矛盾概率 0.11。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|笔臂侧收翻腕，铜绿刻纹内聚|
|主体与运动|带回钩的印痕从侧上方翻入|
|接触或生效|反印翻面压裂，边角错层崩开|
|持续阶段|短反印余迹向内卷回|
|收势与退场|腕肘依次回位，取消不留独立印板|

实录：[enemy-executor-2](../../output/all-spells-polish-20260921/enemy-executor-2.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-12.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725`

### M28 · 裁定锤卫·校定锤击

主线敌人 / 正式/源码可达 / 批次D / 主角1人；两种动画变体

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：保留双手重锤和不规则地裂身份；纵向砸落与压舱平行冲压分开。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.65；缺口 1.00/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|双手举锤，光沿锤头棱面聚起|
|主体与运动|肩腰带锤落下，重心有承重|
|接触或生效|不规则地裂向短方向上掀|
|持续阶段|重碎片先落，小火花后退|
|收势与退场|锤与身体回位；准备/恢复不另算招|

实录：[enemy-adjudicator-1](../../output/all-spells-polish-20260921/enemy-adjudicator-1.mp4) · [enemy-adjudicator-2](../../output/all-spells-polish-20260921/enemy-adjudicator-2.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-12.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725`

### M29 · 押运锤卫·压舱重击

主线敌人 / 正式/源码可达 / 批次D / 主角1人；两种动画变体

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：平行冲压体现横向压力与锤头重量；不复用裁定锤卫的放射地裂。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.91；缺口 1.00/3；文字矛盾概率 0.08。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|压肩屈膝，锤面低位充能|
|主体与运动|锤势带两道低位压浪前送|
|接触或生效|贴地平行冲压错时爆开|
|持续阶段|铅灰/冷光碎屑低位退去|
|收势与退场|锤头回位，剧情撤退保活|

实录：[enemy-convoy-1](../../output/all-spells-polish-20260921/enemy-convoy-1.mp4) · [enemy-convoy-2](../../output/all-spells-polish-20260921/enemy-convoy-2.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-13.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725`

### M30 · 总签官·铜钟裁断

主线敌人 / 正式/源码可达 / 批次D / 主角1人；同一Boss身体

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：钟环刻度、铜巨手和档案书共同参与动作；弧形铜钟碎面有侧壁，不做平贴插画。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.74；缺口 1.00/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|铜手/钟环聚能，衣摆跟随重心|
|主体与运动|破铜钟扇面定向压来|
|接触或生效|钟面压缩后沿不对称刻度裂开|
|持续阶段|铜屑与金纹错时熄灭|
|收势与退场|铜手收回；Q28/Q29撤退不播真死|

实录：[enemy-chronarch-1](../../output/all-spells-polish-20260921/enemy-chronarch-1.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-13.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725`

### M31 · 总签官·所有权封印

主线敌人 / 正式/源码可达 / 批次D / 主角1人；第二视觉变式

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：以档案书合页和封签覆盖表达，不把铜钟裁断只换颜色。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.81；缺口 1.00/3；文字矛盾概率 0.12。
- 执行判断：先核对整招。先按真实整招与本行候选对照；保留现有主体，发现实际差距再定向精修。低置信度不作为推倒重做理由。

|阶段|本招方案|
|---|---|
|起手与蓄力|档案书页错层翻起、铜手合印|
|主体与运动|封签在目标处逐层叠合|
|接触或生效|真实接触时合页压印后快速裂回|
|持续阶段|印纹保持短暂层次，目标仍可见|
|收势与退场|书页退回同一身体；Q30才允许真死结局|

实录：[enemy-chronarch-2](../../output/all-spells-polish-20260921/enemy-chronarch-2.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-13.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/BattlePrototype.cs`；`docs/development/ALL_SPELLS_POLISH_20260921.md`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725`

### R02 · 僭命勋章

遗落物附效 / 正式白名单附效 / 批次E / 自身；临时生命/上限/攻击增益及结束清算

- 原始证据：源码/规则有此项；85段总览缺少本项独立完整证据，先核对路由与当前整招。
- 保护边界：保持与假面互斥，不借特效改代价。
- 当前候选改法：只设计身体勋章脉动与上下限变化反馈；不把临时生命抬升画成普通治疗。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.99；缺口 1.22/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。

|阶段|本招方案|
|---|---|
|起手与蓄力|手动点亮胸前勋纹|
|主体与运动|纹样贴衣装/躯体向上展开|
|接触或生效|在真实发动回执时激活|
|持续阶段|8秒强弱脉动，保留主角材质|
|收势与退场|按真实清算收缩；胜利/撤退也不漏清算|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-02.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:268`

### R03 · 盐封呼吸囊

遗落物附效 / 正式白名单附效 / 批次E / 自身；有限持续伤害吸收与生命上限封存

- 原始证据：源码/规则有此项；85段总览缺少本项独立完整证据，先核对路由与当前整招。
- 保护边界：持续伤害专用；不吸收直击或自身契约代价。
- 当前候选改法：把吸收量/剩余容量落在囊体盐晶化，避免误导成直接攻击护盾。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.98；缺口 1.34/3；文字矛盾概率 0.08。
- 执行判断：先核对整招。没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。

|阶段|本招方案|
|---|---|
|起手与蓄力|吸收事件前维持低亮|
|主体与运动|毒性细流只向囊体收拢|
|接触或生效|真实吸收才短闪，不制造敌方接触|
|持续阶段|盐晶随容量增长，显示封存而非回血|
|收势与退场|战后解封不补血，状态原位解除|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-03.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:268`

### R04 · 返礼银扣

遗落物附效 / 正式白名单附效 / 批次E / 自身吸收；该次攻击者获得普通盾

- 原始证据：源码/规则有此项；85段总览缺少本项独立完整证据，先核对路由与当前整招。
- 保护边界：并行敌人只能给真实攻击者赠盾。
- 当前候选改法：银扣合拢与攻击者获盾用不同空间端点表现，不撒全场护盾。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.94；缺口 1.19/3；文字矛盾概率 0.09。
- 执行判断：先核对整招。没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。

|阶段|本招方案|
|---|---|
|起手与蓄力|就绪银扣有小范围呼吸光|
|主体与运动|直击抵达才闭合防护|
|接触或生效|吸收与赠盾分别锚定主角/实际攻击者|
|持续阶段|赠盾跟原ID，双方条件满足才重新就绪|
|收势与退场|盾破与冷却完成按实际事件退光|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-03.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:268`

### R05 · 迟签印章

遗落物附效 / 正式白名单附效 / 批次E / 原技能一笔对1敌伤害延后；固定目标

- 原始证据：源码/规则有此项；85段总览缺少本项独立完整证据，先核对路由与当前整招。
- 保护边界：主技能与附效不能重复结算同一笔。
- 当前候选改法：延后伤害沿原目标保留悬置印痕；不重播完整技能蓄力。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.96；缺口 1.36/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。

|阶段|本招方案|
|---|---|
|起手与蓄力|原技能起手保持|
|主体与运动|暂存该笔印痕于原目标|
|接触或生效|3秒后真实结算才压印短爆；作废无命中|
|持续阶段|悬置印痕低亮收紧|
|收势与退场|目标离场/真免伤则熄灭，不能改投|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-03.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:268`

### R06 · 反照墨镜

遗落物附效 / 正式白名单附效 / 批次E / 固定1敌；另一敌直击是触发来源

- 原始证据：源码/规则有此项；85段总览缺少本项独立完整证据，先核对路由与当前整招。
- 保护边界：目标/触发来源是不同角色，不等于两人同时受伤。
- 当前候选改法：镜面赠血与后续反射分清先后；反光沿真实攻击来源往返。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.90；缺口 1.17/3；文字矛盾概率 0.11。
- 执行判断：先核对整招。没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。

|阶段|本招方案|
|---|---|
|起手与蓄力|锁定固定目标后镜面显影|
|主体与运动|赠血用恢复语义，不装成先发攻击|
|接触或生效|只有符合条件直击才反射|
|持续阶段|4秒等待窗口镜纹逐渐变暗|
|收势与退场|未触发直接退光，不退赠血、不补打|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-03.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:268`

### R07 · 缄卷镇纸

遗落物附效 / 正式白名单附效 / 批次E / 自身；封第三槽一次技能换一次直伤收容

- 原始证据：源码/规则有此项；85段总览缺少本项独立完整证据，先核对路由与当前整招。
- 保护边界：原技能全部效果消失，不新增伤害。
- 当前候选改法：强调被封技能消失、卷页压住；不能同时播放原技能完整演出。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.88；缺口 1.33/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。

|阶段|本招方案|
|---|---|
|起手与蓄力|固定第三槽出现封页提示|
|主体与运动|镇纸纹样向主角防护点收紧|
|接触或生效|实际直击被收容才皱缩|
|持续阶段|4秒单次收容，原技能冷却照走|
|收势与退场|未用也解除，绝不补放被封技能|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-03.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:268`

### R08 · 逆潮铜锚

遗落物附效 / 正式白名单附效 / 批次E / 自身；同敌同招的后续两段有限收容

- 原始证据：源码/规则有此项；85段总览缺少本项独立完整证据，先核对路由与当前整招。
- 保护边界：不能把首击画成被免伤；不能收容第三方攻击。
- 当前候选改法：铜锚向内压住后续冲力；第一击额外代价必须仍可见。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.99；缺口 1.30/3；文字矛盾概率 0.11。
- 执行判断：先核对整招。没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。

|阶段|本招方案|
|---|---|
|起手与蓄力|首击真实承伤，不抢先立盾|
|主体与运动|铜锚短拉回，防护贴主角|
|接触或生效|只对窗口内同敌同招后两段反馈|
|持续阶段|2秒窗口最多两次，不用连续爆闪|
|收势与退场|时窗结束锚纹沉下并清空计数表现|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-04.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:268`

### R09 · 归属断线针

遗落物附效 / 正式白名单附效 / 批次E / 固定1敌的外来治疗截取给自身

- 原始证据：源码/规则有此项；85段总览缺少本项独立完整证据，先核对路由与当前整招。
- 保护边界：保留6秒禁疗；不会把所有敌人治疗统一截取。
- 当前候选改法：细针剪断受疗线路并回流主角；不做伤害刺杀。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.98；缺口 1.19/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。

|阶段|本招方案|
|---|---|
|起手与蓄力|锁定固定受疗敌人的线路|
|主体与运动|针尖顺真实外来治疗线移动|
|接触或生效|截取实际发生才分流和绿色实际回血|
|持续阶段|随后自身禁疗用低亮封口纹|
|收势与退场|状态结束解除；失败无伪回血|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-04.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:268`

### R10 · 空栏名片

遗落物附效 / 正式白名单附效 / 批次E / 自身与固定1敌互相不承受彼此直伤3秒

- 原始证据：源码/规则有此项；85段总览缺少本项独立完整证据，先核对路由与当前整招。
- 保护边界：不是无敌盾；不能给其它敌人同样屏蔽。
- 当前候选改法：空白名片两端擦除直伤连线，第三方不受影响。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.97；缺口 1.30/3；文字矛盾概率 0.08。
- 执行判断：先核对整招。没有该项独立整招证据。先核对真实入口再补录；模型缺口分数不能证明画面已经有缺陷。

|阶段|本招方案|
|---|---|
|起手与蓄力|手动摊开空栏名片|
|主体与运动|两个固定端点短暂空白描边|
|接触或生效|互相直伤落空显示克制的小擦痕|
|持续阶段|仅3秒双向直伤隔离，技能照常消耗|
|收势与退场|按时还原，不清除第三方/毒/控制|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-04.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:268`

### L02 · 假面谕令（旧技能02，非手动遗落物）

保留库 / 目录隐藏 / 批次F / 1敌＋自身效果域

- 原始证据：技能02有视觉录像，但visibleSkills明确隐藏maskedWhisper，不是R01手动假面。
- 保护边界：保留库内，不借全法术梳理重新解锁。
- 当前候选改法：保留实体瓷面与自体幻影分域方案；不重新开放隐藏技能。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留库／暂不接入，路线置信度 0.95；缺口 0.06/3；文字矛盾概率 0.09。
- 执行判断：保留库／暂不接入。正式接入/解锁未批准，模型建议核对也不构成上线授权。试演可继续保留对照。

|阶段|本招方案|
|---|---|
|起手与蓄力|瓷面自掌中升起|
|主体与运动|敌方误认面与自身幻影分开|
|接触或生效|各在自己的效果域生效|
|持续阶段|自身承伤状态独立于敌状态|
|收势与退场|两个owner分别清理|

实录：[hero-02](../../output/all-spells-polish-20260921/hero-02.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-16.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700`

### L09 · 后手改写（库内技能09）

保留库 / 库内非第一章常规解锁 / 批次F / 自身；targetID=nil

- 原始证据：9/21已有所列Unity表现实录；未见本招最新整招视觉认可记录，不能据此判断已合格或一定不合格。
- 保护边界：保留现有身份、配色、数值和站位；改法是待实录检验的候选，不是现状缺陷结论。
- 当前候选改法：保留12段回卷页片与自体净化方向；先核对解锁，不将其写成当前第一章获得技能。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.87；缺口 1.00/3；文字矛盾概率 0.08。
- 执行判断：保留库／暂不接入。正式接入/解锁未批准，模型建议核对也不构成上线授权。试演可继续保留对照。

|阶段|本招方案|
|---|---|
|起手与蓄力|手掌收回自体，页片沿袖口聚起|
|主体与运动|12段曲面页片平滑向内翻卷|
|接触或生效|自身净化/强化时局部内收光|
|持续阶段|不向任何敌人放爆炸|
|收势与退场|页片贴身退去，负面清除只由规则驱动|

实录：[hero-09](../../output/all-spells-polish-20260921/hero-09.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-16.response.json)

源码/记录：`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700`

### X01 · 凤凰虹翼

独立试演 / 试演未接正式技能 / 批次F / 正式规则未定；已录1/2/3目标实例，不能据此定为群攻

- 原始证据：有独立Unity多目标试演；模拟拍点不等于正式规则/真机接入。最新force/extreme等观感仍需分开复核。
- 保护边界：不擅自绑定07/08等正式技能；Time.timeScale试演停顿不得搬入正式全局战斗；每目标完整主体，公共镜头反馈一次。
- 当前候选改法：保留连续虹翼曲面与金羽内部纹理；以force/extreme并排定强度，不擅自替换现有技能。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.70；缺口 0.82/3；文字矛盾概率 0.10。
- 执行判断：保留库／暂不接入。正式接入/解锁未批准，模型建议核对也不构成上线授权。试演可继续保留对照。

|阶段|本招方案|
|---|---|
|起手与蓄力|从主角前方低位卷起，羽纹聚向曲面|
|主体与运动|世界空间虹翼扇面推进，前后羽层柔软错位|
|接触或生效|保留宽金羽光与短暂停顿；强度选择待复核|
|持续阶段|羽纹从内部蚀散，不整幅插画漂浮|
|收势与退场|按纹理分片撕散，逐目标独立清理|

实录：[phoenix-1](../../output/target-instances-20260921/phoenix-1.mp4) · [phoenix-2](../../output/target-instances-20260921/phoenix-2.mp4) · [phoenix-3](../../output/target-instances-20260921/phoenix-3.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-15.response.json)

源码/记录：`UnityBattleSource/Assets/Editor/ReferenceSpellsReview20260921.cs`；`docs/development/TARGET_INSTANCES_20260921.md`

### X02 · 霜雷裁决

独立试演 / 试演未接正式技能 / 批次F / 正式规则未定；已录1/2/3目标实例，不能据此定为群攻

- 原始证据：有独立Unity多目标试演；模拟拍点不等于正式规则/真机接入。最新force/extreme等观感仍需分开复核。
- 保护边界：不擅自绑定07/08等正式技能；Time.timeScale试演停顿不得搬入正式全局战斗；每目标完整主体，公共镜头反馈一次。
- 当前候选改法：保留细分雷体与冰晶簇；细岔沿原画走，晶花体量需与过曝同时对照。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.59；缺口 0.78/3；文字矛盾概率 0.12。
- 执行判断：保留库／暂不接入。正式接入/解锁未批准，模型建议核对也不构成上线授权。试演可继续保留对照。

|阶段|本招方案|
|---|---|
|起手与蓄力|细雷体与晶核预聚，冷暖核心分层|
|主体与运动|不等距雷折点，细白芯带青蓝侧纹|
|接触或生效|雷压后冰花迅速撑开并晶簇崩飞|
|持续阶段|短余雷迅速熄灭，冰晶有明暗侧面|
|收势与退场|晶屑错深度退去，不能固定留下发亮三柱|

实录：[thunder-1](../../output/target-instances-20260921/thunder-1.mp4) · [thunder-2](../../output/target-instances-20260921/thunder-2.mp4) · [thunder-3](../../output/target-instances-20260921/thunder-3.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-16.response.json)

源码/记录：`UnityBattleSource/Assets/Editor/ReferenceSpellsReview20260921.cs`；`docs/development/TARGET_INSTANCES_20260921.md`

### X03 · 裂界炎途

独立试演 / 试演未接正式技能 / 批次F / 正式规则未定；已录1/2/3目标实例，不能据此定为群攻

- 原始证据：有独立Unity多目标试演；模拟拍点不等于正式规则/真机接入。最新force/extreme等观感仍需分开复核。
- 保护边界：不擅自绑定07/08等正式技能；Time.timeScale试演停顿不得搬入正式全局战斗；每目标完整主体，公共镜头反馈一次。
- 当前候选改法：保留用户已认可Continuous裂口方向和抬升金边；不恢复红地毯、黑洞或金属锯齿。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：先核对整招，路线置信度 0.39；缺口 0.85/3；文字矛盾概率 0.12。
- 执行判断：保留库／暂不接入。正式接入/解锁未批准，模型建议核对也不构成上线授权。试演可继续保留对照。

|阶段|本招方案|
|---|---|
|起手与蓄力|红热纹沿地表先收紧|
|主体与运动|连续暗裂向目标推进，金边有柔和侧壁|
|接触或生效|目标接触点金白芯与红橙拖尾短爆|
|持续阶段|低位热浪局部流动，保持边缘柔软|
|收势与退场|热纹与金边回落，不声称真实地形开洞|

实录：[rift-1](../../output/target-instances-20260921/rift-1.mp4) · [rift-2](../../output/target-instances-20260921/rift-2.mp4) · [rift-3](../../output/target-instances-20260921/rift-3.mp4)

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T060134046024Z/batch-16.response.json)

源码/记录：`UnityBattleSource/Assets/Editor/ReferenceSpellsReview20260921.cs`；`docs/development/TARGET_INSTANCES_20260921.md`

### N07A · D07 铜背甲兽·铜甲震击（工作名）

新增塔小怪 / 并行制作中／未验收 / 批次G / 主角1人；两招各有charge/charge2，恢复并入整招

- 原始证据：任务“接入教会塔小怪与法术”正在独立接入。当前ChurchTower及ChurchMinionVfx源码已有first/second分支；本表快照未取得完整十招实录及运行回执。
- 保护边界：不抢另一任务的源码修改权，不宣称已装机/视觉通过；名称为本页工作名而非改游戏名。当前代码两种蓄力2.2/2.8秒、contact0.5秒，仅作为并行快照核对，后续以其最终契约为准。
- 当前候选改法：沿并行源码的四道低位错层震片检查身体附着与原画材质层次；两招区分主体/运动，不统一32碎光就算完成。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留库／暂不接入，路线置信度 0.49；缺口 1.93/3；文字矛盾概率 0.11。
- 执行判断：先核对整招。另一任务正在制作，本表只纳入增量快照；待其自产实录/回执按本行核对，不抢写源码、不将进行中内容称验收通过。

|阶段|本招方案|
|---|---|
|起手与蓄力|四足压身、胸甲与骨盆聚能|
|主体与运动|甲缝能量沿地表推出四道不等厚震片|
|接触或生效|真实接触短停后低位掀裂|
|持续阶段|石铜屑快速落低，不留整片发光地板|
|收势与退场|四足/胸背回位，取消只清本施法实例|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T061438136500Z/batch-01.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchDemonPresentation20260917.cs`；`UnityBattleSource/Assets/Scripts/ChurchMinionVfx20260921.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchTower.swift`

### N07B · D07 铜背甲兽·掀甲拱浪（工作名）

新增塔小怪 / 并行制作中／未验收 / 批次G / 主角1人；两招各有charge/charge2，恢复并入整招

- 原始证据：任务“接入教会塔小怪与法术”正在独立接入。当前ChurchTower及ChurchMinionVfx源码已有first/second分支；本表快照未取得完整十招实录及运行回执。
- 保护边界：不抢另一任务的源码修改权，不宣称已装机/视觉通过；名称为本页工作名而非改游戏名。当前代码两种蓄力2.2/2.8秒、contact0.5秒，仅作为并行快照核对，后续以其最终契约为准。
- 当前候选改法：沿并行源码的七片弯拱甲浪检查身体附着与原画材质层次；两招区分主体/运动，不统一32碎光就算完成。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留库／暂不接入，路线置信度 0.49；缺口 1.83/3；文字矛盾概率 0.09。
- 执行判断：先核对整招。另一任务正在制作，本表只纳入增量快照；待其自产实录/回执按本行核对，不抢写源码、不将进行中内容称验收通过。

|阶段|本招方案|
|---|---|
|起手与蓄力|四足后压再抬胸，区别第一招|
|主体与运动|七片弯拱甲纹错深度翻卷|
|接触或生效|接触处拱浪打开后快速收拢|
|持续阶段|宽片先收，小火星后散|
|收势与退场|胸背/骨盆恢复，不用旋转第一招替代|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T061438136500Z/batch-01.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchDemonPresentation20260917.cs`；`UnityBattleSource/Assets/Scripts/ChurchMinionVfx20260921.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchTower.swift`

### N08A · D08 赤蛮魔·拳焰突击（工作名）

新增塔小怪 / 并行制作中／未验收 / 批次G / 主角1人；两招各有charge/charge2，恢复并入整招

- 原始证据：任务“接入教会塔小怪与法术”正在独立接入。当前ChurchTower及ChurchMinionVfx源码已有first/second分支；本表快照未取得完整十招实录及运行回执。
- 保护边界：不抢另一任务的源码修改权，不宣称已装机/视觉通过；名称为本页工作名而非改游戏名。当前代码两种蓄力2.2/2.8秒、contact0.5秒，仅作为并行快照核对，后续以其最终契约为准。
- 当前候选改法：沿并行源码的四指节弯曲拳焰检查身体附着与原画材质层次；两招区分主体/运动，不统一32碎光就算完成。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留库／暂不接入，路线置信度 0.53；缺口 1.73/3；文字矛盾概率 0.09。
- 执行判断：先核对整招。另一任务正在制作，本表只纳入增量快照；待其自产实录/回执按本行核对，不抢写源码、不将进行中内容称验收通过。

|阶段|本招方案|
|---|---|
|起手与蓄力|单臂回收，亮纹贴手背和指节|
|主体与运动|厚拳焰随实际拳势前送|
|接触或生效|弯指节亮脊短压再撑开|
|持续阶段|拳风尾迹断开，避免无源白团|
|收势与退场|肩肘依次回位|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T061438136500Z/batch-01.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchDemonPresentation20260917.cs`；`UnityBattleSource/Assets/Scripts/ChurchMinionVfx20260921.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchTower.swift`

### N08B · D08 赤蛮魔·双拳落砸（工作名）

新增塔小怪 / 并行制作中／未验收 / 批次G / 主角1人；两招各有charge/charge2，恢复并入整招

- 原始证据：任务“接入教会塔小怪与法术”正在独立接入。当前ChurchTower及ChurchMinionVfx源码已有first/second分支；本表快照未取得完整十招实录及运行回执。
- 保护边界：不抢另一任务的源码修改权，不宣称已装机/视觉通过；名称为本页工作名而非改游戏名。当前代码两种蓄力2.2/2.8秒、contact0.5秒，仅作为并行快照核对，后续以其最终契约为准。
- 当前候选改法：沿并行源码的成对下落焰拳检查身体附着与原画材质层次；两招区分主体/运动，不统一32碎光就算完成。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留库／暂不接入，路线置信度 0.54；缺口 1.80/3；文字矛盾概率 0.12。
- 执行判断：先核对整招。另一任务正在制作，本表只纳入增量快照；待其自产实录/回执按本行核对，不抢写源码、不将进行中内容称验收通过。

|阶段|本招方案|
|---|---|
|起手与蓄力|双臂过顶、脊柱承重|
|主体与运动|两团指节焰拳从上方下落|
|接触或生效|双拳接触共用原一次结算，不变两目标|
|持续阶段|下压碎焰快速回收|
|收势与退场|双手和重心恢复，死亡取消零迟到回调|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T061438136500Z/batch-01.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchDemonPresentation20260917.cs`；`UnityBattleSource/Assets/Scripts/ChurchMinionVfx20260921.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchTower.swift`

### N09A · D09 绯幕先知·曲幕咒刃（工作名）

新增塔小怪 / 并行制作中／未验收 / 批次G / 主角1人；两招各有charge/charge2，恢复并入整招

- 原始证据：任务“接入教会塔小怪与法术”正在独立接入。当前ChurchTower及ChurchMinionVfx源码已有first/second分支；本表快照未取得完整十招实录及运行回执。
- 保护边界：不抢另一任务的源码修改权，不宣称已装机/视觉通过；名称为本页工作名而非改游戏名。当前代码两种蓄力2.2/2.8秒、contact0.5秒，仅作为并行快照核对，后续以其最终契约为准。
- 当前候选改法：沿并行源码的三片柔曲咒刃检查身体附着与原画材质层次；两招区分主体/运动，不统一32碎光就算完成。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留库／暂不接入，路线置信度 0.48；缺口 1.85/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。另一任务正在制作，本表只纳入增量快照；待其自产实录/回执按本行核对，不抢写源码、不将进行中内容称验收通过。

|阶段|本招方案|
|---|---|
|起手与蓄力|长爪与手腕收聚，鸟面具/腰铃仍可读|
|主体与运动|三片柔曲绯幕前送，边缘有厚薄|
|接触或生效|接触沿曲面错向裂开|
|持续阶段|布纹由内蚀散，不变硬金属片|
|收势与退场|长爪松开、披袍回落|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T061438136500Z/batch-01.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchDemonPresentation20260917.cs`；`UnityBattleSource/Assets/Scripts/ChurchMinionVfx20260921.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchTower.swift`

### N09B · D09 绯幕先知·交幕裁裂（工作名）

新增塔小怪 / 并行制作中／未验收 / 批次G / 主角1人；两招各有charge/charge2，恢复并入整招

- 原始证据：任务“接入教会塔小怪与法术”正在独立接入。当前ChurchTower及ChurchMinionVfx源码已有first/second分支；本表快照未取得完整十招实录及运行回执。
- 保护边界：不抢另一任务的源码修改权，不宣称已装机/视觉通过；名称为本页工作名而非改游戏名。当前代码两种蓄力2.2/2.8秒、contact0.5秒，仅作为并行快照核对，后续以其最终契约为准。
- 当前候选改法：沿并行源码的四片斜向交剪曲幕检查身体附着与原画材质层次；两招区分主体/运动，不统一32碎光就算完成。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留库／暂不接入，路线置信度 0.47；缺口 2.09/3；文字矛盾概率 0.13。
- 执行判断：先核对整招。另一任务正在制作，本表只纳入增量快照；待其自产实录/回执按本行核对，不抢写源码、不将进行中内容称验收通过。

|阶段|本招方案|
|---|---|
|起手与蓄力|双手交错外展，蓄力区别直送|
|主体与运动|四片斜向曲幕相互交剪|
|接触或生效|交点短压后错层张开，避免仅转第一招|
|持续阶段|碎幕沿纹理收卷|
|收势与退场|手臂披袍归位，跨关清实例|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T061438136500Z/batch-02.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchDemonPresentation20260917.cs`；`UnityBattleSource/Assets/Scripts/ChurchMinionVfx20260921.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchTower.swift`

### N10A · D10 金喉树蛙·囊声弹（工作名）

新增塔小怪 / 并行制作中／未验收 / 批次G / 主角1人；两招各有charge/charge2，恢复并入整招

- 原始证据：任务“接入教会塔小怪与法术”正在独立接入。当前ChurchTower及ChurchMinionVfx源码已有first/second分支；本表快照未取得完整十招实录及运行回执。
- 保护边界：不抢另一任务的源码修改权，不宣称已装机/视觉通过；名称为本页工作名而非改游戏名。当前代码两种蓄力2.2/2.8秒、contact0.5秒，仅作为并行快照核对，后续以其最终契约为准。
- 当前候选改法：沿并行源码的六瓣膨胀声压检查身体附着与原画材质层次；两招区分主体/运动，不统一32碎光就算完成。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留库／暂不接入，路线置信度 0.51；缺口 2.11/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。另一任务正在制作，本表只纳入增量快照；待其自产实录/回执按本行核对，不抢写源码、不将进行中内容称验收通过。

|阶段|本招方案|
|---|---|
|起手与蓄力|喉囊左右与喉部真实鼓胀|
|主体与运动|六瓣厚薄不同声压沿前方推进|
|接触或生效|接触声瓣压缩再迅速膨开|
|持续阶段|柔薄声屑消退，不长时间完整圆环|
|收势与退场|喉囊回缩、躯干恢复|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T061438136500Z/batch-02.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchDemonPresentation20260917.cs`；`UnityBattleSource/Assets/Scripts/ChurchMinionVfx20260921.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchTower.swift`

### N10B · D10 金喉树蛙·扁声压浪（工作名）

新增塔小怪 / 并行制作中／未验收 / 批次G / 主角1人；两招各有charge/charge2，恢复并入整招

- 原始证据：任务“接入教会塔小怪与法术”正在独立接入。当前ChurchTower及ChurchMinionVfx源码已有first/second分支；本表快照未取得完整十招实录及运行回执。
- 保护边界：不抢另一任务的源码修改权，不宣称已装机/视觉通过；名称为本页工作名而非改游戏名。当前代码两种蓄力2.2/2.8秒、contact0.5秒，仅作为并行快照核对，后续以其最终契约为准。
- 当前候选改法：沿并行源码的四道扁平不对称声压面检查身体附着与原画材质层次；两招区分主体/运动，不统一32碎光就算完成。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留库／暂不接入，路线置信度 0.50；缺口 2.06/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。另一任务正在制作，本表只纳入增量快照；待其自产实录/回执按本行核对，不抢写源码、不将进行中内容称验收通过。

|阶段|本招方案|
|---|---|
|起手与蓄力|低身收喉后前推，区别声弹|
|主体与运动|四道扁平声压面拉宽且错时推进|
|接触或生效|接触横向短撑，不复用圆球爆炸|
|持续阶段|声压面变薄快速衰减|
|收势与退场|喉囊/前肢归位，取消不遗留持续波|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T061438136500Z/batch-02.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchDemonPresentation20260917.cs`；`UnityBattleSource/Assets/Scripts/ChurchMinionVfx20260921.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchTower.swift`

### N11A · D11 月牙鼠·双月牙突袭（工作名）

新增塔小怪 / 并行制作中／未验收 / 批次G / 主角1人；两招各有charge/charge2，恢复并入整招

- 原始证据：任务“接入教会塔小怪与法术”正在独立接入。当前ChurchTower及ChurchMinionVfx源码已有first/second分支；本表快照未取得完整十招实录及运行回执。
- 保护边界：不抢另一任务的源码修改权，不宣称已装机/视觉通过；名称为本页工作名而非改游戏名。当前代码两种蓄力2.2/2.8秒、contact0.5秒，仅作为并行快照核对，后续以其最终契约为准。
- 当前候选改法：沿并行源码的上下错层双月牙检查身体附着与原画材质层次；两招区分主体/运动，不统一32碎光就算完成。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留库／暂不接入，路线置信度 0.48；缺口 2.17/3；文字矛盾概率 0.11。
- 执行判断：先核对整招。另一任务正在制作，本表只纳入增量快照；待其自产实录/回执按本行核对，不抢写源码、不将进行中内容称验收通过。

|阶段|本招方案|
|---|---|
|起手与蓄力|贴地收身，头部与尾尖聚光|
|主体与运动|上下两枚冷月牙随突袭前送|
|接触或生效|上下咬合短裂，仍为主角1人|
|持续阶段|尖端细尾光迅速断开|
|收势与退场|身体/尾链回原站位|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T061438136500Z/batch-02.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchDemonPresentation20260917.cs`；`UnityBattleSource/Assets/Scripts/ChurchMinionVfx20260921.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchTower.swift`

### N11B · D11 月牙鼠·旋牙尾扫（工作名）

新增塔小怪 / 并行制作中／未验收 / 批次G / 主角1人；两招各有charge/charge2，恢复并入整招

- 原始证据：任务“接入教会塔小怪与法术”正在独立接入。当前ChurchTower及ChurchMinionVfx源码已有first/second分支；本表快照未取得完整十招实录及运行回执。
- 保护边界：不抢另一任务的源码修改权，不宣称已装机/视觉通过；名称为本页工作名而非改游戏名。当前代码两种蓄力2.2/2.8秒、contact0.5秒，仅作为并行快照核对，后续以其最终契约为准。
- 当前候选改法：沿并行源码的单旋月牙＋低位尾痕检查身体附着与原画材质层次；两招区分主体/运动，不统一32碎光就算完成。
- 新增硬约束：全阶段禁止规则几何图元式轮廓；新增要求不是此前Jev回执的审核结论。
- Jev（此前原始文字方案）：保留库／暂不接入，路线置信度 0.44；缺口 2.00/3；文字矛盾概率 0.10。
- 执行判断：先核对整招。另一任务正在制作，本表只纳入增量快照；待其自产实录/回执按本行核对，不抢写源码、不将进行中内容称验收通过。

|阶段|本招方案|
|---|---|
|起手与蓄力|身体侧拧，尾部发力|
|主体与运动|单月牙转入并带一条低尾痕|
|接触或生效|宽低弧裂接触后快收，不是双月牙换色|
|持续阶段|低位尾痕逐段淡去|
|收势与退场|头尾与腰恢复，重复施法不积累姿态|

实录：85段总览中无独立完整样本，先补入口核对/录制。

[Jev原始回执](../../output/jev-spell-plan-20260921/run-/20260922T061438136500Z/batch-02.response.json)

源码/记录：`UnityBattleSource/Assets/Scripts/ChurchDemonPresentation20260917.cs`；`UnityBattleSource/Assets/Scripts/ChurchMinionVfx20260921.cs`；`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChurchTower.swift`

## 暂停和旧目录附录

不把以下保留项算成当前制作完成；不重新开放奖励、装备或触发入口。

|原审计项|名称|处理|
|---|---|---|
|10|03 纸偶替身（旧分支）|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|25|不肯落幕的铃|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|26|偏差透镜|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|27|迟滞铜片|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|28|记忆蛭标本|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|29|借声铜铃|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|30|预警录片|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|31|追猎者断刺|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|32|镜潮银线|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|33|裁去的名牌|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|34|三证环|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|35|空白戏票|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|36|雾锚碎片|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|37|空白名牌|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|38|矛盾证词|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|39|回收封签|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|40|借位绳结|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|41|红蜡证印|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|42|盐晶存片|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|43|拒认契据|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|44|折返路签|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|45|追加证词|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|46|错页夹|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|47|归航盐片|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|48|无主印章|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|101|D00犬双火／扑咬|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|
|102|核心archive_repair／calibrate／transfer|暂停/旧库：不重新开放、不伪造完整攻击法术；保留历史数据与资产。|

## 方法来源

[TypeSafe API](https://docs.typesafe.ai/api) · [Choice](https://docs.typesafe.ai/primitives/choice) · [证据核对示例](https://docs.typesafe.ai/cookbooks/citation_check)

采用 typesafe-ai 的类型化判断和 game-spell-impact 的整招、独立目标及真实实录边界；没有将技能里的样本参数统一强加到所有法术。
