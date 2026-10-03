# 交接：主角 v4、模拟器复看、技能牌与遗落物衔接 · 2026-10-02

> **2026-10-03 更新**：后续进展见 [法术“往前打”样板与封印物版设计交接](HANDOFF_SPELL_FORMS_20261003.md)。模拟器已换成 iPhone 17 Pro Max（`E64100C9…`），本文里的 `B4897FBE…` 设备数据已被清理。

## 现在在哪（先读这一节）

- **模拟器**：iPhone 17 Pro（iOS 26.5，UDID `B4897FBE-4AB9-40B7-8DE7-9F1AE31FA9FE`）装着 **169.29**，主角样板静音运行（`-MistportCityMute YES --tempo-device-review=hero`）。左下角“换样板”可以重看，或切换三套服装。另一台已经启动的 iPhone 16 Pro Max（iOS 18.6）不是本会话开的，不要动。
- **手机**：iPhone 13 上是 **169.26**（主角 v4、样板法术特效恢复、第一版全身施法）。169.27–169.29 只装在模拟器，**没有装机**。
- **等用户看、还没有认可**（不能记为合格）：
  1. 主角 v4 三套服装的模型；
  2. 新的战斗架势待机和全身施法；
  3. 节奏样板战斗里的法术特效。

  用户 2026-10-02 刚要求过“待机也要有战斗的样子”，169.28 起已经改成战斗架势，用户还没看过。
- **等用户选**：技能牌与遗落物衔接的五种方案。推荐“抢戏”为主、“对戏”为辅。
  - 方案稿只在分支 `claude/skill-relic-design-20261002`：`mistport-ios/docs/game-design/chapter-one-30/SKILL_RELIC_INTERPLAY_20261002.md`。
  - 阅读版（私有）：https://claude.ai/artifact/3mWRNy2Ui99WRhCStCtQNT

## 分支（全部已推送，都没有合入 main）

| 分支 | 最新提交 | 内容 | 基底 |
|---|---|---|---|
| `claude/decisions-20261001` | `b011d12` | 用户代定事项：身份错置改名张冠李戴；遗落物显示名改回无主假面；贵族区要城市贡献度 300 才开放 | main `758d409` |
| `claude/hero-v4-20261001` | `6366ddf` | Blender 程序化主角 v4 第 1–4 轮：模型、贴图、骨骼、14 段动作 | main `758d409` |
| `claude/hero-v4-device-20261001` | 本交接所在提交 | 合并上面两条，加 Unity 接入和本次所有修正。Blender 工具以这条为准，比 `claude/hero-v4-20261001` 新 | Codex 的 `codex/return-buttons-device-20261001`（`b8af649`），因此带着 PR #40、#41、#42 还没进 main 的内容 |
| `claude/skill-relic-design-20261002` | `3d00796` | 技能牌与遗落物衔接方案稿，只有文档 | main `758d409` |

**合并顺序**

- decisions 和 skill-relic-design 两条可以直接对 main 开 PR。
- hero-v4-device 要等 PR #40、#42、#41 先进 main，或者把主角相关提交重放到合并后的 main 上。
- 本机没有 gh，所以没开 PR。
- 用户之前同意的合并顺序是 #40 → #42 → #41。

## 本次做了什么

### 用户代定事项（decisions 分支）

- **改名**：张冠李戴、无主假面两处改名，覆盖规则库、测试、App、Unity 显示名、特效工具脚本和设计文档。
- **贵族区**：`HousingStamina.swift` 新增 `noble` 区，下设两项：
  - 公馆客房 `noble_suite`：每天 40 铜，体力 +12；
  - 公馆膳房 `noble_dining`：每天 20 铜，体力 +8。

  城市贡献度不到第 4 档（300）时，签约会抛出 `.notAllowed`。赁屋行显示一行锁住的贵族区和说明。测试覆盖了 299 被拒、300 通过。
- **区名**：区名只在赁屋行出现，这一点原来就满足，没有改。
- **测试**：规则库 decisions 分支 560 项、集成分支 565 项，当时全部通过。本次后续改动没有动规则库。
- **代定了但还没写进设计文档**：
  - 每日内容目标，倾向“每天 30–45 分钟正经内容，加可选的重复工作”，用户没有确认；
  - 合并顺序 #40 → #42 → #41。

### 主角 v4

