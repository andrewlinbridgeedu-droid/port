# AI 主角动作接入 · 2026-10-02

用户在查看全身动作页后说“好啊，接入游戏”。本轮按这条授权接入原有 Q4、D01、B01 样板，三套服装各五段。Q3 与其他战斗保持原入口；场景原画、战斗机位、Swift 规则、费用与存档格式不改。图稿选用授权不代表游戏内视觉认可，PR #41 仍待复看。

[游戏内动作预览](review.html)来自 Unity Mac 运行捕获，不是 AI 原片套背景，也不是 iPhone 录像。近景使用检查机位，正式机位另列三张图。没有安装手机或读取、改写 Preferences。

## 接入方式

- `AIHeroAnimatedBody` 在原主角脚底位置放置透明动画面片，采用原画颜色，不加 PBR 镜面、金属或额外灰色明暗层。身体的迈步、转腰、投掷与衣摆全部来自用户看过的 AI 视频。
- App 已有的 `hero-outfit:` 消息从本场 loadout 选择夜行／星辉／狂欢。换装保留施法时钟，只更换对应服装图集；每套动作可以不同。
- 每条视频抽取 48 帧，每帧 512×640，八列六行组成 4096×3840 RGBA 图集。这是运行纹理尺寸，不是原片为 4K，也没有补出原片不存在的细节。原始 MP4 与三张 2D 原画保留。
- 背景抠除兼顾手臂、双腿围住的灰色空隙；缩放与脚底锚点按每条初始姿势固定，不逐帧自动居中，以保留全身位移。`atlas-build.json` 记录来源哈希与出手时间。
- 施法前半段压到现有命中时点，后半段收招加速，末尾 0.18 秒过渡到原站姿。动画使用战斗时钟，支持 ×2 与暂停，不触发伤害回执。原片没有完全回位的动作仍可能看出短暂姿势过渡，尚未由用户在游戏中认可。
- iOS 使用 ASTC 6×6、无 mipmap，当前服装的五条图集常驻，卸载旧服装。引用计数保护同一帧销毁旧角色、创建新角色时仍在用的纹理。桌面使用 BC7。真机内存、帧率与边缘观感尚未测量。
- 旧 Blender v1–v4 与源素材保留。历史检查可用 `--hero-v1` 至 `--hero-v4` 指定旧路径；正常样板默认使用此次 AI 动作。

| 动作 | 接到的技能 ID |
| --- | --- |
| 斜步切出 | 普攻、`fool_skill_01` |
| 抬手敕令 | `fool_skill_02`、`fool_skill_08` |
| 踏步过肩投掷 | `fool_skill_04`、`fool_skill_07`、`fool_skill_10` |
| 落掌盖印 | `fool_skill_05`、`fool_skill_09` |
| 侧跨转腰甩投 | `fool_skill_06` |

接触时间复用 `FoolSkillChoreography.ExpectedContact` 和样板原有时间，没有另写规则数值。遗留 `fool_skill_03` 不在现行装备技能中，本轮不更改其兼容路径。

## 验证与复跑

- 图集转换：SSD 媒体 Python 环境执行 `tools/animation/prepare_ai_hero_runtime.py`，依赖 Pillow、NumPy、SciPy、imageio-ffmpeg。
- Unity Mac：执行 `AIHeroImport.BuildPreview`（首次导入），或后续 `BuildRuntimePreview.BuildMacPlayer`；通过 `-previewPlayerOutput` 指定 SSD 输出。
- 实际运行：设置 `MISTPORT_AI_HERO_CAPTURE` 为 SSD 证据目录，运行 Mac player 的 `--verify-ai-hero`。该检查静音运行并在完成后退出，不留后台音乐。记录每套五段各 48 帧、正式机位、换装、暂停与切场；三套衣装 × 两档速度 × 七个生产攻击入口，核对各一次命中与完成回执。
- 整理预览：`tools/animation/package_ai_hero_runtime.py <证据目录>`，要求先有 `passed.txt`，打包后逐条完整解码。运行记录见 `runtime-verification.txt`，媒体参数见 `runtime-media.json`。
- iOS 导出必须显式指定本 worktree 的 `MISTPORT_UNITY_IOS_OUTPUT`，随后跑 `scripts/check_unity_export_freshness.sh`。宿主 DerivedData、构建包均在 SSD，编号低于 170；本轮目标 169.27，最终结果见 `ios-build.json`。

尚未验证：真实 iPhone 上的显示、帧率／内存、长时间连续战斗，原生技能按钮与新身体的整场观感，以及用户对最终回位过渡的认可。没有将此轮接入铺到其他战斗。
