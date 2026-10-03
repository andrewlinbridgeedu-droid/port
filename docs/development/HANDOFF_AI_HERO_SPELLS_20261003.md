# 交接：视频主角 + 法术往前打 + 塔小怪潮 · 2026-10-03（中午写，下午 169.47 装机后更新）

接在 [法术形式交接](HANDOFF_SPELL_FORMS_20261003.md) 之后。那份是全天的流水，本份只写**现在在哪、下一步做什么**。

## 现在在哪（先读这一节）

- **分支**：`claude/ai-hero-integration-20261003`（工作树 `/Volumes/andrew's SSD/Mistport-worktrees/hero-v4-device`）。
- **最新代码提交 `0ebbbe6`**：放大命中范围、给普攻加拖尾。
  - 用户在手机上看 169.45 后说：“法术效果似乎有点范围太小，普攻几乎旧没效果”。
  - 上一个会话写这份交接时 `0ebbbe6` 其实还没推送、交接本身也没提交；下午接手的会话已一并提交推送。
- **169.46 模拟器复看（下午接手的会话做的，模拟器逐帧，不是真机，也不是用户认可）**：图在 [`spell-forms-20261003/`](spell-forms-20261003/) 的 `sim-169.46-*.jpg`。
  - 伪证：红蜡带火花从主角飞到敌人，砸下后红色碎片外溅，约 1.5 个敌人大，三招里最收（“盖章”）。开场第一发仍被敌人紫雾遮掉一部分。
  - 双影：两个视频分身冲出，命中后紫烟约占屏宽 55%。
  - 荒谬：彩色尾迹从主角手边飞出，落地彩虹扇面约占屏宽 60%。
  - 错步（Q4）：残影冲出，交叉斜刃和碎光罩住猎犬，约占屏宽一半。
  - 普攻：紫色塔罗牌带一道金线飞到敌人，落地一道粉金斜划，约两个猎犬高，每次都看得见。
  - 判断：都比 169.45 大一截，收在敌人周围，主角那半边干净，没有回到“满屏开花”。没有再调，直接出真机包。
  - 原来那段 `big-q4.mp4` 只录了 22 秒，战斗 20.7 秒才开始，普攻落地没录到；补录了 48 秒的 `big-q4-long.mp4`。
  - 主角脚边偶尔出现一块红色楔形地面标记，是节奏样板原有的敌方蓄力预警（`CombatTempoVFX.Telegraph`），不是这次的改动。
- **手机（iPhone 13）**：**169.47**（提交 `0ebbbe6`，13:25 装），替换本线的 169.45。
  - 签名校验通过；Preferences 装前 264 份、装后 264 份、静音预览启动后 264 份，全部逐字节相同。
  - 这次手机没锁屏：带 `-MistportCityMute YES --tempo-device-review=hero --tempo-speed=1 --tempo-preview-only` 启动，25 秒后进程仍在，随后终止。
  - 只证明装上了、能启动；没有在手机上看画面，也没有用户认可。
  - 记录在 SSD 的 `Mistport-archives/releases/Build169.47-bigger-landings/`。本线更早的装机记录：`Build169.36-spell-forms`、`Build169.41-tower-minions`、`Build169.43-ai-hero-integration`、`Build169.45-fix-all`。
- **主角**：用户定了用视频展示动作，不再做 3D。视频主角（`AIHeroAnimatedBody`）来自 Codex 分支 `codex/combat-tempo-samples-20261001`，已合并进来，并且**在所有战斗里都显示**（`CombatTempoPresentation.HeroOnly`）。

## 下一步（按顺序）

1. **等用户在手机上看 169.47**：命中大小和普攻是否合适。
   - 用户最早的反感是“满屏开花”，上一轮是“范围太小”，要卡在两者之间。
   - 还要调的话，改 `SpellSpectacle20260926.FormImpact` 里的命中尺度（现在普攻 0.55、其他 0.8）和 `LaunchShots` 的 `Form.Flick`。
2. 用户看过后再做：
   - 主线有些关卡给旧主角模型配过专门演出（Q1 教学、Q2 错步镜头等）。现在模型隐藏、换成视频主角，这些演出可能看不到，要逐关看。
   - 小怪潮：小怪多半走不到站位就被群体技能清掉；五种小怪没有行走动画，行走是待机动作加起伏。
   - 其他六张牌和敌人的法术还是原来的“炸开”形式。
   - 封印物稿评审（`claude/skill-relic-design-20261002`，`72d6159`）列的四个规则问题，以及规则第一批。

## 这一天做成了什么（细节在旧交接）

