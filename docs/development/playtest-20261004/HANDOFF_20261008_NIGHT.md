# 雾港法术命中：命中手感修正 + 程序化 2D 手绘笔触 · 交接文档（2026-10-08 晚）

接续 `HANDOFF_20261008.md`（凌晨）和另一会话的 `HANDOFF_20261008_PM.md`（下午：猎犬手绘爪痕、错步穿行卡牌碎裂）。本段覆盖 10-08 中午到晚上：命中手感八条审查 bug 修正、摇晃幅度定稿、震动修正、爪痕镶边试验（已关）、**新方向：在 Unity 里程序化画 2D 手绘笔触（`Ink2D`）**，以及用户最新给的参考 `yao_vs_ting`。逐条过程在同目录 `log.md` 第十二轮末尾。构建、装机、存档通用做法见 `HANDOFF_20261007.md` §5，本文件只写变化。

---

## 1. 现在的状态（一屏看完）

| 项 | 状态 |
|---|---|
| 代码 | 全部**未提交**，worktree `/Volumes/andrew's SSD/Mistport-worktrees/hero-v4-device`（分支 `claude/ai-hero-integration-20261003`，HEAD `4ed6d5a`）。 |
| 模拟器 | iPhone 17 Pro Max（`E64100C9-43DA-4B8C-996A-2D953A13219C`）装 **170.28**（含 `Ink2D` 第 4/5 版：猎犬爪痕新月 + 普攻圆球）。测试存档已恢复 Q14 备份并逐字节核对，App 关闭。 |
| 源码比 170.28 新 | `Ink2D` 已改成第 9 版（照 `yao_vs_ting` 配方重写），**有运行时错误、用户没看过**（§4.4）。 |
| 真机 | 没出设备包。震动修正只能真机验。 |
| 用户已认可（本段） | ① 猎犬爪痕（用户手绘 PClaw 版，170.22 起）；② **命中摇晃**（170.27：主角下压/横摆/挤压，敌人后弹/横摆）——原话"这个爪子可以，摇晃也可以"；③ `Ink2D` 的**形状**方向——"好，形状可以，做画工"。 |
| 用户未认可 | `Ink2D` 画工：ink7 "有进步了，但还没达到可用"；ink8 发了没回；用户随后给 `yao_vs_ting` 参考："这个比你的好，但还需要更精细"。 |
| 用户的工作方式（本段明确） | "我不管那么多吧，我要类似这样的效果""我要怎么做吧，我不懂"——**不要让用户出逐帧图或做技术选择**，直接做出效果给他看；"需要平面图时还是可以叫我"。 |

---

## 2. 用户这段的原话（按时间）

1. "好，开始工作"（接上午的分析）。
2. "这个爪子可以，摇晃也可以"（170.27 近景）。
3. "按你建议"（先出晶片/陨石/闪电单图、装机待说）——随后我自己撤回了"出单图"建议（单图仍是静态贴图）。
4. "现在又用回贴图了？之前不是说不好吗"（对爪痕三阶镶边试验）。
5. "我不管那么多吧，我要类似这样的效果"（再次贴 2XKO 三张图）；"我要怎么做吧，我不懂"。
6. "这样就对了，但需要我时还是可以叫我，如果你需要平面图"（对"我直接在 Unity 里画、不等你出图"）。
7. "这是终稿？"（对 ink4/ink5）→ 我答不是，列了三点差距。
8. "好，形状可以，做画工"。
9. "有进步了，但还没达到可用"（ink7）。
10. 贴 `yao_vs_ting` 十二格截图 + `@/Users/andrewlin/Downloads/yao_vs_ting_fight.zip`："这个有参考价值吗，这个比你的好，但还需要更精细"。
11. "写handoff"。

---

## 3. 命中手感（已完成，摇晃已认可）

### 3.1 审查出的 8 条 bug，修了 7 条（原件 `worktree/backups/hit-feel-fix-20261008/original/`）

