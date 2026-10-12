# 交接：法术手绘化、敌人整身出招、猎犬冥火与翡翠亡魂 · 2026-10-10

接在 [SPELL_SPECTACLE_20261007.md](SPELL_SPECTACLE_20261007.md) 之后，覆盖 10-07 到 10-10。只写**现在在哪、哪些用户认可了、下一步做什么、怎么做**。做法细节和被否掉的教训在项目 skill：`.claude/skills/mistport-spell-spectacle/SKILL.md`（"现行做法"和"当前进度"两节）与 `references/lessons.md`，动手前先读。

## 1. 现在在哪（先读这一节）

- **分支**：`claude/ai-hero-integration-20261003`，工作树 `/Volumes/andrew's SSD/Mistport-worktrees/hero-v4-device`。
- **最后一次提交**：`4ed6d5a`（10-05，椭圆光盾）。**10-06 以后的全部法术工作都没提交**（见第 7 节文件清单）。提交、推送、合入 main 都要等用户开口。
  - 不要提交 30 个 `UnityBattleSource/Assets/Resources/CombatTempo/AIHero/**/*.png.meta`。
  - 不要合并 `edf41cb`（需要用户在场）。
- **最新构建**：模拟器 **170.33**（10-10 01:51 起构建，Unity 导出新鲜度检查通过，日志 `output/hound-emerald-20261010/build-170.33.log`）。
  - 已装在模拟器 `iPhone 17 Pro Max`（E64100C9-43DA-4B8C-996A-2D953A13219C）上，第 5 关实战录过（第 4 节）。
  - 构建模拟器版会把 `ProjectSettings.asset` 的 `iPhoneSdkVersion` 从 988 改成 989，出真机包时会改回去，不是功能改动。
- **手机（iPhone 13）**：这几天本线没有装机。装机只在用户说"装机"时做；装前用 `xcrun devicectl device info apps` 查实时版本，不以文档为准。
- **测试存档**：`output/playtest-save-backups/q14-cleared-20261005/` 的两个 plist。每次模拟器跑完都要拷回 App 数据容器的 `Library/Preferences/`，再用 `cmp` 逐字节核对。170.33 第 5 关前后都已核对一致。

## 2. 用户认可状况

**已认可**（录像或模拟器里用户明确说可以）：

- 主角 11 张牌（含 Q12 实战）。
- 敌人：钟卫、红雾灵、猎犬扑咬爪痕、档案馆馆员、记忆水蛭/吞名、族母、执行者、瑟维安铜手、锤卫、铁爪、石皮、盐喉两招、教堂塔后 6 个（"非常好"）、B03 鬼浪漩涡（"可以了"）。
- 敌人出招三件套（施法聚光、命中层、光色跟法术走）连同整身动作：用户"可以，打模拟器版"。
- **10-10**：翡翠亡魂·翠毒漫天新版（六缕毒雾 + 整场地上毒泡 + 统一翠绿）"可以"；翡翠亡魂·返场毒爆"可以"。
- 猎犬冥火喷吐和第 4 关两连发大火球：10-10 用户"已经确定"。

**做了、还在等确认**：时钟核心第三版、第四批（押运、救援、第十三响）、鳍蛇、瑟维安视频身体的前冲替身、悬赏其余招式、猎犬冥火喷吐的模拟器实战（还没录）。

**搁置**：

- 敌人描边（`EnemyOutline20261009`）。代码留着，默认关闭；用环境变量 `MISTPORT_OUTLINE=ink|glow` 打开（录制时用）。深色描边在黑色敌人上几乎看不见；蓄力发光边效果明显。用户："先不管放光"。
- 瑟维安视频：只做了普攻一条。待机、蓄力、受击三条等用户的生成额度；提示词第三版（全身动）在 `output/sevian-video-20261009/PROMPTS.md`，原片 `strike.mp4` 和输入图都在。

## 3. 10-10 做了什么

### 3.1 手绘图接入

- 用户画的三张图：`hellfire_breath`、`emerald_fog`、`emerald_burst`。另外从 `emerald_burst` 里裁出三颗毒泡 `poison_bubble_a/b/c`，色相 +19（满值 255）对齐毒雾图。
- 都在 `ArtSource/SpellProps20261007/`，共 46 张。
- 拼进 `SpectaclePaint3.png`：39 冥火，40 毒雾，41 毒爆，42–44 毒泡，都是黑底光效格。

