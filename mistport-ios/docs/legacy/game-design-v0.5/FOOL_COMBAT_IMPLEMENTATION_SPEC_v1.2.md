# 《秘仪：雾港升序》帷幕之径战斗程序实现规格

版本：1.3.0  
状态：程序实现唯一依据  
适用范围：三人副本中玩家主角“帷幕之径”的首轮无美术战斗原型  
配套数据：`fool_combat_config.v1.1.json`、`fool_combat_test_vectors.v1.1.json`

---

## 0. 文档权威与冲突处理

本文件是帷幕之径技能、伤害、状态、自动序列、敌人数值和战斗测试的**程序实现规格**。

出现冲突时，程序人员按以下优先级执行：

1. 本文件；
2. `fool_combat_config.v1.1.json`；
3. `fool_combat_test_vectors.v1.1.json`；
4. `SKILL_DESIGN_GUIDE.md`；
5. 其他产品、剧情、纵切和旧战斗文档。

本版本明确废止以下旧规则：

- 不以预测敌人下一行动作为帷幕之径的核心玩法；
- 不通过“正确预测”生成预兆；
- 不实现预兆资源；
- 不实现随机命中率、随机闪避率、暴击率和随机伤害浮动；
- 命中与闪避采用确定性结算：攻击默认命中，只有明确的主动闪避状态可以令一次可闪避攻击落空；
- 不实现实时移动、站位距离、寻路和多人同步；
- 普通卡牌不使用独立冷却；每回合按已开放并装备的全部卡牌执行，卡牌数量由装备位决定；
- 不允许程序人员根据个人理解修改伤害、状态层数或结算顺序。

本版本的技能核心为：

> 假象铺垫 → 错位转换 → 追击利用 → 终幕收割 → 当前装备卡牌循环重新开始。

---

## 1. MVP实施范围

### 1.1 必须实现

- 玩家主角＋2名AI队友对1–4名敌人的固定技能回合制战斗；
- 9个普通主动技能；
- 1个每场一次的终极技能；
- 战前从9个普通技能中装备6个；
- 终极技能固定占独立按钮；
- 命中结果、主动闪避、格挡、防御、护盾、伤害、自动序列、状态、驱散、净化和死亡；
- NORMAL、ELITE、BOSS三种控制抗性等级；
- 战斗日志；
- 配置文件加载；
- 本文件列出的全部自动化测试。

### 1.2 暂不实现

- 被动技能与遗器；
- 技能等级和技能升级；
- 属性成长曲线；
- 元素克制；
- 随机命中率、随机闪避率、暴击率和随机伤害；
- 速度条和插队；
- 玩家治疗技能；
- 自动战斗；
- PVP；
- 真人多人战斗；
- 正式美术和复杂镜头表现。

程序中可预留字段，但不得在MVP中启用。

---

## 2. 战斗基本流程

### 2.1 战斗单位

每场标准副本战斗包含：

- 1名玩家主角；
- 2名AI队友；
- 1–4名普通敌人，或1名Boss加0–2名附属单位；
- 玩家最多装备6个普通技能；
- 玩家固定拥有1个终极技能。

本文件只规定玩家主角的技能结算；AI决策、倒地复活与副本持续状态以 `PARTY_AI_IMPLEMENTATION_SPEC.md` 和 `DUNGEON_COMBAT_SPEC.md` 为准。

### 2.2 回合顺序

MVP不使用速度属性。顺序固定：

1. 敌方公布意图；
2. 玩家主角行动；
3. AI队友A行动；
4. AI队友B重新校验后行动；
5. 存活敌人按意图行动；
6. 回合结束；
7. 进入下一回合。

如果单位在轮到行动前死亡，则跳过其行动。

### 2.3 玩家行动

一次玩家行动只能选择一个技能和合法目标。

执行顺序：

1. 校验技能是否已解锁；
2. 校验技能是否已装备；
3. 校验冷却；
4. 校验每场使用次数；
5. 校验目标；
6. 校验技能条件；
7. 建立施法开始快照；
8. 锁定本次技能所用的状态加成；
9. 建立一次 `AttackAction`，确定 `hit_policy` 与全部命中段；
10. 进行确定性命中/闪避判定；
11. 若结果为 `HIT`，逐段执行防御、减伤、格挡、护盾与生命结算；
12. 仅在至少一段成功命中时，执行 `ON_HIT` 状态消费与施加；
13. 无论是否闪避，执行 `ON_CAST` 自身效果；
14. 执行死亡检查；
15. 写入战斗日志；
16. 更新技能下次可用行动序号；
17. 递减以“玩家行动”为时钟的状态。

