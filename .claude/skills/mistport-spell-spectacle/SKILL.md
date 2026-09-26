---
name: mistport-spell-spectacle
description: 雾港（mindstone-game / Mistport）Unity 战斗里"命中华彩层"SpellSpectacle20260926 的设计、修改、录制和复看流程。用户要求让法术更绚丽、更炸裂、更丰富，说某些法术雷同、缺乏创意，要加旋风、剑气、剑雨、流星、地刺、龙、莲花一类名招，给新敌人或新通缉头目配命中特效，调某招颜色/材质/形状，或者要录法术对比视频、看全招式网格时，都要使用本 skill，即使用户没提 SpellSpectacle 这个名字（英文说法如 spell VFX / hit effect / make spells flashier / signature move 也适用）。不用于原生 Swift 伤害结算、普攻身体动作时长或 iOS 构建本身。
---

# 雾港命中华彩层（SpellSpectacle20260926）

这是一层**只做表现**的命中特效：施放时由正式入口登记，只在已有的 `UnityBattleBridge.ReportCombatContact` 回执那一刻生成，不结算伤害、不改 contact 时刻、冷却、目标或战斗时钟。所有正式法术（主角、主线、塔、通缉）都挂在这一层上。

开始前先读：
- 项目根 `AGENTS.md`：存档、外置 SSD 符号链接、证据分级等长期边界。
- 通用法术原则 `~/.codex/skills/game-spell-impact/SKILL.md` 及其 `references/mindstone.md`（若本机存在）：主体/节奏/目标语义/复看要求。本 skill 只补充这一层的具体做法。
- 交付记录 `docs/development/SPELL_SPECTACLE_20260926.md`：前三轮做了什么、用户怎么反馈、还剩什么。

改代码前读 [references/architecture.md](references/architecture.md)（文件、挂接点、身份识别、如何加新招）。遇到怪现象先查 [references/lessons.md](references/lessons.md)（本项目已经踩过的坑）。

## 用户认可过的方向

三轮迭代里用户的反馈，按时间顺序：
1. 给出三张参考图（彩虹鳞片冲浪、金纹祥云龙卷、彩虹穹顶斩），要求**每一招**都达到那种绚丽、炸裂、丰富度。
2. "全部加强"：包括主角 H07/H08/H01 的发白也要压，支援类也要亮。
3. "缺乏一点创意，比较雷同"：只换颜色和形状不够。
4. "可以设计类似旋风、剑气等著名的魔幻招数"，看过成品后说"非常好"。

所以"好"的标准是：**同屏排成网格时，每个身份一眼能认出不同**，并且有一个能叫出名字的招式动作。颜色只是最后一个区分维度。

## 每个身份由五个维度组成

在 `SpellSpectacle20260926.cs` 底部的 `Profiles` 表里，每一行 `P(...)` 定义一个身份：

| 维度 | 可选项 | 决定什么 |
|---|---|---|
| 形态 `Family`（主 + 副） | Crescent 彩虹穹顶弧、Rising S形升腾、Falling 过顶砸落+地面撕裂、Surge 冲浪卷、Fan 扇叶、Twin 交叉斩、Curtain 褶帷、Tide 贴地潮浪 | 主体曲面的走向；同一身份第偶数次施放换副形态 |
| 材质 `Matter` | Filigree 金纹、Flame 火、Water 水、Crystal 晶体、Silk 丝、Ink 墨、Electric 雷电、Smoke 烟 | 纹理、边缘（撕边/刻面锯齿/软边）、墨色压暗、流动速度、闪烁，以及**命中心**的形式 |
| 签名 `Accent` | Lightning、Cracks 地裂、Vortex、Wings、Orbit 环绕、Shards、Splatter 泼墨、Foam，名招 Tornado 旋风、SwordQi 剑气、SwordRain 剑雨、Meteor 流星、Spikes 地刺、Dragon 金龙、Lotus 莲花 | 身份独有的附加主体和粒子 |
| 强度 `Style` | Light / Strike / Heavy / Support / Control | 尺寸、层数、粒子数、全屏染色；由 intent 推断（`EnemyStyle`） |
| 色阶 `ramp` + line/core/wash/hot | 5–7 个色标 | 主体颜色、金线、亮芯、全屏染色 |