### 3.2 猎犬冥火喷吐

用于早期猎犬、后期披甲猎犬（签名施法）和塔猎犬。

- 画法：`SpellSpectacle20260926.EnemyBreath` 在旧流程"出发"那一刻调用，传入离命中还有几秒；吐息从嘴里长出来，命中时正好到主角。命中后由 `PaintedSubject("hellbreath")` 画手绘火爆开、火舌上窜、暗红烟。
- 旧的火球和云：`HellHoundEffekseerFireball`、`EmeraldRevenantSpell`、`EnemySignatureSpellVFX` 的猎犬分支，在 `DrawsBreath` 为真时只保留原来的计时和命中回调，不再画。
- 猎犬扑咬（`bite`）仍是已认可的爪痕（`ClawHit` 只认 `bite`）。
- **第 4 关两连发**（`Q4HoundPresentation.Shot`）按用户要求保留旧的大火球飞行，落点改用手绘火；旧爆炸和旧爆点光球隐藏。蓄力时身上那两颗火球仍是旧的。

### 3.3 翡翠亡魂（规则里只有两招，没有抓击）

- **翠毒漫天**：六缕 `emerald_fog`，各走一条弯路，尾巴拖后，命中时到主角腿边，绕一圈后撕散（`BreathStream`）。命中处只冒一点同色烟。
  - 规则：开场放一次，本身不造成伤害；毒雾持续到战斗结束，每 3 秒加浓一级；第 19 关回气时降回 1 级。
  - 画面：`SpellSpectacle20260926.PoisonPool` 跟着 `emerald-poison:N` 在主角脚边常驻毒泡。1 级 7 个，每级 +2，最多 24 个。毒泡用 `Ink2D.CreatePool` 加 24 个手绘毒泡精灵，同一个时钟；N=0 或清场时消失。
  - 每次加浓时的烟，原来是通用的青色上涌，改成手绘烟，染成 `PoisonGreen`（`PlayState("poison-field")` → `PoisonTick`）。
- **返场毒爆**：毒焰在嘴边蓄成一团，射向主角，在主角身上先缩后炸，火舌上窜，带少量黄绿烟。
- 变体：`BeginEnemy` 读 `BattlePrototype.EmeraldVariant`，由 iOS 在攻击前发的 `emerald-spell:mist/burst` 决定。

### 3.4 被否掉的（已写进 lessons）

- 一整团毒雾滚到主角身上（"这团东西不好看"）。
- 程序画的扁平毒泡（"这些泡泡有些假"）。
- 同一招里黄绿和青绿并存（"这两种绿颜色要一致"）。
- 一整团毒爆后的大黄绿烟球。

## 4. 验证记录

| 层级 | 结果 |
|---|---|
| 编辑器录制 | 每版录过 M05/M07/M08 和自定义的 X1–X3（翡翠亡魂三段），录制断言全过。录像已按用户要求删除（见第 6 节），需要时重录 |
| 模拟器 170.33 | 第 5 关"不肯落幕"实战打赢：约第 16 秒翠毒漫天，之后整场毒泡，约第 33 秒返场毒爆。剪辑 `output/hound-emerald-20261010/sim-170.33/q5-170.33.mp4`（原速 + 两招各一段 1/2 慢放） |
| 模拟器 170.32（10-09） | 第 30 关输、第 20 关赢、塔第 11 层；塔第 11–40 层逐层打通并录了第 40 层（测试存档已恢复，层数没有保留）。这些录像已删 |
| 真机 | 无 |

## 5. 下一步（建议顺序）

1. 模拟器实战录第 3、4 关，看猎犬冥火喷吐和两连发大火球。用 170.33 即可，不用重新构建。
2. 把第 2 节"还在等确认"的几项逐个重录给用户看（旧录像已删）。
3. 用户有额度后做瑟维安待机、蓄力、受击三条视频，用 `tools/animation/prepare_sevian_video_body.py` 处理（要用 SSD 上 media-venv 的 python）。
4. lessons 里记着、还没做的出招问题：
   - 剧情敌人把 1.4 秒的 Charge 压进 0.4 秒；
   - 塔小怪动画暂停时没有逐帧步进；
   - 悬赏只放 Cast；
   - 雾灵手臂动作落在隐藏的守卫骨骼上；
   - 翡翠亡魂没启用骨骼层；
   - 早期猎犬的"攻击"其实是走路动画。