动画只能读取结算结果，不能修改结算结果。


### 2.4 攻击行动、命中与闪避

一次造成伤害的技能必须建立一个 `AttackAction`。多段技能仍然只建立一个攻击行动。

```text
AttackAction
- action_id
- attacker_id
- target_id
- hit_policy          // DODGEABLE | UNAVOIDABLE
- damage_type         // STANDARD | TRUE
- hit_coefficients_bp // 一段或多段
- on_hit_effects
- on_cast_effects
```

命中结果枚举：

```text
HIT       // 攻击成功接触目标；即使护盾吸收全部伤害也仍为HIT
DODGED    // 主动闪避成功；本次攻击行动全部命中段落空
IMMUNE    // 目标对该效果明确免疫
INVALID   // 目标死亡、目标不合法或技能条件不成立
```

MVP不进行随机数判定，也不存在 `accuracy` 与 `evasion_rate` 属性。规则如下：

1. `UNAVOIDABLE` 攻击直接得到 `HIT`，不会消耗闪避；
2. `DODGEABLE` 攻击遇到目标至少1个 `evasion` 充能时，得到 `DODGED`；
3. 一次多段技能只消耗1个闪避充能，全部命中段一起落空；
4. `DODGED` 时伤害为0，不施加 `ON_HIT` 状态，不消费目标上的错位或假象；
5. `DODGED` 时技能冷却和每场使用次数照常消耗；
6. `DODGED` 时 `ON_CAST` 自身效果仍然生效；
7. 闪避不会触发纸人反制、受击反击或“受到伤害后”事件；
8. 护盾吸收全部伤害仍然属于 `HIT`，可以触发受击事件。

该设计的目的，是让连招结果可计算。玩家不会因为隐藏的随机miss而失去六回合连段。

---

## 3. 数据类型与固定精度

### 3.1 百分比

所有百分比使用基点整数：

- `10000` = 100%；
- `500` = 5%；
- `1500` = 15%；
- `-1000` = -10%。

禁止使用二进制浮点数直接保存平衡数值。

### 3.2 整数类型

伤害计算中间值使用64位有符号整数或任意精度整数。

最终生命、护盾、伤害和属性均为整数。

### 3.3 四舍五入

所有伤害只在**每个独立命中结束时**进行一次四舍五入。

四舍五入规则：

- 小数部分小于0.5：向下；
- 小数部分大于等于0.5：向上；
- 不使用银行家舍入。

例如：

- 41.49 → 41；
- 41.50 → 42；
- 41.99 → 42。

---

## 4. 核心属性

### 4.1 玩家首轮固定属性

| 属性 | 值 |
|---|---:|
| 最大生命 `max_hp` | 1000 |
| 当前生命 `hp` | 1000 |
| 攻击 `attack` | 100 |
| 防御 `defense` | 11 |
| 通用伤害加成 `damage_bonus_bp` | 0 |
| 通用减伤 `damage_reduction_bp` | 0 |

### 4.2 敌人属性

每个敌人必须包含：

```text
id
name
rank                 // NORMAL | ELITE | BOSS
max_hp
hp
attack
defense
status_resistance    // 0–10000，MVP固定为0
ai_pattern
buff_list
status_list
```

### 4.3 防御、破防与真实伤害

先计算加减防后的原始防御：

```text
modified_defense = max(0,
    base_defense
  + sum(flat_defense_bonus)
  - sum(flat_defense_penalty))
```

普通伤害的有效防御：

```text
effective_defense = floor(
    modified_defense
  × (10000 - armor_penetration_bp)
  ÷ 10000)
```

防御系数：

```text
defense_factor = 100 ÷ (100 + effective_defense)
```

`STANDARD`伤害应用上述防御。`TRUE`伤害令 `effective_defense = 0`，但仍然受到通用减伤、格挡与护盾影响。

防御、有效防御和防御系数都必须写入战斗日志。防御不得低于0，百分比破防不得高于10000。

---

## 5. 最终伤害公式

### 5.1 单次命中

```text
coefficient_damage = attacker.attack × skill_coefficient_bp ÷ 10000

bonus_multiplier = (10000 + total_outgoing_bonus_bp) ÷ 10000

defense_multiplier = 100 ÷ (100 + effective_defense)

unrounded_damage = coefficient_damage
                 × bonus_multiplier
                 × defense_multiplier

final_damage = round_half_up(unrounded_damage)
```

