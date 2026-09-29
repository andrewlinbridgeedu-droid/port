# 华彩层架构

## 目录

- 文件
- 生命周期与挂接点
- 身份识别
- 生成一次命中
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
| `SpectacleAtlas.png` | 2048²：星爆 2×2（左上）、撕裂溅射 2×2（右上）、粒子 4×2（下方 1024–1536 行：Spark/Ember/Shard/Ink/Petal/Card/Wisp/Puff） |
| `SpectacleNoise.png` | 可平铺噪声 |

生成器在仓库 `tools/vfx-spectacle-20260926/`：`make_textures.py`（星爆/溅射/粒子/噪声/金纹）、`make_matter.py`（材质图集，import make_textures 取金纹行）。需要 `/tmp/mistport-vfx-encode/venv`（numpy、pillow、imageio-ffmpeg）。

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
