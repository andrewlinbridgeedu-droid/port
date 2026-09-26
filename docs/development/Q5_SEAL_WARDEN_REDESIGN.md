# 第5关重设计工作稿

> 最新用户决定：纸人遗落物不合适；本文“纸人代签封印”方案已撤销，仅保留敌人造型候选供后续核对。遗落物需回到规划逐步重设计。纸人状态草稿及测试已移出编译目录保存为废案。

用户确认：第4关取消扑近，只喷火球；第5关换新怪，纸人必须区别于假面。以下具体设计为制作方向，尚未实装，不将旧版第五关算作完成。

## 封缄狱卒 / Meshy生成规格
旧案保管室随原信封印苏醒的守藏执行体，非猎犬、非普通持斧守卫。人形高约2米，黑铁档案匣胸腔、旧铜镶边、暗红蜡封、粗短锁链；脸部是无五官封条面甲。右臂大型封缄印章，左臂展开夹具，双脚稳定承重。哥特欧洲雾港写实风格。无需内置文字、发光粒子或场景底座。

英文提示：Gothic archive seal warden, humanoid automaton built from black iron archival lockboxes and aged brass fittings, dark burgundy wax seals and short heavy chains, faceless sealed metal visor, right arm a massive stamping press, left arm a articulated document clamp, sturdy legs, readable silhouette, realistic PBR fantasy game enemy, no readable text, no particles, no display base.

提供FBX模型、贴图和骨骼；根节点脚底中点、直立约2米；Idle、Walk、Hit、Death、SealCast（抬印蓄力后落印）、StampAttack（重击）动作。目标挂点胸前蜡封，施法发射点印章底面。动作尽量原地，不把发光/锁链粒子烘进模型。收到后工程侧统一轴向、尺寸、挂点、动画和性能。

## 纸人：代签封印
保留封存原信交付来源。每场一次，封缄/禁锢将施加到主角时，由原信展开纸人代签，该次控制不生效；本次伤害仍正常结算。不回血、不免死、不加误认、不额外攻击。假面继续负责主动幻影承伤。旧纸人的致命保留1生命规则必须同步移除，不叠加两套保护。

第5关以公开的封印起手教控制预警与纸人触发，下一次封印正常生效；需要核对两格技能在当时可得资源下能解，不用强制失败脚本。战后移交单仍为物证，不重复发放遗落物。第6关回到原猎犬追索线收尾。

## 当前状态
新怪模型缺失，需用户Meshy生成；尚未接新敌人、控制规则、纸人替换与剧情。当前已绘制移交单位图并映射。第4关规则改为charge/memory_breath交替，取消bite；规则测试同步更新。

## 最新设计衔接
纸人/代签废止。第五关新遗落物候选与重击教学见 Q5_RELIC_REPLACEMENT_DESIGN.md；封缄狱卒保留造型候选，控制锁牌改为抬印蓄力/落印重击/回收，避免提前引入后期净化教学。