最终伤害最小为1，除非技能明确标记为0伤害。

### 5.2 本路径伤害加成

```text
total_outgoing_bonus_bp =
    attacker.damage_bonus_bp
  + illusion_stack_bonus_bp
  + fabricated_evidence_bonus_bp
  + other_skill_specific_bonus_bp
```

MVP中同类伤害加成相加后统一乘算。

### 5.3 假象伤害加成

每层假象使帷幕之径对该目标造成的伤害增加5%：

```text
illusion_stack_bonus_bp = illusion_stacks × 500
```

最多4层，因此最多增加20%。

### 5.4 伪证植入加成

目标拥有`fabricated_evidence`时，帷幕之径下一个伤害技能获得15%加成：

```text
fabricated_evidence_bonus_bp = 1500
```

一次技能无论包含多少次命中，只消耗1个充能，所有命中都获得15%加成。

### 5.5 防御、减伤、格挡、护盾与生命的固定顺序

每个成功命中的独立伤害段严格按以下顺序结算：

```text
1. 技能系数与攻击力
2. 攻击方增伤
3. 防御与破防
4. round_half_up，得到 damage_after_defense
5. 汇总目标通用减伤、舞台庇护和格挡
6. round_half_up，得到 damage_after_reduction
7. 护盾吸收
8. 剩余伤害扣除生命
```

精确公式：

```text
reduction_bp = min(
    target.damage_reduction_bp
  + stage_guard_reduction_bp
  + active_guard_reduction_bp,
    6000)

damage_after_reduction = round_half_up(
    damage_after_defense
  × (10000 - reduction_bp)
  ÷ 10000)

shield_absorb = min(current_shield, damage_after_reduction)
current_shield -= shield_absorb
hp_damage = damage_after_reduction - shield_absorb
current_hp = max(0, current_hp - hp_damage)
```

规则：

- 减伤总上限为60%；
- `guard` 按一次攻击行动生效，而不是按每个命中段分别消费；
- 多段攻击中每一段都享受同一次格挡减伤，全部命中结束后才消费1个格挡充能；
- 若攻击被闪避，格挡不消费；
- 伤害在进入护盾前最小为1；护盾可以令实际生命伤害为0；
- 纸人反制在确认 `HIT` 后触发，不要求生命实际受损。

---

## 6. 自动序列实现

普通卡牌没有独立冷却，也不保存 `next_available_action_index`。

- 战前按顺序装备最多6张普通卡牌；
- 战斗开始后，每回合按该顺序执行当前已经开放并装备的全部普通卡牌；
- 序列不限制每回合执行的卡牌数量，开放并装备几张就执行几张；
- 玩家本回合全部卡牌执行完后，敌人依次行动；
- 走到队列末尾后，下一回合从第一张继续循环；
- 遗落物通过强化伤害、状态层数、持续时间、目标范围或触发效果来增强已有卡牌，不额外制造一套冷却队列；
- 终极技能与“每场一次”等特殊能力使用独立次数或资源限制，不进入普通冷却系统。

旧存档中的冷却字段仅用于兼容读取，不能阻止普通卡牌执行。原“缩短冷却”效果必须改造成强化下一次铺垫、资源回复或其他明确效果。

---

## 7. 状态持续时间

每个状态必须声明时钟：

```text
PLAYER_ACTION_END
ENEMY_ACTION_END
ROUND_END
CHARGE_ONLY
```

### 7.1 新施加状态不立即递减

状态保存：

```text
applied_clock_index
remaining_duration
```

只有当前时钟序号大于`applied_clock_index`时才递减。

### 7.2 状态叠加规则

状态必须指定：

```text
stack_rule      // ADD | SET_MAX | REPLACE | NO_STACK
max_stacks
refresh_rule    // REFRESH_TO_BASE | KEEP_LONGER | NO_REFRESH
```

### 7.3 死亡时清理

单位死亡时：

- 清除其全部状态；
- 清除其护盾；
- 取消尚未结算的个人触发；
- 不移除其他单位已经获得的独立状态。

---

## 8. 状态精确定义

### 8.1 `illusion` 假象

```text
owner: enemy
clock: PLAYER_ACTION_END
base_duration: 3
stack_rule: ADD
max_stacks: 4
refresh_rule: REFRESH_TO_BASE
category: CORE_PATH_DEBUFF
cleansable: true
```