5. 用户要求提交时，建议按主题分几次提交：华彩层与手绘图、敌人整身动作、瑟维安视频身体、命中震动（`mistport-ios` 的三处 haptics 改动，10-08 的 hit-feel 工作），描边试验单独一次。

## 6. 10-10 的两件环境事

- **模拟器数据被外部清空**：01:59 本机 `~/Library/Developer/CoreSimulator` 被整个删掉重建（不是本会话做的，多半是别的会话在清本机磁盘）。E641 的 App 和测试存档全丢，正在运行的模拟器卡死。
  - 处理：`simctl shutdown` → `simctl erase` → `boot` → 重装 170.33 → 放回测试存档并核对。
  - 以后核对存档前，先确认数据容器里确实有 `Library/Preferences`。
  - 旧的模拟器设备集还在 SSD 的 `/Volumes/andrew's SSD/Library-Developer/CoreSimulator/Devices/`，没有动过。
- **按用户要求永久删除了旧录像**：`output/` 下 11502 个文件，约 13.3 GB；会话临时目录约 2.7 GB。
  - 保留：`playtest-save-backups/`、`ref-handdrawn-vfx-20261008/`、`shield-effekseer-ref-20261006/`、`handdrawn-vfx-20261008/bin|compile|work/*.py`、两份提示词文档、瑟维安原片与输入图、各 `build-*.log`、`spell-spectacle-20261007/SpellSpectacle.new.cs`。
  - `output/` 下没有符号链接，没有动到任何链接。

## 7. 怎么做（命令）

- **录制**：`bash .claude/skills/mistport-spell-spectacle/scripts/record.sh <输出目录> --only=M05,M07`（必须用 bash）。
  - 翡翠亡魂的变体顺序 M11 复现不了（攻击指令先于变体指令），用 `assets/capture-plan-emerald.json`（含 X1 翠毒漫天、X2 返场毒爆、X3 翠毒漫天 + 浓度 1→3）：先拷进输出目录，命名为 `capture-plan.json`，再录 `--only=X3`。
  - `*-close.mp4` 只对着敌人，飞向主角的东西看全景 `*.mp4`。
- **抽帧 / 编码**：`output/handdrawn-vfx-20261008/bin/extract_range <视频> <目录> <起秒> <止秒> <fps> 0 0 4000 4000 0`；`output/handdrawn-vfx-20261008/bin/encode <帧目录> 30 <输出.mp4>`。
- **拼图集**：`python3 tools/vfx-spectacle-20260926/paint_atlas.py ArtSource/SpellProps20261007 <输出.png> 3`（要带 PIL 的 python，不能加 `-I`），再拷到 `UnityBattleSource/Assets/Resources/SpellSpectacle20260926/`。
- **模拟器构建**：`MISTPORT_SIM_DEVICE="iPhone 17 Pro Max" sh scripts/build_hero_v4.sh simulator <版本号>`。
  - 产物在 `/Volumes/andrew's SSD/Mistport-build-cache/hero-v4-hero-v4-device-simulator/Derived/Build/Products/Debug-iphonesimulator/Mistport.app`。
  - 安装：`xcrun simctl install <UDID> <app>`。
  - 静音启动：`xcrun simctl launch <UDID> com.yourcompany.mistport -MistportCityMute YES --developer-tools`。
- **模拟器里进关卡**（点坐标，440×956 点）：标题页"测试"(313,87) → 关卡列表点关卡 → "跳过对白"(82,272) → "开始战斗"(219,440)；塔里"下一层"(220,572)。
- **录模拟器屏幕**：`xcrun simctl io <UDID> recordVideo --codec=h264 --force <文件>`，只能写到会话临时目录（写 SSD 会被拒），结束时 `kill -INT`。

## 8. 未提交文件（主要）

