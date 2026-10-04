# 华彩层架构

## 目录

- 文件
- 生命周期与挂接点
- 身份识别
- 生成一次命中
- 主角牌：往前打、流光、命中炸开、出手光（2026-10-03）
- 如何加一个新签名招式
- 如何加一种新材质
- 如何给新敌人或新通缉头目配身份

## 文件

| 路径（相对 `UnityBattleSource/Assets/`） | 作用 |
|---|---|
| `Scripts/SpellSpectacle20260926.cs` | 全部逻辑：登记、命中、主体曲面、粒子、全屏染色、身份表 |
| `Resources/SpellSpectacle20260926/SpectacleSweep.shader` | 主体曲面。`_Row` 选材质行；`_Facet` 晶体锯齿边；`_Ink` 墨色压暗；`_Distort` 火焰扭动；`_Flicker` 雷电闪烁；`_Wobble` 顶点振动。预乘 alpha，饱和色覆盖，亮芯/溶解边/闪点才发光 |
| `Resources/SpellSpectacle20260926/SpectacleFlare.shader` | 公告板：uv2.x = 覆盖比例，uv2.y = 亮芯变白程度 |
| `Resources/SpellSpectacle20260926/SpectacleWash.shader` | 全屏染色，直接写裁剪空间，任何相机都铺满 |
| `SpectacleMatter.png` | 1024×2048，8 行 × 1024×256。R 线条、G 体积、B 闪点、A 覆盖。行 0 金纹，1 火，2 水，3 晶体，4 丝，5 墨，6 雷电，7 烟。**导入关闭 mipmap**，否则行间串色 |
| `SpectacleAtlas.png` | 2048²：星爆 2×2（左上）、撕裂溅射 2×2（右上）、粒子 4×2（下方 1024–1536 行：Spark/Ember/Shard/Ink/Petal/Card/Wisp/Puff），1536–1792 行左边两格是四角星芒 Glint/Twinkle（Mote 8、9） |
| `SpectacleNoise.png` | 可平铺噪声 |

生成器在仓库 `tools/vfx-spectacle-20260926/`：`make_textures.py`（星爆/溅射/粒子/噪声/金纹）、`make_matter.py`（材质图集，import make_textures 取金纹行）、`glints.py`（四角星芒，纯 PIL；可单独对已提交的图集补两格，不动其他像素）。前两个需要 `/tmp/mistport-vfx-encode/venv`（numpy、pillow、imageio-ffmpeg）。

## 生命周期与挂接点

入口 API（静态）：

- `BeginPlayer(battle, skillID, caster, targets, seeds)`：主角施放时登记。`BattlePrototype.BeginPlayerSpectacle` 负责把每个受体包成"活着就更新、退场就用最后位置"的闭包，**不会把命中转给别的敌人或主角**。
- `BeginEnemy(battle, actor, intent, playerTarget, supportRecipient)`：敌人施放时登记；`recover` 或准备类 intent 会清掉登记。
- `PlayState(battle, profileKey, anchor, seed)`：没有 contact 的状态（锁甲、假面、毒层更新、护航开始）直接播一次 Support 包覆。
- `Contact(actor)`：由 `UnityBattleBridge.ReportCombatContact` 调用（`enemy-cancel:` 不调用）；85ms 内同一 actor 去重，合法的第二段仍会触发。
- `StopAll()`：`BattlePrototype.SetNativeCombatEnabled(false)` 调用，清登记和所有对象。
- `ReducedMotion`：原生受击包第 7 字段置位，降低染色和粒子。
- `Suppressed`：仅录制器 `--spectacle-off` 用，关掉本层做对照诊断。
- `LiveEffects`：录制器 `CheckStopped` 断言停战后归零。