| 内容 | 提交 | 状态 |
|---|---|---|
| 法术往前打：伪证（投掷）、双影（两个主角分身追击）、荒谬（道具落雨）；根因是起点在 1 米高主角的头顶上方 | `e4801b4` | 已上手机 |
| 塔小怪潮：每波 4–6 只小怪走进来；群体技能只在塔里放开（错步 3 个，荒谬主目标全额加另外 2 个半伤） | `6f5232b` | 已上手机 |
| 错步改成突进穿行：视频残影贴地冲刺、镜面鞋印、拐弯连穿、交叉斜刃 | `430e0b8` | 已上手机 |
| 合并视频主角；有新形式的牌不再叠播旧剧场 | `0d89444` | 已上手机 |
| 普攻去掉全屏着色器；鞋印放大；视频主角上所有战斗 | `64a0efd` | 169.45 已上手机 |
| 放大命中、普攻加拖尾 | `0ebbbe6` | 模拟器 169.46 已看；169.47 已上手机，用户未看 |
| 静音启动不再有声音（音乐、Unity 音效都关） | `e4801b4` | 已上手机 |

## 怎么复现

**构建**（工作树里，会先做 Unity 导出）：

```bash
MISTPORT_SIM_DEVICE="iPhone 17 Pro Max" MISTPORT_BUILD_OUT="/Volumes/andrew's SSD/Mistport-build-cache/hero-v4-sim-20261002" sh scripts/build_hero_v4.sh simulator 169.48
```

```bash
MISTPORT_BUILD_OUT="/Volumes/andrew's SSD/Mistport-build-cache/hero-v4-device-20261001" sh scripts/build_hero_v4.sh device 169.49
```

- 号码只是示例（169.47 已用）：出包前先用 `xcrun devicectl device info apps` 查手机上的版本，再看 `Mistport-archives/releases/`，取没用过的号。
- 构建脚本出错时，`| tail` 会吞掉错误码；一定要在输出里看到 `BUILT …` 才继续录像或装机。
- Unity 导入会给视频主角图集的 `.meta` 补行尾空格，构建后用 `git checkout -- UnityBattleSource/Assets/Resources/CombatTempo/AIHero/` 还原，不要提交。

**模拟器录像**：用 iPhone 17 Pro Max（`E64100C9-43DA-4B8C-996A-2D953A13219C`）。

- 带 `-MistportCityMute YES` 静音启动，录完立刻终止应用并关机；用户不想听到声音。
- 样板要准备约 20–28 秒才开打，录像至少录 45 秒，否则普攻落地录不到。
- 录像时间 ≈ 日志里的 Unity 时间 + 4.3～4.9 秒（每次启动不同），用第一个 `SPELLFORM impact` 对齐。
- 样板参数：`--tempo-device-review=hero`（主角样板）、`q4`（发条猎犬）、`pack`（塔第 2 层小怪潮）、`pack8`（塔第 72 层满编八人）。
- 录屏先写到 `/private/tmp` 再复制到 SSD。
- 抽帧：`scripts/video_contact_sheet.swift`；走廊裁切 `330,1150,660,950`（塔），Q4 用 `260,1000,800,1300`。
- 调试构建会输出 `SPELLFORM`（法术坐标与命中时刻）和 `MINIONWALK`（小怪行走）日志，用 `simctl launch --console-pty` 抓。

**装机和存档核对**：

1. `xcrun devicectl device copy from … --source Library/Preferences` 拷装前快照；
2. 安装；
3. 再拷一次，逐文件比对 SHA-256；
4. 如果手机解锁，就带 `-MistportCityMute YES --tempo-device-review=hero --tempo-preview-only` 启动预览，再拷一次比对，然后终止进程。

上午的会话手机三次都锁屏，启动检查都没做成；169.47 装机时手机解锁，启动检查做成了。连接偶尔断，`copy from` 和 `install` 要重试。

## 环境坑

- **Unity 授权和主机名绑定。**编辑器报 “No valid Unity Editor license” 时，先看 `~/Library/Logs/Unity/Unity.Licensing.Client.log` 里的 `EnvironmentHostname`。主机名已用 `scutil` 固定为 `AndrewLins-AI-Assistant`；如果又出问题，要用户在 Unity Hub → 设置 → 许可证点 Refresh。
- **仓库只在 SSD 上**（`/Volumes/andrew's SSD/Downloads/mindstone-game`）。内置盘那份 10 月 3 日凌晨被删，工作树指针已经修好；提交后尽快推送。
- **手机是共用的**：Claude 和 Codex 的会话都会装机，装之前一定查清手机上是哪一版、是哪条线。本会话就因为没核对内容，用 3D 主角版顶掉过用户的视频主角版。

## 不要做

- 不要从 `claude/hero-v4-device-20261001`（3D 主角线）出包装机。
- 不要把模拟器画面、录像或作者观察记成用户认可。
- 不要覆盖真实存档；不要删除 SSD 上的链接和归档。
- 主线的群体技能目标数不要动（Q2 分裂战的教学依赖“错步打 2 个”），除非用户点头。