- 改动：
  - `Scripts/SpellSpectacle20260926.cs`（主体）、`BattlePrototype.cs`、`EnemySignatureSpellVFX.cs`、`HellHoundEffekseerFireball.cs`、`EmeraldRevenantSpell.cs`、`Q4HoundPresentation.cs`；
  - `Bounty*`、`SaltmawSpell20260919.cs`、`ChronarchPresentation20260916.cs`、`MainlineBodyRound2.cs`、`CombatTempoPresentation.cs`、`AIHeroAnimatedBody.cs`、`OvalLightShield.cs`、`PlayerImpactFeedback20260925.cs`、`StraightLines20261003.cs`；
  - `AGENTS.md`（冲击环例外）、skill 两份文档，`mistport-ios` 的 haptics 与 `ChapterOneTestView.swift`。
- 新增：
  - `EnemyWholeBody20261009.cs`、`EnemyOutline20261009.cs`、`SevianVideoBody20261009.cs`、`HitShake20261007.cs`、`HitShakeRestore20261007.cs`、`SpellBloom20261008.cs`；
  - `Resources/SpellSpectacle20260926/` 下的着色器和图集、`Resources/EnemyOutline20261009/`、`Resources/CombatTempo/SevianVideo/`；
  - `ArtSource/SpellProps20261007/`、`tools/vfx-spectacle-20260926/paint_atlas.py` 等工具、`tools/animation/prepare_sevian_video_body.py`。
- 删除：`Resources/Shaders/OvalLightShield.shader`（10-07 光盾第三版不再画整片光膜，改用 `OvalShieldParts.shader`）。

## 9. 10-10 上午追加（另一会话）

- 修了两条出招遗留问题（详见 skill `references/lessons.md` 末尾三条）：剧情敌人蓄力被压进 0.4 秒 → `StoryStrikeTiming20261010`；早期猎犬出招是走路动画 → 所有关卡装节奏版身体并播 Pounce/HeavyRelease。顺带修了施法聚光在换波次后不消失（安全检查之前就失败）。原件 `backups/motion-fix-20261010/original/`。
- 验证：编辑器改前/改后录制（`output/motion-fix-20261010/before|after`，各 38 项）；`safety2/` 录制 50 项 + 安全检查 220 项全过，源码一致 `24a214e70c5c`。对比视频 `output/motion-fix-20261010/motion-before-after.mp4`。**没出模拟器包**（下一个号 170.34）。
- 瑟维安三条视频提示词第三版已存 `output/sevian-video-20261009/PROMPTS.md` 末尾。
- 剩下的出招遗留：塔小怪动画暂停时没有逐帧步进；悬赏只放 Cast；雾灵手臂动作落在隐藏的守卫骨骼上；翡翠亡魂没启用骨骼层。

## 9. 补记（10-10 中午）：瑟维安视频与最终 Boss 方案

- 用户交回的视频：12:04 与旧 `strike.mp4` 逐字节相同；11:56 是只动手臂的推掌（掌心冒光，不用）；12:03 是全身横扫；12:46 是“夺名代签”签名动作。都在 `output/sevian-video-20261009/takes-20261010/`（12:04 那条重复，已删）。
- **普攻身体**：换成 12:03 横扫（`prepare_sevian_video_body.py sweep`，出手帧 21 = 侧身推出铜手），撤掉了 `SevianVideoBody20261009` 里的临时前冲，`ChronarchPresentation` 改成 `PlayStrike(1f,2f)`。编辑器 M30 录过，用户“这个可以的”。旧素材在 `backups/sevian-strike-20261009/`。
- **签名动作**：12:46 已抠成 `Resources/CombatTempo/SevianVideo/sign.*`（`sign` 预设，FIGURE 400 给举笔留空间，按掌时头顶冒出的手写字已擦掉，出手帧 31 = 一掌按出）。手里突然出现的黑色长笔保留，接入时在出现那一刻用金光遮一下。**还没接进游戏**：`SevianVideoBody` 目前只读 `strike`，接第二段要按各自的 `figureHeight` 缩放面片。
- **最终 Boss 方案（待用户点头，未改规则）**：第 30 关现在只有 strike / thirteenth_charge / slam 三个攻击（`chapterThirtyIntentPattern`、`resolveChapterThirtyIntent`），血量 `MPCProgressionWalls.q30SovereignHP = 6500`。用户要求至少 4 个技能、超厚血。提议：铜手按印（横扫）、第十三响（蓄力砸地视频）、镇钟重砸（共用砸地视频，不蓄力，手绘碎岩染铜色）、新招“夺名代签”（封住主角一张技能牌 6 秒）；血量约 12000，分 100–60 / 60–30 / 30 以下狂暴三阶段。数值要先用推进模拟器验证每天 1–2 小时的玩家能过。
- **还缺的视频**：待机、蓄力（举拳过头斜砸）、受击。提示词在 `PROMPTS.md`（第三版全身动；夺名代签是加大幅度后的那版）。