- **源码**：`tools/animation/build_hero_v4.py` 和 `tools/animation/hero_v4/`。
- **服装**：三套服装（雾港夜行、星辉魔术师、午夜嘉年华），共用 28 根骨骼和 14 段动作。
- **面数**：共用身体 56,604 面；三套服装分别 61,428、66,720、65,588 面。
- **Unity 接入**：
  - `RefinedHeroV4Import.cs` 读取 `materials.json`，生成材质和 Animator；
  - `HeroPaintedV4.shader` 负责描边、顶点 AO、跟随相机的主光；
  - 资源放在 `Assets/Resources/CombatTempo/RefinedHeroV4/`；
  - `CombatTempoPresentation` 默认加载 v4，编辑器里可用 `--hero-v3`、`--hero-v2`、`--hero-v1` 切回旧版。
- **复看入口**：`--tempo-device-review=hero`，加 `--tempo-outfit=<服装>`。

### 用户反馈后的修正

| 反馈 | 原因 | 修正 | 版本 |
|---|---|---|---|
| “所有法术效果好像都消失了” | 节奏样板截走了技能，只放占位卡片，也没登记华彩层 | `BattlePrototype.PlayTempoSkillVisuals` 播放完整技能特效并登记华彩层；占位卡只留给普攻 | 169.26（`cf8e940`） |
| “施法时只有手动，身体不动” | 动作只有手臂轨迹 | 全身施法：转腰、前倾、下蹲、跨步，腿部用 IK 落地 | 169.26 |
| “待机也要有战斗的样子，现在呆呆直立算什么” | 所有动作的基础姿态是 A 字直立 | 共用战斗架势（下面详述），所有动作从架势起手、回到架势；施法幅度加大 | 169.28、169.29（`da60055`） |
| （自查发现）跨步和站位没效果 | `CombatTempoAnimatedBody` 给主角装了钉脚 IK，按绑定姿势记录目标，权重一直是 1 | 主角不再装钉脚 IK，Blender 动作本身已经让脚落地 | 169.28 |
| （自查发现）开发版屏幕上有红字报错 | `RefinedHeroAppearance` 在字段初始化里创建 `MaterialPropertyBlock` | 改为第一次用时再创建 | 169.29 |
| （自查发现）模拟器会把法术声外放 | 静音参数只管港城环境音 | 带 `-MistportCityMute YES` 时，App 发给 Unity 的 `audio-volume` 为 0；格挡金属声、返场钟声原本写死音量，现在跟随战斗音量 | 169.29 |

**战斗架势**的参数在 `tools/animation/hero_v4/rig.py` 的 `STANCE`、`FEET`、`R`、`L` 里：

- 左脚在前，右脚后撤并外撇 45°；
- 重心下沉 12.5 厘米；
- 侧身 28°，前倾 10°；
- 右手持牌架在头侧，左手放在腹前。

待机时在这个架势上加呼吸起伏、重心左右移动和翻牌。各招的转腰、下蹲、跨步幅度在 `BODY` 里。

### 技能牌与遗落物衔接（设计稿）

方案、推荐和四个待定问题都在方案稿里。写稿时查明了这些事实：

- 第一章拿不到假面谕令这张牌，Q3 给的是遗落物；后手改写要到第一章结尾才取得。
- 规则层只能识别组合 K01、K02，K03–K10 只是写在内容表里。
- 出牌只有第一轮按卡栏顺序，之后谁的冷却先好谁先出，见 `ContinuousSkillScheduler`。
- 盐仓、镜剧院、潮门、雾冠四个街区挂着二十多件吃误认和错位的遗落物，但玩家只能进旧城区，所以拿不到。

## 构建与装机记录

| 版本 | 装在哪里 | 内容 | 核对 |
|---|---|---|---|
| 169.25 | iPhone 13 | 主角 v4 首次装机 | Preferences 装机前后 264 份逐字节相同 |
| 169.26 | iPhone 13 | 特效恢复，第一版全身施法 | 264 份相同；75 秒控制台无异常，内存 600–785 MB |
| 169.27 | 模拟器 | 169.26 加一次无效的 Unity 端静音尝试（已删） | 95 秒录像：特效出现；样板报告为胜利，第 6 回合，主角剩 872/1000 |
| 169.28 | 模拟器 | 战斗架势，去掉钉脚 IK | 70 秒录像：架势和全身施法出现 |
| 169.29 | 模拟器 | 复看静音、红字报错修正 | 控制台无异常，屏幕红字消失；静音只核对了代码路径，没有实际听 |

- **签名包和 Preferences 快照**：`/Volumes/andrew's SSD/Mistport-archives/releases/Build169.25-hero-v4` 和 `…/Build169.26-hero-v4`。
- **模拟器产物**：在 `/Volumes/andrew's SSD/Mistport-build-cache/hero-v4-sim-20261002/`。
- **复看录像、日志、姿态渲染**：在 `/Volumes/andrew's SSD/Mistport-archives/hero-v4-20261002-review/`。
- **证据图**：`docs/development/hero-v4-20261002/`。都是模拟器或 Blender 的图，不是真机，也不是用户认可。
- **版本号**：本会话用了 169.25–169.29；SSD 上已有 Build170（城市会话的）。下一次装机前，按 memory 里的规则先查已有编号再选。