效果：每层使帷幕之径对该目标的伤害增加5%。

添加假象时：

```text
stacks = min(4, current_stacks + added_stacks)
remaining_duration = 3
```

### 8.2 `misalignment` 错位

```text
owner: enemy
clock: PLAYER_ACTION_END
base_duration: 3
stack_rule: SET_MAX
max_stacks: 2
refresh_rule: REFRESH_TO_BASE
category: CORE_PATH_DEBUFF
cleansable: false in MVP
```

错位本身不直接增加伤害。它由技能1、6、7消费或检查。

### 8.3 `fabricated_evidence` 伪证

```text
owner: enemy
clock: PLAYER_ACTION_END
base_duration: 3
charges: 2
stack_rule: REPLACE
category: INTERNAL_MARKER
cleansable: true
```

效果：帷幕之径下一个伤害技能获得15%加成。每个伤害技能消耗1充能。

### 8.4 `finale_ready` 终幕准备

```text
owner: player
clock: PLAYER_ACTION_END
base_duration: 1 or skill-defined override
stack_rule: REPLACE
category: PLAYER_BUFF
cleansable: false
```

普通技能1施加时持续1次后续玩家行动。终极技能10施加时持续3次后续玩家行动。

### 8.5 `weaken_next_action` 弱化下一击

```text
owner: enemy
clock: CHARGE_ONLY
charges: 1
magnitude_bp: 1000
category: DAMAGE_REDUCTION_ON_SOURCE
cleansable: true
```

敌人的下一次伤害行动总伤害降低10%。多段伤害视为同一次行动，全部命中都降低10%，行动结束后消耗。

### 8.6 `paper_double_counter` 纸人反制

```text
owner: player
clock: ROUND_END
base_duration: 2
charges: 1
category: PLAYER_BUFF
```

玩家受到敌人的直接伤害行动时，行动完全结算后，对伤害来源施加2层假象并消耗状态。

伤害被护盾完全吸收也算受到直接伤害。

持续伤害、环境伤害和反伤不触发。

### 8.7 `resistant_disorientation` 抗性错乱

用于ELITE和BOSS：

```text
owner: enemy
clock: CHARGE_ONLY
charges: 1
magnitude_bp: 2500
suppress_secondary_effects: true
cleansable: false
```

敌人下一次伤害行动伤害降低25%，且该行动附带的可压制负面状态不生效。

### 8.8 `normal_disorientation` 普通错乱

用于NORMAL：

```text
owner: enemy
clock: ENEMY_ACTION_END
base_duration: 1
skip_harmful_action: true
cleansable: false
```

NORMAL敌人的下一次有害行动被跳过。防御或自我净化可以正常执行。

### 8.9 `enhanced_setup` 强化铺垫

```text
owner: player
clock: PLAYER_ACTION_END
base_duration: 1
charges: 1
```

下一次使用技能2或技能5时，额外施加1层假象，然后消耗。

### 8.10 `stage_guard` 舞台庇护

```text
owner: player
clock: ROUND_END
base_duration: 3
incoming_damage_reduction_bp: 1500
```

玩家受到的全部伤害降低15%。


### 8.11 `evasion` 主动闪避

```text
owner: any unit
clock: CHARGE_ONLY
charges: 1
applicable_hit_policy: DODGEABLE
scope: ATTACK_ACTION
```

使下一次 `DODGEABLE` 攻击行动得到 `DODGED`。一次多段技能只消费1个充能并全部落空。

### 8.12 `guard` 主动格挡

```text
owner: any unit
clock: CHARGE_ONLY
charges: 1
incoming_damage_reduction_bp: 3500
scope: ATTACK_ACTION
```

下一次成功命中的攻击行动受到的所有伤害段降低35%。该减伤与其他减伤相加，受60%总上限限制。攻击被闪避时不消费格挡。

---

## 9. 10个技能精确规格

技能编号是永久数据ID，不随界面排序改变。

本版本所有造成伤害的帷幕之径技能默认 `hit_policy = DODGEABLE`、`damage_type = STANDARD`。无伤害技能不建立攻击行动。未来若某技能不可闪避，必须在配置中显式写入 `UNAVOIDABLE`。

### 技能1：错步刺击 `fool_skill_01`

```text
target: SINGLE_ENEMY
base_coefficient_bp: 12000
reuse_delay_actions: 0
armor_penetration_bp: 0
```

逻辑：