## 10. 补记（10-10 下午）：终战组队方向、瑟维安多段动作、猎犬模拟器实战

- **终战组队**：用户提出最终 Boss 改为 3 人组队（2 个 AI 队友）。用户同意奥黛尔入队；玛拉的真实身份是黑夜教会女神的分身，不当普通队友。草案见 `mistport-ios/docs/game-design/chapter-one-30/FINAL_BOSS_PARTY_20261010.md`（推荐第二人诺恩·凯德，附两人全身原画和 8 条视频的提示词）。**规则没改**，等用户确认第二人选、范围（只第 30 关还是 28–30）、玛拉是否剧情介入、血量方向。规则引擎原本就有 AI 同伴（`MPCChapterOneCatalog.companions`、`companionCandidates`），第一章 30 关目前 `companionSlots` 全是 0。
- **视频额度**：用户今天没额度了，明天交瑟维安的待机、蓄力、受击，以及（定了以后）队友的视频。
- **`SevianVideoBody20261009` 改成多段**：按名字读 `strike`（必需）以及 `sign / charge / hit / idle`（可选）。每段按自己的 `figureHeight` 换面片尺寸；有 `idle` 时休息播循环，没有就停在普攻首帧并保留呼吸；`Play(clip, contact, recover)`、`PlayHit()` 已备好，**还没接触发**（第十三响 / 夺名代签 / 受击等规则定了再接）。编辑器录过 M30，编译通过，日志 `clips=strike,sign`，表现不变。明天视频到了：在 `prepare_sevian_video_body.py` 加对应预设（看抽帧定时间点和出手帧），出 `<名字>.json/.png/-idle.png` 放进 `Resources/CombatTempo/SevianVideo/` 即可被读到。
- **模拟器 170.33 实战**：第 3 关打赢，猎犬冥火喷吐出现几次；第 4 关输了（这关要在两团火亮起时手动用假面接火球，自动战斗不会用），两连发大火球都录到。剪辑 `output/hound-emerald-20261010/sim-170.33/q3-q4-170.33.mp4`。测试存档每次跑完都已恢复并逐字节核对。


## 11. 补记（10-10 晚）：终战组队规则、天使出场、队友骨骼动画

- **规则（已完成，规则库 600 项测试全过）**：第 28–30 关三人组队（诺恩 + 新加的奥黛尔·芬，AI）；三人全倒才输，奥黛尔用 3 秒救起主角（复活 1 次）；第 30 关瑟维安 20000 血、三阶段、四招（铜手按印 / 第十三响 / 镇钟重砸群攻 / 夺名代签封技能）；模拟验证“好遗落物才能过”；第 28、29 关普通遗落物能过；第 30 关输了不给提示。数值与模拟表见 `mistport-ios/docs/game-design/chapter-one-30/FINAL_BOSS_PARTY_20261010.md`。装备血量存回存档的旧问题由用户另开的会话修好。
- **瑟维安新招画面**：镇钟重砸（用户画的 `bronze_bell`，三团碎岩已按用户要求去掉，金色尘雾加浓）；夺名代签（项目原有的空白名牌 `name_plate` + 金墨 `gold_ink` + 私印）。录制行 Y1/Y2（`assets/capture-plan-emerald.json`）。
- **天使出场**（`SpellSpectacle20260926.AngelIntro`，指令 `angel-intro`，录制行 Y3）：用户画的伊莱娅、巨影（`SpectacleCast.png`，2×2，`tools/vfx-spectacle-20260926/cast_atlas.py`）。翅膀全张开的两张图（`elaia_spread_descend/seal`）用户在画，到了重跑 cast_atlas 即替换（现在用半收翅膀那张兜底）。字幕是草稿，未接进第 30 关开场。
- **队友骨骼动画**（不用视频模型）：
  - 部件图 `ArtSource/FinalBossParty20261010/*_parts.png` → `tools/animation/cut_parts.py` 切块 → `rig/*.json`（关节点手工定，`tools/animation/rig_preview.py` 和全身图对照）→ `tools/animation/pack_rig.py` 打包到 `Resources/FinalBossParty/`。
  - 运行时 `CutoutRig20261010`（动作 attack / cast / guard / hit / down / revive，全身动；`SetHeight` 按主角身高缩放）；`BattlePrototype.PartyRig/PresentPartyAction`，调试指令 `party-show`、`ally:<norn|odelle>:<动作>`，录制行 Y4。
  - **背面版已做（战场用）**：`rig/odelle_back.json`、`rig/norn_back.json` → `Resources/FinalBossParty/*_back.*`；奥黛尔背面拿药瓶的手在另一侧，rig 设 `mirrorPose`（动作左右互换、角度取反）。正面版留给演出和界面。背面视角倒地改为原地瘫坐（整体压低 + 轻微歪斜；压扁的整体里不要再转部件，会斜拉成躺平）。录像 `output/party-boss-20261010/party-rig-back-v1.mp4`。
  - **还没接**：Swift 那边在队友出手、受击、倒地、救起时发指令给 Unity；队友血条与被封技能的界面。