| # | 问题 | 修法 | 文件 |
|---|---|---|---|
| 1 高 | 震动淡出曲线 `hapticIntensityControl` 是 pattern 全局乘子，把余震/追击第二下/终结第三下一起压掉 | rumble 单独一个 pattern + player，`player` 改为 `players` 数组 | `mistport-ios/Mistport/CombatHaptics.swift` |
| 2 低 | `hurtLight` 优先级 74 > 终结 70 / 重击 65，轻伤会盖掉终结技震动 | 改 60 | `MistportCombatCore/.../CombatHapticsPolicy.swift` |
| 3 中 | `HitShake` 与 `BountyBodyRound2`、`CombatTempoAnimatedBody.OnAnimatorMove` 同写 `localPosition`，偏移被烙进基准（悬赏敌人浮空、节奏敌人后滑） | 新增 `HitShakeRestore20261007`（执行序 −20000）帧首撤掉自己的偏移，`HitShake`（32000）帧尾再叠 | `HitShake20261007.cs`、新 `HitShakeRestore20261007.cs(+meta)` |
| 4 中 | 雾灵/翠绿亡魂的 `handle.Model` 是隐藏的旧模型 | 改取 `EarlyEnemyIdlePresence.VisibleActor`，非激活目标跳过 | `BattlePrototype.PresentEnemyImpact` |
| 5 低 | 减弱动态 ×.35 乘了两次 | `PlayerImpactFeedback.LastStrengthUnreduced`，只在 `ConfirmedHit` 折减 | `PlayerImpactFeedback20260925.cs`、`BattlePrototype.cs` |
| 6 低 | 致命包用过期力度多晃一下 | `LastWasDefeat` 时不调 `PlayerHit` | 同上 |
| 7 低 | 连击时 `Dim` 重触发从 0 爬坡，背景先亮一两帧 | 仍在压暗时从保持段起点续 | `SpellSpectacle20260926.cs` `Dim.Trigger` |
| 8 低 | `ReducedMotion` 只随主角受击包下发 | **未改**（需原生单独下发） | — |

MistportCombatCore `swift test` 583 项改前改后全过；`CombatHaptics.swift` 用 iPhoneSimulator SDK `-typecheck` 通过；之后的完整构建也都过了。

### 3.2 摇晃幅度（170.27，用户认可）

170.24 看不出主角摇晃。加临时诊断日志（170.25/170.26，`xcrun simctl launch --console` 抓 iOS 包里的 `Debug.Log`）证实链路通、强度 0.94，但位移只有身高 3%，且命中帧模拟器只有 ~15 fps，17 Hz 抖动采样后每帧同相位 = 静止。改为：
- 主角 `AIHeroAnimatedBody`：立即下压 9% 身高 + 9 Hz 阻尼横摆 6% + 前 0.1 s 横 +14% / 纵 −11% 挤压（每帧先复位 `homeScale` 再挤压）+ 滚动 ±9°。
- 敌人 `HitShake20261007`：立即后弹 9% + 9 Hz 横摆 6% + 6 Hz 上下 2%。
- 诊断日志已全部删掉，编译无错。教训已写进技能 `references/lessons.md`。
- 近景证据 `shots/r12-170.27-q3-hero-hit-zoom.jpg`。

压暗：Q3 猎犬是 Light 档，`darken = 0`，Q3 里不触发；重击身份的压暗**没有在模拟器核对过**。

---

## 4. 程序化 2D 手绘笔触 `Ink2D`（主线，未达标）

### 4.1 为什么走这条路