1. 施法开始时检查目标是否至少有1层错位；
2. 如果有，技能系数改为16800；
3. 造成一次伤害；
4. 如果施法开始时目标有错位，玩家获得`finale_ready`，持续1次后续玩家行动；
5. 不消耗错位。

### 技能2：假面低语 `fool_skill_02`

```text
target: SINGLE_ENEMY
base_coefficient_bp: 5000
reuse_delay_actions: 2
```

逻辑：

1. 造成一次伤害；
2. 伤害后给目标施加2层假象；
3. 如果玩家拥有`enhanced_setup`，额外增加1层并消耗该状态；
4. 给目标施加`weaken_next_action`，幅度10%，1充能。

### 技能3：纸人替身 `fool_skill_03`

```text
target: SELF
base_coefficient_bp: 0
reuse_delay_actions: 0（普通卡牌不使用独立冷却）
```

逻辑：

1. 召唤可见的纸偶替身，不提供护盾；
2. 纸偶仅覆盖本回合随后的敌方行动阶段；
3. 本回合首次针对玩家的直接单体攻击改由纸偶承受，玩家不受到该次伤害；
4. 纸偶受击后消失，并给攻击者施加2层假象；
5. 如果当前回合没有符合条件的攻击，纸偶也会在回合结束时消失。

### 技能4：身份错置 `fool_skill_04`

```text
target: SINGLE_ENEMY
base_coefficient_bp: 8000
reuse_delay_actions: 3
required_illusion_stacks: 4
```

逻辑：

1. 施法条件：目标假象层数必须等于4；
2. 伤害计算时仍使用4层假象提供的20%加成；
3. 如果目标有`fabricated_evidence`，本技能获得15%加成并消耗1充能；
4. 造成一次伤害；
5. 伤害后移除目标全部假象；
6. 目标获得2层错位，持续3次后续玩家行动；
7. NORMAL获得`normal_disorientation`；
8. ELITE或BOSS获得`resistant_disorientation`。

### 技能5：伪证植入 `fool_skill_05`

```text
target: SINGLE_ENEMY
base_coefficient_bp: 6000
reuse_delay_actions: 2
```

逻辑：

1. 使用施法开始时已有的假象层数计算本次伤害加成；
2. 造成一次伤害；
3. 伤害后施加2层假象；
4. 如果玩家拥有`enhanced_setup`，额外增加1层并消耗该状态；
5. 施加`fabricated_evidence`，2充能、持续3次后续玩家行动；
6. 重复施加时充能重置为2，持续时间重置为3，不累加到4充能。

### 技能6：镜像追击 `fool_skill_06`

```text
target: SINGLE_ENEMY
hit_1_coefficient_bp: 7000
hit_2_normal_coefficient_bp: 7000
hit_2_empowered_coefficient_bp: 13300
reuse_delay_actions: 2
```

逻辑：

1. 施法开始时检查目标是否至少有1层错位；
2. 如果目标有`fabricated_evidence`，两次命中都获得15%加成，但整个技能只消耗1充能；
3. 第一击造成70%伤害；
4. 如果施法开始时目标有错位，消耗1层错位，并让第二击使用133%系数；
5. 如果没有错位，第二击使用70%系数；
6. 第二击结算；
7. 两次命中分别四舍五入。

### 技能7：荒谬终幕 `fool_skill_07`

```text
target: SINGLE_ENEMY
base_coefficient_bp: 18000
per_misalignment_stack_bp: 10000
finale_ready_bonus_bp: 8000
armor_penetration_bp: 3000
reuse_delay_actions: 5
```

逻辑：

1. 施法开始时记录目标错位层数，最多2；
2. 记录玩家是否有`finale_ready`；
3. 最终技能系数：

```text
18000
+ misalignment_stacks × 10000
+ (has_finale_ready ? 8000 : 0)
```

4. 使用30%护甲穿透计算一次伤害；
5. 伤害后移除目标全部错位；
6. 如果使用了`finale_ready`加成，则消耗该状态；
7. 目标没有错位、玩家没有终幕准备时仍可使用，伤害为180%。

### 技能8：反客为主 `fool_skill_08`

```text
target: SINGLE_ENEMY
base_coefficient_bp: 7000
reuse_delay_actions: 4
```

逻辑：

1. 造成一次伤害；
2. 检查目标可驱散正面状态，按以下优先级选择一个：

```text
ATTACK_UP > DEFENSE_UP > DAMAGE_REDUCTION > REGEN > OTHER
```