## 怎么复现

**构建**：`scripts/build_hero_v4.sh`（本次新增）。模拟器模式已用 169.29 实跑通过；真机模式还没用这个脚本跑过，步骤与 169.26 当时的真机流程相同

```bash
scripts/build_hero_v4.sh simulator 169.30 --blender
```

```bash
scripts/build_hero_v4.sh device 169.30
```

- `--blender` 依次跑：Blender 导出 → Unity 导入 → Unity iOS 导出 → 新鲜度检查 → Xcode 构建。不加时只从 Unity iOS 导出开始；`--import` 只重建 Unity 材质。
- 模拟器导出会替换 `mistport-ios/UnityBuild`，所以下次真机构建前必须重新导出。device 模式会自动导出。
- Unity 做模拟器导出时，会把 `ProjectSettings.asset` 的 `iPhoneSdkVersion` 改成 989。脚本结束时会还原，不要把这个改动提交。

**装进模拟器并静音启动**

```bash
xcrun simctl install B4897FBE-4AB9-40B7-8DE7-9F1AE31FA9FE "/Volumes/andrew's SSD/Mistport-build-cache/hero-v4-sim-20261002/Derived/Build/Products/Debug-iphonesimulator/Mistport.app"
```

```bash
xcrun simctl launch --terminate-running-process B4897FBE-4AB9-40B7-8DE7-9F1AE31FA9FE com.yourcompany.mistport -MistportCityMute YES --tempo-device-review=hero
```

- 要看 Unity 日志，就在启动命令里加 `--console-pty`，把输出重定向到 `/private/tmp` 下。
- 不要把 `--stdout`、`--stderr` 指到 SSD 路径，否则启动会被拒（SBMainWorkspace denied）。
- `simctl io recordVideo` 也不能直接写到 SSD，会报无权限。先录到 `/private/tmp`，再复制到 SSD。

**复看工具**

- `scripts/video_contact_sheet.swift`：从录像里截一段时间，按需裁剪，拼成带时间标签的图。
- `tools/animation/hero_v4_pose_sheet.py`：把 Blender 姿态渲染拼成“四个机位 × 七个相位”的图。渲染命令：

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/animation/build_hero_v4.py -- "$PWD" --pose-frames BattleIdle,CastFinaleThrow --pose-dir /private/tmp/hero-pose
```

## 已知问题与观察（都没改）

- **石颚碎石**：石颚重击飞出的碎石是纯色四面体（`CombatTempoVFX.Sparks`，棕色）。有一片飞到镜头前时，会变成一大块棕色三角形。这是敌人的旧特效。
- **胜利后不结算**：复看样板打赢后不切结算画面，停在战场上，敌人也还站着。
- **启动参数到不了 Unity**：iOS 上宿主的启动参数没有传进 Unity 的 `Environment.GetCommandLineArgs()`（试过，代码已删）。要给 Unity 传开关，请走 `UnityBattleRuntime.send(action:)`。
- **模拟器观感**：模拟器上 Effekseer 改用 Unity 渲染，ASTC 纹理被解压，法术观感可能和手机不同，以真机为准。
- **旧模拟器脚本**：`scripts/build_player_test_simulator.sh` 依赖 iOS 18.6 时期预编译的界面资源。现在已装 iOS 26.5 运行时，用新脚本即可。

## 下一步

1. 等用户在模拟器里看 169.29。按反馈调整：架势改 `STANCE`、`FEET`、`R`、`L`，施法幅度改 `BODY`。改完用 `--blender` 重建，在模拟器里录像核对，再交给用户。
2. 用户要装机时：
   - 先查已有版本号；
   - 跑 `scripts/build_hero_v4.sh device <版本号>`；
   - 按 AGENTS.md 装机前后逐文件核对 Preferences；
   - 带 `-MistportCityMute YES` 静音启动。
3. 用户选定衔接方案后，先做状态显示：敌人头上的误认、错位，牌在条件满足时发光，不改数值。然后按方案稿第 5 节分批做，每批都重跑墙关三档。
4. 合并按上面的分支表。

## 不要做

- 不要把模拟器画面、录像或作者观察记成用户认可。
- 不要动别的会话开的模拟器；不要覆盖真实存档；版本号先查再用。
- 不要删除 SSD 上的符号链接、旧签名包和归档。
- 不要提交模拟器导出改掉的 `ProjectSettings.asset`。