挂接点（改 `BattlePrototype.cs` 时保持）：`PresentEnemyAttack` 开头（BeginEnemy）、`SetQ4HoundPhase`（Q4 双焰走的另一条命令）、`PresentPlayerAction` 普攻、`PresentPlayerSkillAction`（含 H01/H10 多目标分支）、`SetMasquerade`、通缉 guard/bounty_armor 与 D01 guard 分支（PlayState）、`SetEmeraldPoison`、`ChurchStatusPresentation20260917` 护航分支。

## 身份识别

`BeginEnemy` 先确定 `model`，再交给 `EnemyProfile(actorID, intent, model)`：

1. 默认 `actor.ProfileEnemyId`。
2. 身上有激活的 `FogGhostActor` 子物体 → `fog-ghost` / `crimson-ghost`（IsSplit）。幽灵皮肤仍用守卫的 profile ID。
3. 战斗对象上的 `EmeraldRevenantPresentation.InstalledHandle == actor` → `emerald`（翠焰替换了火犬外观）。
4. 有 `BountyIdentityPresentation20260917` → `bounty-` + bountyID 前三位（B04 借执行者模板、B06 借裁定锤卫模板，不这样识别会拿错颜色）。

`EnemyProfile` 优先级：治疗/强化/护甲 intent → 通缉 → 毒 → 精英蓄力 → 各模型名 → 犬类/蛭/核心/幽灵 → 默认守卫。
`EnemyStyle`：heavy/second/slam/thirteenth_charge/name_devour/overwrite/bind/silk_bind/true_stab/rend → Heavy；first/ambush 最多到 Strike。

**每次改身份后都要在录像里确认实际颜色对不对**。这几个借模板的情况都是看图才发现的。

## 生成一次命中（`Burst`）

1. 尺寸 `s` = 命中深度处可视半高 / 4.5 × 身份 scale × 强度档，所以塔内缩放和近景机位的屏幕比例一致。
2. 单目标：`SpawnBodies` 在目标处长出主形态（按 Style 定层数）、副形态（Strike/Heavy）、可选光柱、签名主体（`AccentPaths`），并对带 `impactAt` 的路径在到达时刻生成落地火花。
3. 多目标：一个共享环境主体放在中点，每个受体各自一组命中心和粒子（`Flares.Build(..., group:true)` 去掉白芯、缩小数量）。
4. `Flares.Build`：`Heart`（按材质的命中心）→ Support 柔光 → `AccentMarks`（签名粒子）→ 普通碎屑。
5. 全屏染色 `Wash.Trigger`：新命中取较强值，不叠加。

`Path` 上的动作字段：`pivot` 旋转中心；`offset` 从偏移位置飞到原位；`drift` 到达后继续漂移；`spin/spinAxis` 持续旋转；`swing/swingAxis` 从合拢到张开；`shrink` 向内收；`rigid` 不做弹出缩放；`revealScale/holdScale` 节奏；`coreAmt/opacity/flicker/wobble` 外观；`impactAt` 到达时触发 `Flares.Impact`。

## 主角牌：往前打、流光、命中炸开、出手光（2026-10-03）

用户在手机上的要求，按先后：法术要“往前打”、不要满屏开花；命中范围别太小；每次命中要“炸裂开”到约半屏、不要结结实实一团；飞行要有流光；出技能时主角身上要冒出各种光。