- 上午的分析（13 个 agent，`worktree/output/ref-handdrawn-vfx-20261008/analysis-wf_0f7701fa/`）：参考的"流动"来自每帧重画形状；单张贴图 + 噪声扰动/分色永远是"贴图在动"。
- 原计划请用户按 `docs/development/SPELL_FLIPBOOK_ART_REQUEST_20261008.md`（主仓库）出 12 帧序列图——**用户不想做**（§2 第 5、6 条），改为在 Unity 里用代码画多边形笔触。该需求文档和 `tools/vfx-handdrawn-20261008/pack_sheet.py`（切格 + 相邻帧 IoU/质心检查）保留备用。
- 爪痕三阶镶边试验（`SpectacleProp.shader` 的 uv4.z rim 分支、`Props.Item.rim`）：用户指出仍是贴图，**已关**（`RimBands = 0f`），着色器分支还在。

### 4.2 实现位置

- `SpellSpectacle20260926.cs`：`sealed class Ink2D`（在 `EffekseerBurst` 前）；开关 `const bool InkStrokes = true`；`inkMaterial` 在 `Load()` 里建。
- 接入：`ClawHit`（`early-hound`）→ `Ink2D "claw"`，尺寸 `.33 × 可视半高 × tier`；`FormImpact` 里新增 `InkHit`（只对 `paper` = 主角普攻）→ `Ink2D "burst"`，`.18 × 可视半高`。`InkStrokes = false` 恢复原来的 `PaintedClaw` 和普攻落点。
- 着色器 `Resources/SpellSpectacle20260926/SpectacleInk20261008.shader(+meta)`：顶点 uv.x = 到轮廓的距离（0 边 → 1 芯线）切硬边色阶；uv.y 模式（0 色阶 / 1 平涂 / 2 软圆 / 3 加法）；uv.z 沿笔触坐标（亮纹）。队列 Transparent+72，ZTest Always。

### 4.3 迭代记录（编辑器正式录制 `record.sh --only=M05,H00`，输出 `worktree/output/hit-feel-20261008/ink1…ink9`）

| 版 | 内容 | 结果 |
|---|---|---|
| ink1–2 | 新月/泪滴/星/点/墨迹，三阶色，每 1/12 s 换轮廓 | 空网格 → MinMaxAABB；`Pow(sin(π))` → NaN |
| ink3 | 修 bug | 爪痕太大、黑墨成黑板、圆盘像靶心 |
| ink4 | 爪痕缩 2/3、暗逗号、泪滴圆盘 | `shots/r12-ink-claw-v4.jpg`；圆盘像地图图钉 |
| ink5 | 圆球 + 肩部旋涡 | `shots/r12-ink-burst-v5.jpg`；**170.28 就是这版**；用户："形状可以，做画工" |
| ink6 | 逐点抖动、四色边、亮纹、爆发帧柔光+放射星芒+速度线、尖端分叉 | 抖成锯齿、星芒太长 |
| ink7 | 收敛抖动/星芒 | `shots/r12-ink7-painterly.jpg`；用户："有进步了，但还没达到可用" |
| ink8 | 去抖动改书法式（skew/hook）、主体渐变、外侧青边光、笔触光晕+拖影、按拍保持表 | `shots/r12-ink8-painterly.jpg`，已发，**用户没回就贴了新参考** |
| ink9 | 照 `yao_vs_ting` 重写（§4.5） | **没发用户，有问题**（§4.4） |

### 4.4 ink9 的已知问题（接手先修）

