# 不肯落幕的铃：实时手感试演 v2

用户批准继续测试：所有遗落物必须有负面效果。铃有明确代价，不以次数限制冒充代价。

- 仍为独立参数 `--preview-chapter-one-encore-bell`，正式第五关故事、敌人、美术、存档迁移未完成。
- 战前必须手动选牌；空编排只有普攻。试演选入假面后不会自动施放，战中点击上方假面卡召唤。
- 假面立即召唤幻影，持续4秒、承接一次指向攻击，12秒冷却。输出技能及普攻继续自动；假面在此试演不再附带自动伤害。正式关卡的原假面不改。
- 敌人全身蓄火3秒。铃每场一次，延后当前蓄力3秒；返场攻击伤害提高50%，当前测试198→297。假人寿命不延长。
- 无假人时也必须承担297；有及时假人可承接；提前放假人再摇铃可能导致假人先消失。随后攻击恢复198。
- 延迟期间击杀敌人取消未发出攻击；已经发射的攻击仍按真实接触结算。
- 敌人试演生命2400（v1原模型太脆，无法演完机制）；这不是正式第五关平衡。
- 铃使用透明位图，战场侧前方出现并摆动2.4秒；敌人火焰被压低但保持到返场；假人最后0.8秒淡出。

## 验证状态
- 159项核心测试通过，见 `/tmp/encore-negative-tests.log`。涵盖297/198、一次性、无假面也加伤、假人承接、提前过期、12秒冷却及原有规则回归。
- Unity导出成功，见 `/tmp/encore-negative-unity-export.log`。
- v2模拟器与截图尚待本轮完成后追加。旧v1实战录像在 `output/encore-bell/battle-process*.mov`，不能当作新负面效果版本证据。

## 资产
内置imagegen编辑已有铃，生成真实alpha透明图 `mistport-ios/Mistport/Assets.xcassets/ItemEncoreBellCutout.imageset/art.png`，sips确认hasAlpha=yes。原图保留。编辑提示：保留原铃、把手与缎带，移除全部背景、无新增物体文字，输出透明alpha。

以下为v1历史记录，其中“伤害不变”已被v2的负面效果覆盖：

# 不肯落幕的铃：实时手感原型

用户批准试做：战前手动选牌，战中普攻/技能自动执行，主动遗落物由玩家点击。不是回合制，不暂停玩家或全局时间。

## 本次边界
独立启动参数 `--preview-chapter-one-encore-bell`，进入第五关战斗试演；玩家默认没有选牌。使用现有猎犬临时展示，标签明确标注临时模型；不是第五关最终敌人。移除该试演会话中的纸人保命效果，不改正式奖励、剧情、经验、背包或旧存档。正式第五关替换仍待手感确认及新模型。

## 规则
- 每次敌人攻击前增加3秒可读蓄力，之后沿用原攻击与实际Unity接触结算。
- 仅蓄力期间可以点击铃，每场一次。点击把该蓄力结束时间推后3秒（保留原来尚未结束的蓄力时间）。
- 玩家普攻、技能顺序、冷却均继续；不增加伤害、护盾、净化或替身。
- 返场后正常发射原攻击，只结算一次，不追加第二击。
- 蓄力/延后期间击杀敌人，尚未发出的攻击取消；已经发出的攻击仍按原有接触规则兑现。
- 无效点击不消耗，重试重置；离场、敌人死亡清除特效。
- 原型用按钮状态、金光和声波表达，暂未制作新敌人的真实谢幕动作。这里只验证操作与计时，暂未增加弱点伤害倍率。

## 美术
内置 imagegen 生成 `mistport-ios/Mistport/Assets.xcassets/ItemEncoreBell.imageset/art.png`。

Prompt: Create a single square raster inventory item illustration for a premium gothic occult fantasy RPG. An antique cracked silver handbell called The Bell That Refuses the Final Curtain: elegant dark carved ebony handle, aged silver bell with restrained gilded theatre-curtain relief, one visible fine crack glowing faintly warm gold, frayed burgundy ribbon tied around handle. Entire bell visible, strong readable silhouette at small size, centered 3/4 view filling 80 percent frame. Painterly realistic game item rendering with luxurious worn metal texture, dramatic soft rim light. Plain nearly black plum background matching dark purple fantasy inventory icons. No text, no letters, no UI, no border, no diagram, no vector style, no hands.

声音：Unity合成短铃声，暂用音效，不代表最终声音设计。

## 验证
待本轮构建和模拟器实测后追加实际证据。核心状态测试覆盖有效窗口、迟点、连点、返场一次、敌人死亡、重置。集成规则测试覆盖暂缓时玩家出招、原伤害不变及击杀/已发射攻击边界；不以这些测试代替模拟器验证。

## v3表现修正（用户指出花瓣感）
确认原蓄火误用整张四格Fire.png，且原共享shader只取alpha忽略灰度细节；随机旋转使火焰像红色花瓣。
改用Fire_Single.png、独立EncoreFlame.shader保留灰度火焰细节和加色发光，旋转限制在向上方向附近。共享火球shader不改。
战场铃从108×150改为160×220，透明度0.62及screen混合。仅战场显现，不把按钮变得难以识别。修改后待构建与实际截图。

v3实际证据：Unity导出与iOS构建通过（/tmp/encore-flamefix-export.log、/tmp/encore-flamefix-build.log），已安装。CUA手动选入假面、开始战斗、摇铃并手动召唤幻影；截图可见放大半透明铃、玩家持续普攻与假人出现。视频 output/encore-bell/ethereal-bell-confirm.mov；实战帧 ethereal-frames/frame-30.png 清晰展示铃与玩家命中，非生成预览。假面承接返场完整链仍需精确复测，不能仅凭假人出现宣布通过。当前火焰修复花瓣贴图问题，尚未达到用户动画参考的层次与整体演出水准。

## v4 铃淡化与蓄火分层
用户要求铃进一步虚幻、无棕色高亮底。战场显影峰值从0.62降为0.42，0.16秒淡入、最后0.6秒淡出，光晕透明度降为0.3。按钮保持无背景。iOS构建通过（/tmp/encore-fade-build.log），实际点击开始及摇铃已观察透明效果；真实录像 output/encore-bell/faded-bell-v4.mov，第12秒帧 faded-v4-frames/frame-12.png。
蓄火新增贴身火、向上火舌、稀疏余烬三层，继续复用单火焰位图与独立shader，不改变战斗时间。Unity已导出，合并版本构建/视觉验收结果待追加。尚不等同参考动图最终质量。
v4合并版本：/tmp/encore-layered-export.log、/tmp/encore-layered-build.log 均成功，已安装并实际开始战斗和摇铃。CUA观察三层蓄火可见、敌人轮廓保留，铃显影透明且无按钮棕底。实际录像 output/encore-bell/layered-fire-v4.mov。效果仍偏明亮金色，尚未达到参考红色流动能量的材质/层次质量；本次仅为分层第一步，不宣称最终验收。

## 绿色蓄力修订
用户确认画面为蓄力提示，并要求更热烈、身体变绿。粒子密度提高，贴身层缩小发射范围并降低漂离速度；色调改绿色。蓄力时克隆敌人身体材质，逐渐增加绿色/自发光，释放、清场或重复开始时恢复原材质并释放副本，不改变共享资产。Unity导出通过（/tmp/encore-green-export.log），待模拟器视觉验收。
