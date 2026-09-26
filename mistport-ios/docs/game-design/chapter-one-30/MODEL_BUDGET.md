# 第一章模型预算与制作边界

用户授权：现有15个角色模型，加1个新大Boss，完成30关。15包括主角；第一章总数16，敌人15种。此处“模型”指独立角色母版，不把同模型克隆、颜色、配件、血量或阶段算作新模型。

| ID | 现有母版/形象 | 本章职责约束 | 制作现状 |
|---|---|---|---|
| M00 | 紫金长衣主角 | 玩家；八招动作、双手托举保留 | 已接入，仍需逐模型Blender精修 |
| M01 | 红黑空壳剑守卫 | 基层封锁与执行单位；不同个体须有不同实体ID | 已接入 |
| M02 | 幽灵 | 失名记忆残留；赤红分裂仍是同模型 | 已接入 |
| M03 | 旧地狱犬 Emberwolf | 循名追索，远处火球，Q3/Q4/Q16同一实体，Q16终结 | 已接入 |
| M04 | 翠焰亡灵 3.glb | 腐败记忆与邮务异常；递增毒雾/绿焰重击 | 已接入 |
| M05 | Iron Vault Sentinel | 象牙白档案门卫；前悬旋转盾、飞臂螺旋 | 已接入 |
| M06 | 寄忆核心 | 写回旧记录、定向修复；各核心独立施法目标 | 已接入 |
| M07 | 记忆蛭 | 吞取内部记忆与身份；不负责改外部纸面档案 | 已接入 |
| M08 | Armored Hellhound | 后期押运执行犬；地火，禁止旧犬火球 | 已接入 |
| M09 | Crimson Threadweaver | 维娅；Q15/22/25同一实体，最后自愿断契 | 已接入 |
| M10 | Marionette Schola | 蜡脸紫衣书记员；账册、人工证词校正 | 源码新接入，未装手机 |
| M11 | Burdened Brawler | 洛克；Q13本地停机、Q21永久解根并救人 | 源码新接入，未装手机 |
| M12 | Codex Sentinel 0917011404 | 机械笔臂自动机；Q17/P17与Q29/P29独立实例 | 6万面、22骨、七动作已接Unity；未装手机 |
| M13 | Iron Star Sentinel 0916094930 | 重锤甲士A；Q18/J19与Q23/J25独立裁决/封口实例 | 原GLB已存，待制作 |
| M14 | Iron Vanguard 0916102127 | 重锤甲士B；Q20撤运、Q26同体永久毁坏，区别A的动作和机制 | 原GLB已存，待制作 |
| M15 | 新章Boss | 总签官瑟维安；Q28/29/30，同一身体三次交锋，30真死 | 用户指定Chronarch_Sovereign_0917015018；高模已归档，移动端制作待完成 |

## 不隐瞒附加成本

- 三教会共同百层空间封堵玩法：用户已提供D01–D06六种恶魔高模，另复用旧犬，共七种；来源见CHURCH_DEMON_ASSETS_20260916.md，用户本次明确批准独立规划；不混入16个主线母版。
- 地图NPC、对白立绘、线索图、遗落物原画、场景背景、法术特效是单独美术工作，并非“只用16模型”就零新增素材。
- 主线和第一批可上线通缉的战斗对象必须引用上述敌模。海盗/杀人狂的人类原貌可先为立绘；若当前人体、服饰、武器不支持其身份，不以改名冒充，相关战斗版本列后续资产扩展。
- 两具重锤甲士必须通过站姿、发力、攻击轨迹、职责和机制区别，不能仅换颜色与HP。M12机械笔臂不得复用M10布衣动作导致变形。
- 同一实体最多三次正式主线遭遇；量产的同族个体另有实体ID。打败不等于杀死；逃脱、解除命令、断电、死亡等结果要和动画/对白一致。已死实体不可在新剧情复活；旧关重玩标作往事回顾，不改变世界状态。

源文件索引：`ArtSource/StoryEnemyIntake20260916/manifest.json`；两已接入新模型见 `docs/development/CHARACTER_POLISH_20260916.md`。

## v3实体约束

Q24铠甲犬与Q27铠甲犬是新个体，不是Q10押运犬复活；Q27白门卫也是新个体。Q24幽灵/Q19亡灵与早期同族不同实体。维娅、洛克的结算应使用拘束/停机/断契，不播放“死亡”后又活过来的演出。Q28 Boss单体、Q29 Boss+新Codex执行者P29+空壳卫、Q30 Boss单体真死；伊恩、玛拉与其他NPC以对白/立绘承载，不加战斗身体。

M12 current approved master: `ArtSource/CodexExecutor20260916/Meshy_AI_Codex_Sentinel_0917011404_texture.glb`. This replaces Ironclad Sentinel 0916101320 for Q17/Q29. Old Ironclad source deleted with user authorization after new-asset validation. New master and editable Blender retained. 60k triangles, 22 bones and seven clips integrated as executor-template/@executor; Unity playback/contact/cancel/death/retry checked. Q17/Q29 remain planned encounters, not newly unlocked by this asset delivery.
