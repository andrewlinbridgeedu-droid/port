# 主角 v4 战斗架势与全身施法 · 模拟器复看证据 · 2026-10-02

全部来自 iOS 模拟器（iPhone 17 Pro，iOS 26.5）或 Blender 预览，**不是真机，也不是用户认可**。模拟器上 Effekseer 改用 Unity 渲染，ASTC 纹理被解压，法术观感可能与手机不同。

| 文件 | 来源 | 内容 |
|---|---|---|
| `stance-before-after.png` | 模拟器 169.27 与 169.28 录像，Blender 预览 | 左：改前待机（A 字站姿、双手下垂）；中：改后待机；右：新架势的 Blender 侧面和正面；下：169.28 游戏内一次施法，每 0.3 秒一帧 |
| `pose-BattleIdle.png` | Blender `--pose-frames`，最终架势 | 待机七个相位 × 游戏机位、背面、侧面、正面 |
| `pose-CastTwinSweep.png` | 同上 | 双影追猎（交叉扫）：转腰、交叉、下蹲、收回 |
| `sim-169.28-hero-09-21s.jpg`、`sim-169.28-hero-21-33s.jpg` | 模拟器 169.28 录像，主角特写，每 0.5 秒一帧 | 战斗中的施法动作与架势；28 秒后为胜利后的待机 |
| `sim-169.27-spells.jpg` | 模拟器 169.27 录像，全画面 | 样板战斗中法术特效已恢复：彩色放射爆发、雷弧、彩虹扇面；31.5 秒的棕色三角是石颚重击飞出的碎石（敌人旧特效） |

169.29 只比 169.28 多了复看静音和一处红字报错修正，动作与特效相同。

复现：录像用 `xcrun simctl io <UDID> recordVideo --codec=h264 --force /private/tmp/…/x.mp4`（写到 SSD 会报无权限），拼图用 `scripts/video_contact_sheet.swift`；姿态图用 `tools/animation/build_hero_v4.py --pose-frames … --pose-dir …` 加 `tools/animation/hero_v4_pose_sheet.py`。原始录像（169.27 共 95 秒、169.28 共 70 秒）、两次控制台日志和最终架势的 56 张 Blender 姿态渲染不入库，存在 `/Volumes/andrew's SSD/Mistport-archives/hero-v4-20261002-review/`。