1. **运行时错误**：M05 录制 `ROUND2_FAIL M05 no runtime errors`，`Converting invalid MinMaxAABB` 来自 `Ink2D.LateUpdate`（`SpellSpectacle20260926.cs:852` 附近 `SetVertices`）。原因：新 `Crescent` 里 `Mathf.Pow(Mathf.Sin(u * Mathf.PI), .75f)`（第 970 行附近）在 u=1 时 sin 略小于 0 → NaN。ink2 修过一次，重写时丢了——改回 `Mathf.Max(0f, Mathf.Sin(...))`。
2. **违反禁用几何**：`Ring()` 画的是完整等距圆环（普攻爆发的两道环、`ImpactStar` 的扩散环），AGENTS.md 明确禁用。参考里有环，但我们不能用——改成不闭合的弧段或去掉。
3. **烟**：`SmokeDisc` 三层平涂圆在白大理石上读成盖在主角身上的灰圆片，难看；要么去掉，要么改成在主角身后（或小而淡）。
4. **爪痕不退场**：`fade` 从 0.45 s 才开始、0.95 s 结束，抽帧里 0.6 s 仍是满的三道大新月；参考的主体 0.2–0.3 s 就该开始消退。另外"从尾端烧掉"（`eat`）效果不明显。
5. 普攻的雷电 `Bolt` 是给霆（雷系）的，主角普攻用雷电不对身份；可保留碎片/闪光，雷电去掉或换。

### 4.5 `yao_vs_ting` 参考（用户 10-08 晚给的，"比你的好，但还需要更精细"）

- 原件 `/Users/andrewlin/Downloads/yao_vs_ting_fight.zip`（40KB），已解压到 `worktree/output/ref-handdrawn-vfx-20261008/yao_vs_ting/fight/`：Python + skia-python 逐帧画矢量的 30 秒打斗短片（曜 火 vs 霆 雷），`vfx.py` 图元、`effects.py` 全部法术、`scene.py` 分镜与后期、`README.md` 说明。**没跑过**（本机缺 skia-python/opencv/ffmpeg，装要联网先问用户）。
- 值得照搬的配方（ink9 已搬了一部分）：
  - **四阶赛璐璐色板**：`FIRE = #A80F2A / #FF4D1A / #FFAA33 / #FFF3CF`，`STORM = #3D1FC8 / #9B45FF / #52E6FF / #F3FFFF`；外圈是深色饱和带——这是在亮背景上也显眼的关键。`draw_banded` 用同一形状按 scale 缩放叠四层（我们用"到轮廓距离"切阶，等价）。
  - **`ImpactStar`**：12 根长短不一的锥形放射刺 + 白色内刺 + 八角 sparkle + 扩散环 + 辉光，0.22 s，且按真实时间播放（顿帧时也在动）。
  - **`flame_path`**：沿 fbm 抖动脊线的泪滴火舌；**`blob_path`**：fbm 扰动圆；**`lightning`**：中点位移 + 分叉，四层描边（宽紫模糊 → 紫 → 青 → 白）。
  - **`sparkle`**：8 点（腰细 .11、竖向短 .72）+ 白色半尺寸拷贝 + 辉光，全部加法混合。
  - 粒子是闭式抛物线（`Burst`/`Emitter`）：streak/dot/sparkle/shard/smoke 五种。
  - **舞台**（我们还没做）：命中顿帧 `HITSTOPS`、白闪 `FLASHES`、黑白冲击帧 `IMPACT_FRAMES`、整屏多半径高斯辉光后期 `post()`（0.45/0.42/0.38 三档叠加）、色差、暗角、必杀切入画面。**"亮"主要靠这个后期辉光**；项目是内置管线、没有后期，要做得自己写一个相机级的轻量 bloom（降采样 + 模糊 + 加回），手机性能要评估。
- 用户说它"还需要更精细"：它本身也偏简单（圆盘、整环、粗粒子），目标是"它的配方 + 2XKO 概念图的造型精度"。

### 4.6 建议的下一步（按顺序）

1. 修 §4.4 第 1 条 NaN，去掉/改掉完整圆环和灰烟片，爪痕主体 0.25 s 起退场，普攻去雷电；重录 M05/H00，自己逐格看过再发用户（用 `peaks` 找峰值、10–12 fps 抽 8 格、裁到目标附近，脚本见本段 log 里的命令，工具在 `tools/vfx-spectacle-20260926/review-20261007/`，编译到 scratchpad 用）。
2. 用户认可画工后，再试**命中顿帧 + 白闪 + 轻量 bloom**（先只在编辑器录制里对比有/无），这是参考"亮"和"有力"的大头。
3. 画工和舞台都认可后，按同一套 `Ink2D` 铺：主角其余 9 张牌 → 前几关敌人 → 塔/通缉；每批录完给用户看一次。每个身份要有自己的形状语言（AGENTS.md：过于相似必须实际修改）。
4. 不要再请用户出逐帧序列图；只在确实需要"平面图"（实物/角色类单图）时叫他，一次一段中文 prompt。