- **形式 `Form`**（`Throw` 伪证、`Hunt` 双影、`Rain` 荒谬、`Dash` 错步、`Flick` 普攻）：`BeginPlayer` 登记时调 `Launch`，按 `LaunchShots` 生成轨迹带和弹头，掐着预计命中时间落到目标。起点是 `BattlePrototype.HeroChestPoint`（视频主角画面的胸口）。
- **流光**：`Shot.stream`（`Flares.Stream`，光点沿同一条路径跟在弹头后面流向目标，`Mark.course` 让粒子骑在路径上）、`Shot.glow`（`Flares.Follow`，没有自带弹头的普攻牌、双影分身、错步残影跟一团光和一颗星芒）、`Shot.twinkles`（路过时沿途闪四角星芒）。
- **命中**：`FormImpact` 有形式的主角牌不走 `SpawnBodies`。先是各自的落地形态（`ImpactPaths`），再加炸开：`BurstSpikes`（身份材质的锥刺，角度和长度错开，晶体直、火和烟弯、彩虹每根换色）加 `Flares.Explode`（白闪、星爆、撕裂溅射、横向抛出的光刺、身份碎屑、地面溅射）。`reach` 按命中深度的屏宽算：单体 0.62、荒谬 0.55、普攻 0.5 个半屏宽；群体主目标再乘 0.6、其余乘 0.4。普攻不再叠形态层（手机上读成一团）。
- **出手光** `CastLight`（`BattlePrototype.BeginPlayerSpectacle` 调，带 `HeroChestPoint`、`HeroFeetPoint`）：主角背后的光晕和脚下地面光、从肩背和身侧往上往外飘开的四缕细光丝（丝的外观，169.65 起；以前的身份材质宽光舌被用户否掉）、脚下转动的细断弧法阵（两圈，始终留缺口，不闭合成环）都用 `sweepUnderMaterial`/`flareUnderMaterial`（renderQueue 2990，在背景 1000 之后、视频主角 3000 之前画，主角挡在光前面）；身上升起的身份粒子、四角星芒、出手瞬间的手部闪光、全身一亮和从胸口抛出的光用普通材质画在主角前面。普攻只留小光晕、三颗星芒和手部闪光。
- 释放时刻与 `Launch` 一致：`release = contact − clamp(contact × .45, .22, .42)`。
- **散开、不留形状**（`Dispersing` → `Body.Disperse`/`Unravel`）：命中体和出手光淡出时网格不切开，每个顶点按自己的平滑方向被推开（背离命中点和本体中心、Perlin 湍流、上升；推开距离 = 命中尺寸 × 1.1 + 本体尺寸 × `stretch`，出手光 `stretch` 为 0），侵蚀加快，光点从被扯开的位置陆续冒出（`Flares.Scatter`）。不要把网格切成碎片：169.56–169.57 切出来的是直边四边形，还有暗线。
- **外观覆盖** `Path.look`：命中体可以借另一种材质的外观画（贴图行、撕边、刻面），身份的光点和命中心不变。出手光丝、法阵弧、错步的剑光和光芒都用 `Matter.Silk`（最顺滑、只有亮芯和流线）：身份材质画在宽带子上，晶体读成碎玻璃板。
- **错步落点** `Family.MirrorCut`（镜光交叉斩）：两道细长弯月剑光交叉成 X，再加一道短的，两端针尖、亮芯粗；`Flares.AlongCut` 沿刀线闪星芒；`BurstSpikes` 对 `Form.Dash` 只出 6 根细光芒。`Family.Twin` 未动（铁爪、通缉 B01、守卫还在用）。
- **平静散开** `Dispersing(..., calm: true)`：推开 35%、湍流三分之一、噪声尺度不变，给剑光和细光芒用。别用缩小 `size` 来减推力：噪声尺度跟着变小，细线会被扯出闪电似的小折（169.64）。
- 错步冲刺的地面擦光、鞋印和沿途光点从主角脚下沿走廊往远处走，用 `under` 材质画在主角下层；画在上层时在主角身上叠成一条竖线和一排横条（169.60 起就有，169.63 修）。
- **主角其余五张牌的形式**（2026-10-03/04）：
  - `Form.Edict` 假面谕令：白面具直线飞到敌人脸上，落地是横竖两道细亮光；
  - `Form.Swap` 张冠李戴：两张牌从主角两侧交叉飞出，落地两条名牌反向滑过；
  - `Form.Reverse` 反客为主：先射过敌人身后，再从背后反打回来；
  - `Form.Rewrite` 后手改写：落在主角自己身上，一道划去的亮线，加三道斜向上的细光；
  - `Form.Proclaim` 无名宣告：金色宣告牌升到敌人头顶，光柱和四道舞台光直落。
  - 炸开方向按牌区分（`BurstAngle`）：谕令向上扇形，换名向左右两扇，反客朝主角方向。
  - 这五张牌在 `FoolEffekseerSkillVFX` 里不再放旧剧场，只保留原来的 contact/结束时刻（`TimedContact`）。