3. 如果存在：
   - 移除该状态；
   - 目标获得1层错位，持续3次后续玩家行动；
   - 玩家获得对应的弱化复制，持续2回合：

| 原状态 | 玩家复制效果 |
|---|---|
| ATTACK_UP | 伤害增加10% |
| DEFENSE_UP | 防御增加10点 |
| DAMAGE_REDUCTION | 受到伤害降低10% |
| REGEN | 每回合结束恢复50生命，共2次 |
| OTHER | 获得100护盾 |

4. 如果不存在可驱散增益：
   - 目标获得2层假象；
   - 玩家获得100护盾；
   - 护盾总上限仍为400。

### 技能9：幕后换场 `fool_skill_09`

```text
target: SELF
base_coefficient_bp: 0
reuse_delay_actions: 5
```

逻辑：

1. 技能2、4、5的`next_available_action_index`各减少1；
2. 减少后不得小于`current_player_action_index + 1`；
3. 按以下优先级清除玩家一个可净化负面状态：

```text
STUN > SILENCE > DAMAGE_DOWN > DEFENSE_DOWN > DOT > OTHER
```

4. 不清除BOSS核心标记、剧情标记和不可净化状态；
5. 玩家获得`enhanced_setup`，持续1次后续玩家行动。

### 技能10：无名舞台 `fool_skill_10`

```text
target: ALL_ENEMIES_AND_SELF
base_coefficient_bp: 0
reuse_delay_actions: not_applicable
max_uses_per_battle: 1
```

逻辑：

1. 所有存活敌人的假象层数设置为4，持续时间刷新为3次后续玩家行动；
2. 技能4、6、7设置为下一次玩家行动可用：

```text
next_available_action_index = current_player_action_index + 1
```

3. 玩家获得`finale_ready`，持续3次后续玩家行动；
4. 玩家获得`stage_guard`，持续3回合；
5. 本技能不造成伤害；
6. 同一场战斗不能再次使用。

---

## 10. 标准连段与精确结果

标准完整连段：

```text
2 → 5 → 4 → 6 → 1 → 7
```

测试条件：

```text
玩家攻击 = 100
目标防御 = 20
玩家无其他增益
目标初始无状态
所有技能均可用
```

精确结果：

| 玩家行动 | 技能 | 本次伤害 | 行动后关键状态 |
|---:|---|---:|---|
| 1 | 技能2 | 42 | 假象2；弱化下一击1充能 |
| 2 | 技能5 | 55 | 假象4；伪证2充能 |
| 3 | 技能4 | 90 | 假象0；错位2；伪证1充能 |
| 4 | 技能6 | 67＋127＝194 | 错位1；伪证0 |
| 5 | 技能1 | 140 | 错位1；终幕准备 |
| 6 | 技能7 | 316 | 错位0；终幕准备消耗 |

完整连段总伤害：

```text
42 + 55 + 90 + 67 + 127 + 140 + 316 = 837
```

程序输出必须与837完全一致。出现836或838均视为计算顺序或舍入错误。

不同目标防御下，同一完整连段的标准结果：

| 目标防御 | 总伤害 |
|---:|---:|
| 0 | 986 |
| 10 | 904 |
| 15 | 870 |
| 20 | 837 |
| 25 | 807 |

---

## 11. 敌人数值基线

以下数值仅用于第一轮无美术原型，配置中必须可修改，不得硬编码在战斗逻辑内。

| 模板ID | 类型 | HP | 攻击 | 防御 | 目标存活时间 |
|---|---|---:|---:|---:|---|
| weak_minion | NORMAL | 150 | 35 | 0 | 1–2次玩家行动 |
| standard_minion | NORMAL | 300 | 55 | 10 | 2–4次玩家行动 |
| sturdy_minion | NORMAL | 480 | 65 | 15 | 4–6次玩家行动 |
| elite_enemy | ELITE | 900 | 80 | 20 | 6–9次玩家行动 |
| region_boss | BOSS | 1800 | 90 | 20 | 12–15次玩家行动 |
| chapter_boss | BOSS | 2300 | 95 | 25 | 16–20次玩家行动 |

### 11.1 普通敌人AI模板

`weak_minion`：

```text
行动1：100%攻击
行动2：等待/准备
循环
```

`standard_minion`：

```text
行动1：100%攻击
行动2：获得20%减伤，持续1回合
行动3：100%攻击
循环
```

`sturdy_minion`：

```text
行动1：90%攻击
行动2：蓄力，不造成伤害
行动3：160%攻击
循环
```