- **10-10 晚再改**：用户“比例不对，敌人也要小一些远一些”。队友改为主角身高的 0.82 / 0.76（诺恩 / 奥黛尔），几乎与主角站齐（前移 0.18 个身高）；三人组队时 `BattlePrototype.ApplyPartyFormation` 把瑟维安后移 1.1 个主角身高、整体与视频身体缩到 0.82（`SevianVideoBody.SizeMul`，`ClearPartyRigs` 会还原）。天使出场已换上展翅图（`elaia_spread_descend/seal`，演出里按 `AngelDescendK/AngelSealK` 放大以对齐身体大小），灯光收小。录像 `party-rig-back-v2.mp4`、`angel-intro-v4.mp4`。
- **天使出场第五版（10-10 晚）**：用户“链有些假、进度太快、反派要多说几句、天使出现后两人笼罩在光团里只隐约看到激战”“整个屏幕震动、空间撕裂、一片昏暗”。改为约 27 秒（时间点常量 `AiRiftOpen…AiClose`）：瑟维安先说四句，追索者一句，伊莱娅两句，瑟维安收尾（草稿台词在录像字幕里，正式要进 Swift 第 30 关开场对话框）；锁链暂用冷光雾气代替；光团用手绘烟雾叠成，里面两人变成深色剪影冲撞，闪光与划痕叠在上面；整屏震动 `AngelShake`（30800 推镜头、-20000 归位，录像和真机都可见）；空中裂口暂用暗烟加柔光；昏暗加深。锁链和空间裂口的手绘图提示词 `output/party-boss-20261010/锁链与空间裂口提示词.md`，等用户出图。录像 `angel-intro-v5.mp4`。录制已改为视频主角（录制行先发 `tempo-sample:chapter01_q30_encounter`）。
- **天使出场第六版**：用户“空中那块有点假”“两个圆圈晃来晃去有点假”。空中裂口替身关掉（`AngelTearsPainted=false`，等 `space_tear` 手绘图）；“两个圆圈”是每次撞击闪光自带的光环，光团里改为不带光环（`ImpactStar(..., ring:false)`）；两人在光团里是深色剪影，按撞击节拍（`ClashBeat` 0.4 s）冲到新位置、身体斜扑，伊莱娅用展翅举杖的剪影；剪影一直隐约可见、撞击时最清楚（`ClashShow`），并且离镜头更近（z 1.4）以免被光雾挡住。录像 `angel-intro-v6.mp4`。
- **天使出场第七版**：用户“这2团还是有些假，其他可以了”（框的是锁链替身的冷光雾柱和地上压扁的裂口烟雾）。两者都关掉，等手绘图（`AngelChainPainted` / `AngelRiftPainted` = false，提示词同上；`space_tear` 到了也平铺在地上当裂口）。没有裂口时巨影原地从黑暗里站起来（只下沉 0.3、1.8 秒淡入、颜色从近黑亮到冷灰），脚下只留一层很淡的冷光；主角胸口的冷光仍表示被锁住。收光那一下的星芒不带光环。
- **离场祝福（用户 10-10：两人离开时随机给主角和瑟维安各一个祝福，小彩蛋）**：画面在 `GiftPos`（`AiGift` = 收光后 0.1 秒）：光团收拢处飞出两样东西，悬停 0.7 秒后飞走——伊莱娅灯里的一簇火（手绘火焰 cell 14，淡金）呈弧线落到主角身上，绽开星芒、金色光点上升；追索者的一撮黑盐（手绘盐晶 cell 17，压暗成蓝灰）落进瑟维安胸口（按视频身体 `FigureHeight × 0.64` 定胸口，3D 身体的锚点在腰），冷光吸入。昏暗延后到两样都落地后才退。画面不区分是哪种祝福；具体效果由 Swift 规则随机（另一个助手在做，见 `FINAL_BOSS_PARTY_20261010.md` 的“离场祝福”节）。录像 `angel-intro-v7.mp4`（末尾附 0.5 倍慢放）。
- **天使出场第八版（光团里的激战）**：用户“天使的激战如果你有办法做得更逼真就更好了”。原来每 0.4 秒撞一下的节拍改成编排好的一整套动作（`FightKeys` 两人各自的关键帧：时间、位置、身体倾斜、移入用时；`FightBlows` 每一击：时间、谁打谁、力度）：
  - 光团合拢时对峙，冲锋硬碰（顿帧 0.07 秒）；
  - 连续对攻，他一记重挥把她甩到光团边缘、打着转；
  - 她升高后俯冲劈下，把他压下去；
  - 两人角力（`LockFrom..LockTo`，一起来回推、颤抖，中间的光在金和冷蓝之间摆）；
  - 炸开分离，再冲一次，最后她打中收尾。
  - 画面：每击武器光痕（她金色、他冷蓝，用一串重叠柔光画，`Strike`；第一次用实心月牙像香蕉，否了）提前一点挥出、正好落在出手那一刻；撞击星芒、大招时整团闪亮并朝被打的一侧鼓出（`BallPush/BallSwell`，光雾贴图也跟着推）；火星各飞各的；被打的人身体压扁一下（`FightHit`）；快速移动时留两层残影；被打时她掉羽毛（手绘花瓣 cell 5 当羽毛，暖白）、他被扯下黑雾碎片；震屏按每一击的力度。
  - 两人在光团里缩小（她 0.55、他 0.42，`FightScaleHer/Pursuer`），跑动范围放大 1.5 倍、整体抬高；剪影用整体淡入淡出（`Pose2.soft`，不用颗粒溶解，v8 的满屏噪点就是它），深色但不纯黑，最高 0.9 不透明；光团平时暗一些、出手时才亮。试过在人前面再盖一层光雾（全白看不见，撤了）。
  - 录像 `angel-intro-v8.mp4`（末尾激战 0.5 倍慢放）。羽毛如果用户愿意画一张真羽毛会更好，现在用花瓣图代替。
