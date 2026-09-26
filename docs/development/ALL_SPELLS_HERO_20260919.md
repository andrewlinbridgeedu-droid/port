# 主角法术提升一档 — 2026-09-19

本轮依用户「所有法术加强一个级别」及「少一点、大片一点」实施，追加细节、炸裂、绚丽、光彩、面积。此记录是源码变更清单，Unity 编译、运行、录像和用户视觉验收由主批统一记录；本子任务没有运行 Unity，没有原生构建或装机。

## 实际路由

BattlePrototype.PresentPlayerSkill → FoolEffekseerSkillVFX.Play。SpellRegistry 当前没有 fool_skill 系列条目，因此正式九招不被 SpellBridge 抢占。

| ID / 技能 | 生效实现 | 本轮变化 |
|---|---|---|
| 01 错步穿行 | FoolTarotStrikeVFX + FoolSidestepRift.shader | 保留双目标各两个完整主角残影；交叉裂痕长宽适度扩大，亮芯/柔光加强，6碎片减到4片并加宽。 |
| 02 假面谕令 | HeroIdentityTheatreVFX + HeroSpellVolume kind2 | 实体面具约增10%，升腾冠翼面积与内部流纹加强，7细焰减为4宽焰。 |
| 04 身份错置 | 同上 kind4 | 双面具约增10%，交错切换的横向能量片与中心裂缝加宽，保留左右交换身份。 |
| 05 伪证烙印 | 同上 kind5 | 实体烙印2.4→2.65，落压冲击面加厚，5细柱减为3宽柱。 |
| 06 错影追猎 | HeroArcanaTheatreVFX + kind6 | 保留原主角衣装、紫青双影；两条定向穿透尾流和尖端加宽，不改残影或通道位置。 |
| 07 荒谬归结 | 同上 kind7 | 主巨牌1.8×3.1→2.02×3.48，实体碎牌18→8块并放大，shader碎牌13→6；斜切亮刃更宽，单侧扇形炸开。双手托举动作不变。 |
| 08 反客为主 | 同上 kind8 | 四幅舞台帷幕宽0.62→0.78，揭幕后的侧向大片能量加厚，保留中央可见目标。 |
| 09 后手改写 | 同上 kind9 | 回卷书页尺寸约增16%，亮页9→6且更大，保留向内回收而非对外爆炸。 |
| 10 无名宣告 | NamelessDeclarationVFX + kind10 | 原三实体面具不变，收束后纵向宣告光柱和肩沿变宽，内部层次与光彩加强。 |

HeroSpellVolume 各招相对锚点的宽度约增14%（06定向穿行单独加宽），亮度温和增加14%，增加内部矿物状亮脊。原有不同完整轮廓保持，没有新增统一径向爆炸或全屏白闪。命中局部照明由3.2提升到3.8，仍由原命中包络控制，不增额外 Light。

## 保留边界

未修改任何伤害、冷却、contactTime、生命周期、回调、角色骨骼动作、取消/清理代码。未修改 BattlePrototype、UnityBattleBridge、共享敌人或 Editor。源素材不动。

手动假面真实承伤路径为 MasqueradePhantom + summon-masquerade-v1，交由主批遗物盘点；不能用02展示代替拦截验收。03纸人是历史路径，不恢复开放。

## 文件及备份

修改五文件：HeroIdentityTheatreVFX.cs、HeroArcanaTheatreVFX.cs、HeroSpellVolume.cs、Resources/EnemySignature/HeroSpellVolume.shader、Resources/Effects/Fool/FoolSidestepRift.shader。
备份保持完整相对路径：backups/all-spells-tier-20260919/hero/UnityBattleSource/Assets/。

## 建议验证入口

HeroSpellCapture 使用真实 battle.PlayPlayerSkill 路由，参数 --preview-hero-spells --hero-capture=<新输出目录>，九招实际回调与两次取消检查。另 SidestepCinematicCapture 覆盖01单/双目标与取消。需重新实录观察 07牌面是否保持可辨、02/10面具是否被光淹没、06双影纹理是否保留、08帷幕与冲击面的前后层次。规则检查或构建成功均不等于视觉验收。

## 正式手动假面与遗落物补充盘点

手动假面真实发送 `masquerade:N`；真实承伤发送 `masquerade-hit:N`。已改 MasqueradePhantom：幽灵轮廓加宽、内部稀疏流动亮纹、受击金色亮芯增强；破碎由28小片减至12大片，散射速度略降以保持集中。未动Offset、Impact、charges、4秒窗口、冷却、裂纹或寿命/恢复。

命中仪式经 `summon-masquerade-v1` registry → MasqueradeRitual。此 extension 自行计算所有形态，忽略 JSON 中的width/scale；因此直接修改生效的Ritual：12末端小簇→6大片，主轮廓面积增加约13%，三条升腾带增宽，金紫亮芯加强。保留时间/清理，未无效修改registry参数。新增备份三文件 MasqueradePhantom.cs、MasqueradeRitual.cs、MasqueradeGhost.shader。

正式可用遗落物来源 GameStore.EarlyRelicShop：三主动（假面、僭命勋章、空栏名片）+七被动。以下严格区分Unity效果和原生反馈，不能将缺失独有演出说成已增强。

| 遗落物 | 目前实际反馈 | 本轮状态 |
|---|---|---|
| 无主假面 | Unity完整幽灵、承伤金紫仪式、耗尽碎裂 | 已加强，待统一Unity运行与视觉检查 |
| 僭命勋章 | 原生卡面紫金冠、倒计时/血条上限变化 | 无独立Unity法术，未动原生规则/反馈 |
| 空栏名片 | 原生契约中/冷却状态 | 无独立Unity法术 |
| 盐封呼吸囊 | 原生收容量、生命上限变化 | 无独立Unity法术 |
| 返礼银扣 | 原生就绪/礼盾、盾数值 | 无独立Unity法术 |
| 迟签印章 | 待签倒计时；实际伤害时飘字及Unity敌人通用受击 | 无独立印章演出 |
| 反照墨镜 | 反照状态；赠血实际触发Unity enemy-heal；反伤实际受击 | 共用受疗/受击，不是独有镜面法术 |
| 缄卷镇纸 | 第三槽封存状态、原生96×142椭圆庇护罩 | 无独立Unity法术 |
| 逆潮铜锚 | 原生余段数/收容量/冷却 | 无独立Unity法术 |
| 归属断线针 | 原生次数/封疗倒计时、治疗数值 | 无独立Unity法术 |

`presentNewRelicEvents`将真实正伤害送通用enemy-impact，将真实正治疗送enemy-heal，属于共用反馈。旧纸人、旧铃、三证环/无主印章不能按历史文档视作当前全部已开放；本轮不恢复旧契约。GuardianWard实际绑定敌方守卫，不是镇纸庇护，故本子任务未改它。

手动假面需额外验证：Deploy → Hit(1) → Hit(0)碎裂、4秒到期清理、重复Deploy恢复，以及受击后重试无残留。这些不是HeroSpellCapture里02演示自动覆盖的测试。