### 11.2 精英AI模板

```text
行动1：100%攻击
行动2：获得攻击增加15%，持续2回合
行动3：170%攻击
行动4：清除自身最多2层假象；若无假象则获得100护盾
循环
```

### 11.3 章节Boss首轮模板

Boss攻击95、防御25、生命2300。

```text
行动1：100%攻击
行动2：60%攻击，并给玩家施加伤害降低10%，持续1次玩家行动
行动3：180%攻击
行动4：40%攻击，并获得防御增加10点，持续1回合
循环
```

ELITE和BOSS受到技能4时不能跳过行动，只获得`resistant_disorientation`。

本版本不根据玩家技能自动改变Boss行为，不实现针对性读心AI。

---

## 12. 技能解锁与技能槽

程序使用`unlock_step`控制，不直接硬编码到阶位名称。

| 解锁步骤 | 新技能 | 普通技能槽数量 |
|---:|---|---:|
| 1 | 1、2、3 | 3 |
| 2 | 5 | 4 |
| 3 | 4 | 4 |
| 4 | 6 | 5 |
| 5 | 7 | 6 |
| 6 | 8 | 6 |
| 7 | 9 | 6 |
| 8 | 10 | 6＋终极按钮 |

规则：

- 未解锁技能不能装备；
- 未装备普通技能不能在战斗中使用；
- 终极技能解锁后自动出现，不占普通技能槽；
- 存档只保存技能ID，不保存界面位置作为技能身份。

---

## 13. 战斗日志要求

每次技能至少记录：

```text
battle_id
round_index
player_action_index
actor_id
skill_id
target_ids
snapshot_statuses
coefficient_bp
outgoing_bonus_bp
effective_defense
armor_penetration_bp
damage_per_hit
shield_absorbed
hp_damage
statuses_consumed
statuses_applied
next_available_action_index
```

状态变化必须记录来源技能和剩余持续时间。

战斗日志必须能在不播放动画的情况下还原战斗结果。

---

## 14. 必须通过的单元测试

### T01：基础伤害

```text
攻击100，技能2系数50%，目标防御20
期望伤害：42
```

### T02：假象加成

```text
目标有2层假象，攻击100，技能5系数60%，目标防御20
期望伤害：55
```

### T03：状态转换

```text
目标假象4、伪证2充能，使用技能4
期望伤害：90
期望：假象0、错位2、伪证1
```

### T04：多段追击

```text
目标错位2、伪证1充能，使用技能6
期望第一击：67
期望第二击：127
期望总伤害：194
期望：错位1、伪证0
```

### T05：终幕准备

```text
目标错位1，使用技能1
期望伤害：140
期望玩家获得终幕准备
期望错位仍为1
```

### T06：终结技

```text
目标错位1，玩家有终幕准备，目标防御20
使用技能7
期望有效防御：14
期望伤害：316
期望错位0、终幕准备移除
```

### T07：完整连段

```text
按2、5、4、6、1、7执行
目标防御20且生命足够
期望总伤害：837
```

### T08：护盾结算

```text
玩家护盾200，受到150点减伤后伤害
期望护盾50，生命1000
再次受到100点减伤后伤害
期望护盾0，生命950
```

### T09：纸偶代身

```text
玩家在本回合使用纸偶代身
敌人一次直接单体攻击造成50点伤害
期望玩家生命和护盾不变
期望攻击者获得2层假象
期望纸偶移除
若当前回合没有直接单体攻击，期望纸偶仍在回合结束时移除
```

### T10：普通卡无独立冷却

```text
同一张普通卡仅受六卡队列位置约束
核心运行时查询任意普通卡的剩余冷却始终为0
普通卡不会因旧配置中的reuse_delay_actions而变成不可用
```

### T11：终极重置

```text
当前玩家行动10使用技能10
技能4、6、7的next_available_action_index均应为11
所有存活敌人假象均为4
玩家终幕准备持续3次后续玩家行动
```

### T12：Boss抗性

```text
BOSS假象4，使用技能4
Boss不能跳过行动
Boss获得错位2和抗性错乱
下一次伤害行动降低25%，附加负面效果被压制
```


### T13：确定性命中

```text
攻击100，系数100%，目标防御20，无闪避
期望hit_result = HIT
期望伤害83
```

### T14：单段攻击被闪避

```text
目标拥有1个evasion充能，攻击为DODGEABLE
期望hit_result = DODGED
期望伤害0
期望evasion充能变为0
期望护盾和生命不变
```