- **敌人名招**（2026-10-04，用户：“改前的绚丽是值得要的，但要有差异”）：
  - 凤凰 `Phoenix`、飞剑 `FlyingSwords`、簪刺 `Needles`、审判之剑 `JudgmentSword`、断头斧 `ExecutionAxe`、钟针 `ClockHands`、锁链 `Chains`、兽爪 `ClawRake`；
  - 旋风加了 `Path.pulse`（忽大忽小）；
  - `Path.shatter` 让本体淡出时迸出碎片和羽毛（`Flares.Shatter`）。
  - 有名招的身份不画宽形态层（`SpawnBodies` 里的 `named`），命中心只剩一个小闪光（`Heart` 的 `quiet`），名招本身当主体。
  - 分配见 `Profiles` 表；同一条线上相邻的敌人不要用同一种名招。
- 敌人的招恢复原尺寸，全屏染色乘 0.85；炸开半屏只对主角牌。
- 别的旧法术脚本里的曲带、管子都先过 `StraightLines20261003`：只留三成弯度；首尾相接的环缩成一小团。
- 调试构建输出 `SPELLFORM light/launch/shot/impact` 日志，用来在录像里对时间。

## 如何加一个新签名招式

1. 在 `Accent` 枚举末尾加名字（不要插到中间）。
2. 在 `AccentPaths` 的 switch 里加一个 case，返回若干 `Path`。用 `Make(n, pos, across, half, bulge)` 生成：`pos(t)` 走向，`across(t)` 宽度方向，`half(t)` 半宽。所有随机值**在 lambda 外**先取好（见 lessons.md 第 2 条）。地面相关用 `f.Foot` 和 `f.Depth`。
3. 需要到达火花的路径设 `impactAt`；需要旋转/展开/飞入的用上面的动作字段。
4. 在 `AccentMarks` 加对应粒子（环绕粒子用 `orbit=true` 加 `oc/oax/ou/ov/r0/r1/w/rise`）。
5. 在 `Profiles` 里把最贴语义的身份改成新签名。
6. 编译 → 探针录这几个身份 → 看峰值条和近景 → 调 → 全量。

## 如何加一种新材质

1. `make_matter.py` 加一个 `row_xxx()`，四个通道语义保持一致，把图集改成 9 行（同时改 shader 里的 `/8` 和 `7-_Row`）。或者替换一个不用的行。
2. `Matter` 枚举加值；`MatterLook` 加一行（tear、边缘软硬、facet、ink、distort、flicker、流速、平铺）。
3. `Flares.Heart` 加这种材质的命中心。
4. 重新生成图集并复制到 `Resources/SpellSpectacle20260926/`，确认 `.meta` 里 `enableMipMap: 0`。

## 如何给新敌人或新通缉头目配身份

1. 在录像里看它实际用的是哪个模型模板、身上挂了哪些组件（皮肤/身份组件），决定 `model` 怎么识别。
2. 在 `Profiles` 加一行，五个维度按 SKILL.md 的原则选，并和同场景常见敌人对比，确认不雷同。
3. 在 `EnemyProfile` 的查找列表里加上它的 key。
4. 在 `assets/capture-plan-98.json` 加录制行（格式照抄同类行：setup 用 `wave-instances:clock-guard-primary@<皮肤>` 或 `church-tower:...`，`expected` 为预期 contact 数，expected 为 0 的行 `safety` 设为 false）。
