# 全法术目标与表现审计 · 2026-09-21

当前按代码核对目标语义，不改伤害、不声称所有特效已经重做。单体只生成一个目标实例；最多2人与最多3人是上限；全体是所有有效目标，绝不能写死3。多段次数、弹体数量、状态作用域必须另列。新三招仍未绑定正式目标规则。

|范围|法术|目标类型|规则与边界|按skill的表现要求|当前状态|来源|
|---|---|---|---|---|---|---|
|主角|01 错步穿行|最多2敌|主目标＋另一存活敌；第二目标在首击前选择，避免击杀分裂后临时补打|一目标一路、两目标两路；每目标两个完整残影，分别裂开。|核心可核对；视觉拆分需逐招验收|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700|
|主角|02 假面谕令（技能）|1敌＋自身|选中敌伤害/误认；自身幻影承伤是另一效果域|目标处施加误认，自身幻影单独表现；不能当两敌。|核心可核对；视觉拆分需逐招验收|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700|
|主角|04 身份错置|1敌|仅选中目标的误认转换、控制/伤害|一处错位裂隙；零伤控制不伪造伤害爆炸。|核心可核对；视觉拆分需逐招验收|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700|
|主角|05 伪证烙印|1敌|选中目标烙印，后续增伤不新增目标|一个烙印与一次落印爆点。|核心可核对；视觉拆分需逐招验收|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700|
|主角|06 错影追猎|1敌／2段|两段打同一人，不等于两个人|两次独立接触，追击轨迹均指向同一目标。|核心可核对；视觉拆分需逐招验收|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700|
|主角|07 荒谬归结|1敌|基础与条件追加均在选中目标|单目标大终结；追加段不得误显示第二目标。|核心可核对；视觉拆分需逐招验收|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700|
|主角|08 反客为主|1敌／状态|选中敌驱散或误认，返回伤害0|单目标夺取/破印，不能全场伤害爆闪。|核心可核对；视觉拆分需逐招验收|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700|
|主角|09 后手改写|自身|净化/强化自身，targetID=nil|自身收束净化，不向敌人炸开。|核心可核对；视觉拆分需逐招验收|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700|
|主角|10 无名宣告|全体敌／状态|遍历foolStates加误认/准备；不是固定3人，不造成直接伤害|共享舞台可保留，但每个有效敌人独立状态落点；4敌也必须覆盖4个。|核心可核对；视觉拆分需逐招验收|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700|
|主角|03 纸偶替身（旧分支）|自身／召唤|保留paperDouble代码；当前技能内容目录不列此项|预备/旧功能，不据旧录制重新启用。|核心可核对；视觉拆分需逐招验收|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1493–1700|
|主角|普通攻击|1敌|选中有效目标；不由屏幕敌人数扩大范围|一条路径和一个接触点|需与当前普攻路由对照|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift|
|新试演|凤凰虹翼|规则未定／演示3敌|三敌录制不是固定三目标或全体的技能契约；不得擅自绑定07/08等旧技能规则|单敌一束完整虹翼，双敌两束、三敌三束；每束完整纹理与自然边缘。|需实现并验证1/2/3/全体模式|UnityBattleSource/Assets/Editor/ReferenceSpellsReview20260921.cs|
|新试演|霜雷裁决|规则未定／演示3敌|三敌录制不是固定三目标或全体的技能契约；不得擅自绑定07/08等旧技能规则|每个目标独立雷路、落点冰晶和接触爆发。|需实现并验证1/2/3/全体模式|UnityBattleSource/Assets/Editor/ReferenceSpellsReview20260921.cs|
|新试演|裂界炎途|规则未定／演示3敌|三敌录制不是固定三目标或全体的技能契约；不得擅自绑定07/08等旧技能规则|窄通道指向单敌；多目标分支或独立通道，禁止光毯覆盖未选中敌。|需实现并验证1/2/3/全体模式|UnityBattleSource/Assets/Editor/ReferenceSpellsReview20260921.cs|
|遗落物附效|迟签印章|原技能的一笔1敌伤害|技能的一笔直接伤害延后3秒，并追加有限伤害。 代价：目标离场或届时真免伤则作废；12秒冷却。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|目录可用白名单|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|反照墨镜|锁定1敌，另一敌为触发来源|锁定2秒后普攻赠血，换另一个敌人的一次直击反射。 代价：先送血再等4秒，落空不退；8秒冷却。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|目录可用白名单|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|缄卷镇纸|自身|封掉固定第3槽的一次技能，建立4秒一次直伤收容。 代价：原技能全部效果消失，卡牌冷却照常；18秒冷却。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|目录可用白名单|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|逆潮铜锚|自身|同敌同招首击后2秒内下两段收容有限直伤。 代价：首击额外承受5%入场生命；10秒冷却。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|目录可用白名单|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|归属断线针|锁定1敌＋自身受疗|截取选中敌人收到的外来治疗给自己。 代价：随后6秒自己不能回血；每场两次、12秒冷却。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|目录可用白名单|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|空栏名片|自身与固定1敌|主动3秒与固定敌人互不承受彼此直伤。 代价：自己的技能照常消耗；第三方、毒伤和控制不受影响。18秒冷却。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|目录可用白名单|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|盐封呼吸囊|自身|被动吸收部分持续伤害，容量有限；不吸收直接攻击或遗落物自身代价。 代价：每吸收10点伤害，正常生命上限暂时封存1点；战后解封不补血。第4关后商店120铜币。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|目录可用白名单|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|返礼银扣|自身防护＋该攻击者获盾|就绪时吸收下一次直接攻击，最多为入场生命上限的30%。 代价：攻击者立即获得吸收量一半的普通护盾；8秒冷却与赠盾破除均满足才再就绪。第4关后160铜币。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|目录可用白名单|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|僭命勋章|自身|手动发动8秒：当前生命与生命上限提高50%，攻击力提高30%。24秒冷却，与假面互斥。 代价：结束时交出剩余生命的一半，再恢复正常上限；胜利和撤退同样清算。绑定不可出售。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|目录可用白名单|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|假面谕令|自身|手动使用，4秒内承接最多两次直接攻击；所有持续伤害均无效且不消耗次数。18秒冷却，不占卡牌编排。 代价：每次使用永久增加一道暗紫裂纹，十道后彻底失效；第十次正常生效。第3、4关教学不增加裂纹。失败或退出不返还。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|目录可用白名单|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|不肯落幕的铃|条件效果／不新增目标|手动打断翠焰亡灵蓄力，使本次攻击延后3秒；返场时该次攻击伤害提高50%。 代价：延后的攻击不会消失，返场时会以更高伤害归还。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|偏差透镜|条件效果／不新增目标|攻击4层误认目标时获得20%穿甲。攻击0层误认目标时伤害降低8%。 代价：必须在目标状态之间做取舍。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|迟滞铜片|条件效果／不新增目标|成功应对已公布的强攻或避开攻击后，下回合额外执行1张普通技能；每场最多2次。 代价：只奖励对敌方意图的准确判断。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|记忆蛭标本|条件效果／不新增目标|净化自身负面状态后，下一张铺垫技能额外施加1层误认。 代价：首次触发损失5%当前生命。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|借声铜铃|条件效果／不新增目标|AI第一次造成破绽或降低防御时，获得10%最大生命护盾。 代价：同一轮不能重复触发。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|预警录片|条件效果／不新增目标|每3回合揭示额外敌方意图。揭示回合玩家伤害降低8%。 代价：信息越多，行动越需要克制。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|追猎者断刺|条件效果／不新增目标|完成一轮普通技能而未使用荒谬归结时，下一轮第一张伤害技能提高25%。 代价：只有坚持循环才会生效。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|镜潮银线|条件效果／不新增目标|错影追猎第二击命中错位目标后，敌方下一次攻击提高20%。 代价：风险会被转移，但不会消失。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|裁去的名牌|条件效果／不新增目标|敌方驱散玩家增益时，给该敌人施加2层误认。 代价：每次触发使玩家下一次治疗减少30%。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|三证环|条件效果／不新增目标|一轮内完成铺垫、攻击、反制或净化三种不同类别行动时，获得10%最大生命护盾，并强化下一次有伤害的攻击20%。 代价：触发后，下一次实际结算到自身生命或护盾的敌方直接攻击提高25%；幻影承伤不消耗此负面，重复触发只刷新、不叠加。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|空白戏票|条件效果／不新增目标|荒谬归结未消耗错位时，下一轮第一张身份错置额外施加1层误认；每场最多2次。 代价：需要主动保留一次错误。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|雾锚碎片|条件效果／不新增目标|返场或其他复起效果触发后，获得15%最大生命护盾，下一次伤害降低20%。 代价：每场战斗只承认第一次归来。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|空白名牌|条件效果／不新增目标|首次攻击新目标时，额外施加1层误认。 代价：换目标本身就是一种叙述。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|矛盾证词|条件效果／不新增目标|同时拥有误认和错位的目标，额外承受10%玩家伤害。 代价：必须先完成转换再兑现。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|回收封签|条件效果／不新增目标|身份错置消耗误认时恢复4%最大生命，每回合一次。 代价：把错误回收，才有下一次犯错的余地。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|借位绳结|条件效果／不新增目标|目标死亡或切换目标后，下一次攻击提高15%，新目标额外获得1层误认。 代价：鼓励主动切换攻击对象。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|红蜡证印|条件效果／不新增目标|伪证烙印额外施加1层误认，但该技能基础伤害降低10%。 代价：更强铺垫换来更慢的当下。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|盐晶存片|条件效果／不新增目标|身份错置将4层误认转换为错位时，保留2层误认。 代价：让转换后的循环更快回到上限。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|拒认契据|条件效果／不新增目标|敌方成功驱散玩家增益时，该敌人获得1回合错位；每场最多2次。 代价：把对方的校正变成破绽。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|折返路签|条件效果／不新增目标|每4张普通技能执行后，以60%效果重复本轮第一张技能；重复不会再次触发自身。 代价：固定循环可以被一次折返打乱。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|追加证词|条件效果／不新增目标|每个循环第一次使用铺垫技能后，下一张攻击技能额外重复一次，重复效果为50%。 代价：只在铺垫确实转入攻击时生效。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|错页夹|条件效果／不新增目标|第1格与第2格属于不同技能类别时，第2格技能效果提高15%。 代价：战前顺序必须有意制造类别差异。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|归航盐片|条件效果／不新增目标|生命首次低于40%时恢复6%最大生命；下一次行动延迟无效。 代价：每场只承认第一次濒危。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|遗落物附效|无主印章|条件效果／不新增目标|装备后，无名宣告对全体敌人施加2层误认；无名宣告后，下一次满足原有4层条件的成功身份错置不消耗误认，成功使用后恢复正常。 代价：用较少的初始误认换取一次不消耗误认的转换；条件不足时不消耗这次机会。|状态/治疗/护盾独立表现；重复技能继承原目标契约，不把段数当人数。|旧/暂停目录，不当当前法术|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:263,362|
|正式塔|D01盾颚 · 锁甲|自身|准备或防御，不造成伤害。|跟随身体，不向敌方生成命中爆闪。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D01盾颚 · 过顶蓄力|自身|准备或防御，不造成伤害。|跟随身体，不向敌方生成命中爆闪。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D01盾颚 · 重砸 archive_slam|主角1人|多动作/多弹道不改变目标人数。|主角实际承伤点独立爆发；幻影承接按真实接收者。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D02盐囊 · 盐囊蓄力|自身|准备或防御，不造成伤害。|跟随身体，不向敌方生成命中爆闪。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D02盐囊 · 有限毒息 tower_poison|主角持续伤害|多动作/多弹道不改变目标人数。|有限毒雾持续表现；每次毒跳不做全屏震动/重停顿。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D02盐囊 · 盐晶刺 tower_salt_spike|主角1人|多动作/多弹道不改变目标人数。|主角实际承伤点独立爆发；幻影承接按真实接收者。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D03背囊 · 挤囊准备|自身|准备或防御，不造成伤害。|跟随身体，不向敌方生成命中爆闪。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D03背囊 · 恢复 tower_mend|友军1名|D03选一个受伤非背囊/非核心友军；D05选一个存活非蛇冠友军。收件人固定，死亡不自动改投。|只在实际受益者落状态；治疗/强化不用伤害炸裂。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D03背囊 · 短扑 tower_short_pounce|主角1人|多动作/多弹道不改变目标人数。|主角实际承伤点独立爆发；幻影承接按真实接收者。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D04剪肢 · 单刃蓄力|自身|准备或防御，不造成伤害。|跟随身体，不向敌方生成命中爆闪。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D04剪肢 · 举刃准备|自身|准备或防御，不造成伤害。|跟随身体，不向敌方生成命中爆闪。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D04剪肢 · 第一快切|主角1人|多动作/多弹道不改变目标人数。|主角实际承伤点独立爆发；幻影承接按真实接收者。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D04剪肢 · 第二反切|主角1人|多动作/多弹道不改变目标人数。|主角实际承伤点独立爆发；幻影承接按真实接收者。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D04剪肢 · 双刃重切|主角1人|多动作/多弹道不改变目标人数。|主角实际承伤点独立爆发；幻影承接按真实接收者。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D05蛇冠 · 展冠准备|自身|准备或防御，不造成伤害。|跟随身体，不向敌方生成命中爆闪。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D05蛇冠 · 展冠强化 tower_empower|友军1名|D03选一个受伤非背囊/非核心友军；D05选一个存活非蛇冠友军。收件人固定，死亡不自动改投。|只在实际受益者落状态；治疗/强化不用伤害炸裂。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D05蛇冠 · 声矢|主角1人|多动作/多弹道不改变目标人数。|主角实际承伤点独立爆发；幻影承接按真实接收者。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D06骨爪 · 骨爪准备|自身|准备或防御，不造成伤害。|跟随身体，不向敌方生成命中爆闪。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D06骨爪 · 穿刺|主角1人|多动作/多弹道不改变目标人数。|主角实际承伤点独立爆发；幻影承接按真实接收者。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D06骨爪 · 尾扫|主角1人|多动作/多弹道不改变目标人数。|主角实际承伤点独立爆发；幻影承接按真实接收者。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|正式塔|D06骨爪 · 过顶重爪|主角1人|多动作/多弹道不改变目标人数。|主角实际承伤点独立爆发；幻影承接按真实接收者。|正式六恶魔；需按新标准逐招复核|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2521|
|主线敌人|空壳守卫·赤弧斩|主角1人|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2711|
|主线敌人|空壳守卫·重甲架势|自身|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2549|
|主线敌人|幽灵·雾钟震魂|主角1人|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2713|
|主线敌人|幽灵·幽雾追魂|主角1人|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2713|
|主线敌人|早犬·试探火球|主角1人|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2582|
|主线敌人|早犬·第一追索火球|主角1人|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2583|
|主线敌人|早犬·第二追索火球|主角1人|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2583|
|主线敌人|犬·冥火喷吐／后期地火视觉|主角1人|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2599|
|主线敌人|翠焰亡灵·翠毒漫天|环境雾／主角持续伤害|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2024|
|主线敌人|翠焰亡灵·返场毒爆|主角1人|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2589|
|主线敌人|档案守卫·封存装甲|自身|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2549|
|主线敌人|档案守卫·封档重击|主角1人|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2551|
|主线敌人|档案守卫·重新校准|自身收势|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2549|
|主线敌人|寄忆核心·记忆冲击|主角1人|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2559|
|主线敌人|寄忆核心·定向修复|受伤友军1名|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2560|
|主线敌人|记忆蛭·三次试探|主角1人／3次|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2576|
|主线敌人|记忆蛭·吞名|主角1人|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2576|
|主线敌人|抄录傀儡·强化|自身|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2593|
|主线敌人|抄录傀儡·校准驱盾|主角1人／状态|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1974|
|主线敌人|抄录傀儡·重击|主角1人|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2711|
|主线敌人|精英守卫·校正重击|主角1人|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2711|
|主线敌人|维娅·准备|自身|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725|
|主线敌人|维娅·攻击／memory_breath|主角1人|单人战斗；多颗弹、多段、范围外观均不代表多个玩家。|准备/状态/持续雾与直接命中分别表现。|按实际关卡pattern；库中旧动作不自动启用|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725|
|后半章源码|自动签发执行者 · 攻击／重击|主角1人|源码有后半章覆盖，不据此声称30关真机开放。|每段落到主角/真实承接者；Boss循环数不是目标数。|后半编队源码；开放/手机未本次核实|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725|
|后半章源码|自动签发执行者 · 准备／防御／恢复|自身|具体动作随关卡pattern，不扩为群体技能。|准备、受击与恢复区别；recover不伪造回血。|同上|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725|
|后半章源码|裁定锤卫 · 攻击／重击|主角1人|源码有后半章覆盖，不据此声称30关真机开放。|每段落到主角/真实承接者；Boss循环数不是目标数。|后半编队源码；开放/手机未本次核实|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725|
|后半章源码|裁定锤卫 · 准备／防御／恢复|自身|具体动作随关卡pattern，不扩为群体技能。|准备、受击与恢复区别；recover不伪造回血。|同上|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725|
|后半章源码|押运锤卫 · 攻击／重击|主角1人|源码有后半章覆盖，不据此声称30关真机开放。|每段落到主角/真实承接者；Boss循环数不是目标数。|后半编队源码；开放/手机未本次核实|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725|
|后半章源码|押运锤卫 · 准备／防御／恢复|自身|具体动作随关卡pattern，不扩为群体技能。|准备、受击与恢复区别；recover不伪造回血。|同上|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725|
|后半章源码|总签官 · 攻击／重击|主角1人|源码有后半章覆盖，不据此声称30关真机开放。|每段落到主角/真实承接者；Boss循环数不是目标数。|后半编队源码；开放/手机未本次核实|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725|
|后半章源码|总签官 · 准备／防御／恢复|自身|具体动作随关卡pattern，不扩为群体技能。|准备、受击与恢复区别；recover不伪造回血。|同上|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2725|
|旧预备|D00犬双火／扑咬|主角1人|不属于正式塔D01–D06。|保留资产，不加回塔。|预备|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2548|
|旧预备|核心archive_repair／calibrate／transfer|单友军／转移两端|旧库三种支持分支；当前主线被repair_guard,memory_strike覆盖。|不能当现役四技能全套。|旧库|mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:2618|

## 必须补齐的目标模式验收

- 1/2/3/4个存活敌人：单体始终1；双目标最多2；三目标若获批准最多3；全体等于有效存活数。
- 双目标不足2时不复制主目标；不要把额外攻击段填入新敌人。
- 主目标与次目标去重、稳定ID绑定，目标退场按正式契约取消或改选，不能擅自移伤害。
- 同一拍多目标只触发一次公共停顿/镜头震动，每目标各自一次contact；多段逐段记录。
- 共享背景层可以跨战场，攻击主体与接触层只绑定实际目标；状态全体不是伤害全体。
- 当前新试演使用固定位置数组，尚不具备完整移动/退场绑定；三人虹翼仍是共享大面，拆分是待实现，不是已完成。

## 源码发现

错步内容说明写次目标50%，当前EncounterRuntime的次目标分支未见明确×50%步骤；目标数量结论明确，伤害比例存在文案/代码差异，另行验证，本次不修改数值。无名宣告遍历foolStates而非显式alive列表，正式接入视觉时需核对死亡状态过滤。目录技能假面与手动遗落物假面是不同入口，不能合并成同一攻击技能。