---

## 5. 构建、模拟器、存档

| 构建 | 内容 | 结果 |
|---|---|---|
| 170.24 | 命中手感 7 条修正 | 安全检查 M05/M06/M07/H01/B01/B02 116 项全过；新鲜度检查过；Q3 实录看不出主角摇晃 |
| 170.25 / 170.26 | 临时诊断日志 | 证实链路通、幅度太小（诊断已删） |
| 170.27 | 摇晃幅度定稿 | **用户认可摇晃** |
| 170.28 | `Ink2D` ink5（爪痕 v4 + 普攻 v5） | 新鲜度检查过；Q3 实录 `worktree/output/hit-feel-20261008/sim-170.28-q3-sim-raw.mp4`、近景 `sim-170.28-ink.jpg`（爪痕位置尺寸对，普攻球偏大 → 已改 .18） |

- 完整构建：`cd worktree && MISTPORT_SIM_DEVICE="iPhone 17 Pro Max" sh scripts/build_hero_v4.sh simulator 170.29`（下一个号 170.29；出设备包前先查手机和 `/Volumes/andrew's SSD/Mistport-archives/releases/`）。
- 每次看完模拟器：terminate → 拷 `worktree/output/playtest-save-backups/q14-cleared-20261005/*.plist` 进容器 `Library/Preferences/` → `cmp` 逐字节核对。本段每次都做了；跑 Q3 前的临时状态另存过 `temp-after-q3-170.17-20261008-0255/`、`temp-after-q3-170.24-20261008-1910/`。
- `xcrun simctl launch --console <udid> com.yourcompany.mistport -MistportCityMute YES --developer-tools > log` 可以抓 Unity 的 `Debug.Log`（`log show` 抓不到）；`--stdout/--stderr` 参数在这台机器上不生效。
- 录屏：`run_in_background` + `exec xcrun simctl io <udid> recordVideo ...`，记 `$$` 为 pid，之后 `kill -INT`；先写 scratchpad 再拷 SSD。
- 坐标（设备点 440×956）：标题"测试"(313,90)；关卡列表第 3 关 (204,335)；"跳过对白"(91,274)；"开始战斗"(219,440)。打赢后下次启动会先出"已恢复战后奖励"页，恢复存档后重启即可。
- 已知 P2 仍在：Q3 点"开始战斗"后常要十几秒才开打。

---

## 6. 未提交改动（本段新增/改动，worktree 内）