### T15：多段攻击被闪避

```text
目标拥有1个evasion充能，技能含70%与133%两段伤害
期望两段伤害均为0
期望只消费1个evasion充能
```

### T16：不可闪避攻击

```text
目标拥有1个evasion充能，攻击为UNAVOIDABLE
攻击100，系数100%，目标防御20
期望hit_result = HIT
期望伤害83
期望evasion充能仍为1
```

### T17：主动格挡

```text
攻击100，系数100%，目标防御20，guard减伤35%
防御后伤害83
期望减伤后伤害54
期望guard充能变为0
```

### T18：格挡后护盾

```text
玩家生命1000，护盾50
受到T17的54点伤害
期望护盾0
期望生命996
```

### T19：舞台庇护与格挡叠加

```text
攻击100，系数100%，目标防御20
stage_guard 15% + guard 35% = 50%减伤
防御后伤害83
期望最终伤害42
```

### T20：闪避后的状态与资源

```text
目标拥有1个evasion充能和2层假象
玩家使用技能5，攻击被闪避
期望伤害0
期望目标假象仍为2
期望不获得fabricated_evidence
期望技能5进入正常冷却
```

全部测试通过后才允许接入正式UI和动画。

---

## 15. 配置与代码边界

必须配置化：

- 玩家和敌人属性；
- 技能系数；
- 冷却；
- 状态层数；
- 状态持续时间；
- 护盾数值；
- 技能 `hit_policy` 与 `damage_type`；
- 闪避和格挡的充能与减伤参数；
- AI行动系数；
- 敌人生命和防御；
- 技能解锁步骤。

可以代码化：

- 伤害公式；
- 状态通用容器；
- 冷却算法；
- 回合状态机；
- 技能效果执行器；
- 事件日志；
- 配置校验。

不得硬编码：

- `if skillName == "荒谬终幕"`；
- 敌人名称判断；
- 具体伤害数字；
- 具体技能图标位置；
- 某个Boss完全免疫帷幕之径核心状态。

允许按技能ID注册专属效果处理器，例如：

```text
skill_effect_registry["fool_skill_07"] = ResolveAbsurdFinale
```

但技能参数必须来自配置文件。

---

## 16. 交付验收标准

程序版本达到以下全部条件，才视为完成首轮战斗实现：

1. 10个技能均可通过配置加载；
2. 玩家可以装备6个普通技能；
3. 标准连段结果严格等于测试值；
4. 状态持续时间没有提前或延后1行动的问题；
5. 多段技能按每次命中独立舍入；
6. 冷却按玩家行动序号运行；
7. NORMAL、ELITE和BOSS对技能4产生不同控制结果；
8. 护盾先于生命承伤；
9. 战斗结果不依赖动画时长；
10. 战斗日志可还原伤害计算；
11. 所有T01–T20自动测试通过；
12. 所有平衡数字可在JSON中修改，无需重新编译核心战斗逻辑。

---

## 17. 版本冻结规则

本文件版本为`1.1.0`。

任何修改以下内容都必须提升版本号并同步更新配置和测试向量：

- 伤害公式；
- 舍入方式；
- 状态持续时间时钟；
- 技能ID；
- 技能系数；
- 技能冷却；
- 连段标准结果；
- 敌人数值模板。

程序人员不得仅修改代码而不修改规格与测试文件。


## 18. v1.1.0变更摘要

- 保留无随机命中率原则；
- 新增 `HIT / DODGED / IMMUNE / INVALID` 确定性命中结果；
- 新增一次攻击行动级别的主动闪避；
- 新增一次攻击行动级别的主动格挡；
- 明确多段攻击、护盾、纸人反制和ON_HIT状态在闪避情况下的处理；
- 扩展防御公式，加入加减防、百分比破防与真实伤害；
- 新增T13–T20自动测试。


## 18. 三人队伍集成约束

1. 假象、错位和终幕准备默认 `owner_unit_id = PLAYER`；
2. 这些状态默认 `reserved_for_combo = true`、`allies_can_consume = false`；
3. AI可以施加通用破甲、易伤、护盾和治疗，但不能修改本文件固定的技能倍率；
4. 队友增伤、破甲与护盾进入通用结算层，不改变帷幕技能内部状态消费顺序；
5. 标准837点单人连段测试继续保留，用于验证玩家技能公式；队友造成的额外伤害不计入该断言；
6. 三人副本新增测试必须独立验证AI不会抢夺玩家状态。