设计新身份或改旧身份时：
- 先想"这一招在世界里是什么"。比如锤子砸地就是晶体加地裂，墨笔划过就是墨加泼墨，护盾就是晶体加支援升腾。然后挑材质和签名，最后才定颜色。
- 同一场景里常同时出现的敌人，至少要在材质或签名上不同。只换色相会被用户当成雷同。
- 名招要给最贴语义的那一招，不要为了炫而硬塞。剑气给挥剑的，旋风给旋转扫尾的，莲花只给治疗。
- 治疗、护甲、强化用 Support 或 Control：只聚拢、包覆、升腾，**不出现伤害星爆、地面溅射或主角受击**。Lotus 会替换掉升腾火舌。
- 一招一个主角：金龙、旋风这种大签名要减少陪衬主体（见 Dragon 的做法），不然互相遮挡。
- 项目禁用的规则几何（完整等距圆环、平行光条、矩形光毯）依然适用：漩涡每臂少于约 0.7 圈，剑雨/地刺角度和长度要错开。

## 工作流程

1. **确认范围**：用户点名哪几招，还是全部。查 `docs/development/SPELL_SPECTACLE_20260926.md` 的"仍未达到"部分，确认这次是在修什么。
2. **备份**：改动任何既有文件前，复制到 `backups/spell-spectacle-<日期>/original/`（`backups/` 不进 git，但项目要求保留改前原件）。
3. **修改**：身份组合改 `Profiles` 表；新签名或新材质按 architecture.md 的"加新招"步骤；材质贴图用 `tools/vfx-spectacle-20260926/make_matter.py` 重新生成（贴图导入要关闭 mipmap）。
4. **编译**：
   ```bash
   "/Applications/Unity/Hub/Editor/6000.3.20f1/Unity.app/Contents/MacOS/Unity" -batchmode -nographics -quit -projectPath UnityBattleSource -logFile output/<dir>/compile.log
   ```
   然后 `grep "error CS"`。
5. **先小批探针录制**：挑 6–12 个受影响的组，用 `scripts/record.sh`，看完再全量。
   ```bash
   .claude/skills/mistport-spell-spectacle/scripts/record.sh output/spell-spectacle-<日期>/probe1 --only=H07,M26,T12
   ```
6. **复看**（必须真看图，不能只看"通过"）：
   ```bash
   PY=/tmp/mistport-vfx-encode/venv/bin/python
   cd output/spell-spectacle-<日期>/probe1
   $PY ../../../tools/vfx-spectacle-20260926/peak_strips.py after strips [KEY ...]   # 每组峰值前 0.12s 到后 0.62s 共 7 帧
   $PY ../../../tools/vfx-spectacle-20260926/sheet.py out.jpg after/KEY.mp4 起秒 止秒 帧数 [宽]  # 连续帧/近景
   ```
   判断雷同时做**全身份网格**：对每组按 `strips/peaks.json` 的 `peak_seconds + 0.1–0.15` 取一帧，6 列拼图（会话里的 `variety-round7.jpg` 就是这样做的）。
7. **全量录制 + 安全检查**：
   ```bash
   .claude/skills/mistport-spell-spectacle/scripts/record.sh output/spell-spectacle-<日期>/roundN
   .claude/skills/mistport-spell-spectacle/scripts/record.sh output/spell-spectacle-<日期>/roundN --safety
   ```
   第二次跑完，脚本会比对两次源码 SHA 清单是否逐字节一致。全量录制约 7 分钟，安全检查约 6 分钟，可以放后台跑。
8. **给用户看**：用户会说"给我看看效果"。给两样东西：
   - 并排对比视频，左边原版、右边现版，每招先原速再 0.4 倍慢放：
     ```bash
     $PY tools/vfx-spectacle-20260926/showcase.py <改前目录> <改后目录>/after <改后目录>/strips/peaks.json <输出.mp4> "KEY:中文标签" ...
     ```
     改前录像在 `output/whole-spell-round2-20260922/after/`；B07–B10 在 `output/tower-bounty-growth-20260924/after/`。可以把两处软链到同一个临时目录。
   - 峰值网格图。

   发送前先抽几帧检查标签没有乱码、画面里有特效。
9. **记录**：更新 `docs/development/SPELL_SPECTACLE_20260926.md`（或新开当日文件并在 `mistport-ios/docs/game-design/chapter-one-30/README.md` 执行文档表里加指针）。写清：改了什么、录制/安全项数、源码清单 SHA、看图方式（抽帧不是实时播放、没有音轨）、仍未达到的地方。
10. **提交**：只有用户要求才提交或推送。`output/`、`backups/` 被 `.gitignore` 排除。远端是 `andrewlinbridgeedu-droid/port`；上次用户选择"直接合进 main 推上去"，但每次仍要问。

## 汇报口径

- 分开说：Unity 编辑器录像、录制/安全检查、设备导出/签名构建、真机、用户视觉认可。本层到目前为止**只有编辑器录像**，Build127 之后没有出包装机。
- 看图方式如实说：峰值附近抽帧加部分连续帧，不是实时播放，没有听音效，没有测 iPhone 帧率。
- 用户用中文交流，偏好简短结论，然后是"还没做到的"，然后是需要他决定的问题。