| 状态 | 文件 | 说明 |
|---|---|---|
| M | `Scripts/SpellSpectacle20260926.cs` | `Ink2D`、`InkHit`、`InkStrokes`、`inkMaterial`、`RimBands`、`Props.Item.rim`、`Dim.Trigger` 修正 |
| M | `Scripts/HitShake20261007.cs` | 早序还原、跳过非激活目标、新幅度 |
| ?? | `Scripts/HitShakeRestore20261007.cs(+meta)` | 新（guid `490e747e…`） |
| M | `Scripts/AIHeroAnimatedBody.cs` | 新摇晃（`homeScale`） |
| M | `Scripts/BattlePrototype.cs` | `PresentPlayerImpact`（defeat/unreduced）、`PresentEnemyImpact`（VisibleActor） |
| M | `Scripts/PlayerImpactFeedback20260925.cs` | `LastStrengthUnreduced`、`LastWasDefeat` |
| M | `Scripts/CombatTempoPresentation.cs` | 上一段的 `PlayerHit(float)`（本段诊断已删，回到原样） |
| M | `Resources/SpellSpectacle20260926/SpectacleProp.shader` | rim 分支（现未启用） |
| ?? | `Resources/SpellSpectacle20260926/SpectacleInk20261008.shader(+meta)` | 新 |
| M | `mistport-ios/Mistport/CombatHaptics.swift`、`MistportCombatCore/.../CombatHapticsPolicy.swift` | 震动修正 |
| M | `.claude/skills/mistport-spell-spectacle/references/lessons.md` | 加"模拟器 15fps 看不见高频抖动"一条 |
| M | `UnityBattleSource/ProjectSettings/ProjectSettings.asset` | **不是我手改的**，应是 Unity 批处理编译/录制时写回；提交前看一眼 diff 决定要不要 |
| ?? | `tools/vfx-handdrawn-20261008/pack_sheet.py` | 序列图切格检查工具（备用） |
| ?? | `docs/development/SPELL_SPECTACLE_20261007.md` | 补了 §6（手绘图、命中手感、验证）§7（逐帧方向） |

主仓库：`docs/development/SPELL_FLIPBOOK_ART_REQUEST_20261008.md`（备用）、`docs/development/playtest-20261004/`（整个目录仍未提交，含本文件和 `shots/r12-*`）。

上一份交接列的未提交改动和另一会话（PM）的改动都还在；30 个 `AIHero/**/*.png.meta` 不要碰。提交/推送/合 main 先问用户；`edf41cb` 不要自行合。

---

## 7. 其它

- `record.sh` 发现 `/tmp/mistport-vfx-encode/venv` 被清，会自动 `pip install imageio-ffmpeg numpy pillow`（约 30MB，联网）。本段第一次跑安全检查时触发了，事后已告诉用户。现在 venv 在，录像模式可用。
- 参考素材都在 `worktree/output/ref-handdrawn-vfx-20261008/`：`gifs/`（用户同意后下载的 50 张公众号动图）、`sheets/`（逐帧表 + `info.json`）、`timing.json`（33 个一次性爆发：涨开中位 0.18 s、衰到 25% 中位 0.36 s）、`analysis-wf_0f7701fa/`（13 个 agent 的分析原文）、`yao_vs_ting/`。
- 长期记忆已加 `handdrawn-flipbook-vfx-reference`（2XKO/Tolmachov 方向）。可再补一条：用户不想做技术选择、要直接看效果。
- 内置盘：scratchpad 已清到 ~90MB；工作文件全在 SSD。

---

## 8. 用户的长期要求（接手必须遵守）

- 全程中文；直接给推荐并执行，**不要让用户做技术选择或出逐帧图**；需要单张平面图时才叫他，一次一段中文 prompt。
- 视觉问题自己在模拟器/编辑器录制里看，逐格看过再发；只有用户说"装机"才上真机；模拟器和真机都静音启动。
- 不覆盖玩家真实存档；模拟器测试存档每次看完恢复 Q14 备份并逐字节核对。
- 改了 Unity 运行资源必须重新导出、通过新鲜度检查再构建宿主。
- 录像、测试通过、构建成功都不等于用户视觉认可；用户没认可的视觉稿不能记为合格。
- 法术工作走 `mistport-spell-spectacle` 技能；**禁用完整等距圆环**、直边框、规则光板、平行光条。用户已否决：条带主体、整片椭圆光膜、PIL 剪贴画、程序画的平面逐帧图（PIL 版）、Blender 粗模、Meshy 3D 凤凰、静态贴图感、纸片晶片、单张贴图上做分色。用户要的：2XKO 概念图那种 2D 手绘卡通特效 + `yao_vs_ting` 的配方，但更精细；很亮。
- 下载文件、提交、推送、合入 main、永久删除前都先问用户。不要删除/重建/覆盖 SSD 符号链接。内置盘小，工作文件放 SSD。