- **激战的根本问题（用户：“本质还是两个几何块状的东西在碰”）**：两人各是一张静止原画在平移、倾斜，没有四肢、翅膀、灯杖的动作，光效补不了。方案：用一条图生视频（`output/party-boss-20261010/fight-video/激战视频提示词.md`，起始帧 `fight_start.png` 由两张原画拼成、中灰底；视频里不要光效）。到了以后按瑟维安视频的做法抠灰底成序列图，在光团里当一张剪影翻页图播放，替换现在两张静止剪影和残影；`FightBlows` 的时间改成视频里每次打中的帧，闪光、光痕、鼓包、震屏、羽毛跟着对齐。用户的羽毛图已接上：`ArtSource/SpellProps20261007/angel_feather.png` 放进 `SpectacleCast` 第 48 格（原来没用的站姿伊莱娅让位，`cast_atlas.py` 里居中摆放、微光流动），挨打时羽毛被甩出光团外、在暗处摇摆飘落（白羽毛叠在白光上看不见）。录像 `angel-fight-feathers.mp4`。
- **天使出场第九版（10-11，激战换成用户视频）**：用户交回 `generated_video.mp4`（736×400、约 6 秒，复制为 `output/party-boss-20261010/fight-video/takes/fight-v1.mp4`）。`tools/vfx-spectacle-20260926/fight_atlas.py` 按灰底距离做软抠图（视频自带的薄雾半透明保留）、四边渐隐（巨影有时被画框切掉），64 帧打成 `Resources/SpellSpectacle20260926/SpectacleFight.png`（8×8，每格 256×128，画面占 236 宽）；`PaintSprite` 新增第 100+ 格走这张图（`paintFlipMaterial5`），`Pose2.frameAdd` 逐帧换格。光团里两张静止剪影、残影、编排关键帧、挥击光痕全部撤掉，改为这段翻页图（压暗到 0.24，透明度随闪光 0.65–0.95，中心在光团中心偏左 0.45，宽 6.8）。光团撑满整段视频：`AiBallEnd` 22.6→24.1、`AiClose` 23.6→25.1、全长 27→28.5 秒（录制行 Y3 改 870 帧）。按视频读出的打中时刻（`FightBlows`/`FightBlowAt`，视频时间与画面位置）：0.8 秒灯杖打中胸口、1.85 秒锁链抽中她、2.25 秒挥爪把她打退、3.5 秒她从上方劈下、3.65–4.95 秒扭打（`LockFrom/LockTo`）、5.05 秒挣开；闪光、光团鼓起、火星、羽毛 / 黑雾碎片、震屏都按这张表。录像 `angel-intro-v9.mp4`。改前的脚本备份在会话临时目录（`SpellSpectacle-before-fightvideo.cs`）。
- **10-11 用户再交两条**：2:51 是激战重出版（4K，但巨影中途变成蓝色冰晶魔像、后半段站开对峙），用户定“不需要高清，就用之前的激战”，光团里保持第一条（`fight-v1.mp4`）；2:51 留在 `fight-video/takes/fight-v1451.mp4`。2:23 是瑟维安的单人动作（举起铜手、巨掌冲镜头压过来、停住、收回；只有手臂动，中途画了一圈白烟），用户“也将就”，用作**第十三响**：放在 `output/sevian-video-20261009/takes-20261011/v1423.mp4`，`prepare_sevian_video_body.py charge`（4K 半尺寸读取、只留用到的帧；跳过白烟那 0.6 秒的停顿；视频在出掌时镜头推近，脚会下沉约 14%，留出了 FEET 560 / FIGURE 360 的空间，收回段放到 6 秒让推近复原）→ `Resources/CombatTempo/SevianVideo/charge.*`。接法：`thirteenth_charge` 一开始就 `ChronarchPresentation.PlayChargeWindup(2.1f)`（1.1 秒蓄力光 + 出招 1 秒到命中），随后的 `Strike` 遇到 `NextMove=="held"` 不再重置视频（`Cancel(keepVideo)`）；镇钟重砸改回横扫身体（不再共用 charge）。录制行 Y5（`enemy:clock-guard-primary:thirteenth_charge`，带 Q30 视频主角）。录像 `sevian-thirteenth-v1.mp4`。蓄力光已修（用户“碍眼”）：`prepare_sevian_video_body.py` 给每段视频的 json 写入每帧铜手位置 `hand`（青铜色最大块、按上一帧就近追踪，避开腰间皮书），三段（strike / sign / charge）都重新生成；`SevianVideoBody.HandPoint` 换算成屏幕上的位置；第十三响的蓄力丝带和点光（`MainlineStateRound2.Hand`、`ChronarchPresentation.VideoHand`）以及所有招式的起手聚光（`SpellSpectacle.HandOf`）都跟着视频里的铜手。录像 `sevian-thirteenth-v2.mp4`。用户问待机和受击：核对过交来的五条（10-10 的 11:56 推掌、12:03 横扫、12:04 与旧普攻相同、12:46 签名，10-11 的 2:23 出掌），都不是待机或受击，仍缺。
- **10-11 接入实战（Unity 侧）**：`party-show` / `angel-intro` 改为先记下请求（`BattlePrototype.RequestParty/RequestAngelIntro`，`Update` 里 `ServePartyRequests`），等主角和瑟维安都装好再执行，队友先就位、天使出场后播；`party-clear` 同时取消未播的出场。新指令 `angel-intro-skip`（App 的“跳过”）：`SpellSpectacle20260926.SkipAngelIntro` 让本次演出的所有贴图、光、压暗、震屏当帧消失（`angelIntroEpoch`）。录制行 Y6（队友 + 天使出场）、Y7（第 10 秒跳过）验证过。App 侧（Swift：开打发指令、队友动作、血条、封印标记、第 30 关演出台词与跳过、演出后再弹祝福）另由助手接入中。
