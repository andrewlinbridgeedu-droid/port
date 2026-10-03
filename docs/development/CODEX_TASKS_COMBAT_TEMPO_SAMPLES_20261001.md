# Codex 任务单：战斗节奏样板（Q4、D01、B01）与自然动作 · 2026-10-01

交给 Mac 上的 Codex，回复用户用中文。

## 背景

用户给了一段参考录屏，要求战斗更激烈：敌人出手更快、每下伤害更小。另外追加了一条：“通过 Blender 或者其他技术，让敌人和主角的动作更加自然。”

用户已认可：
- 节奏数值；
- 假面等按次数的防御只接重击，轻击由幻影招架；
- 战斗时长基本不变；
- **所有战斗都有 ×2 速度按钮**；
- 先做三场样板。

规划：[COMBAT_TEMPO_PLAN_20261001.md](../../mistport-ios/docs/game-design/chapter-one-30/COMBAT_TEMPO_PLAN_20261001.md)。第 4 节写表现要求，4.1b 写动作自然，第 6 节写规则实施状态。

## 云端已完成的规则

在分支 `claude/world-economy-m0-u62oho`，随 PR #40 合入。

- **只对三场生效**：
  - Q4 `chapter01_q04_encounter`；
  - 塔第 1 层 `church_tower_001`，敌人是石颚（D01）；
  - 通缉 B01 `church_bounty_b01`。
- **轻击**：
  - 敌人在原有动作之间加一种快速轻击：间隔约 1.4 秒，猎犬 1.3 秒；前摇 0.35 秒；
  - 敌人蓄力期间不出轻击，回复期间频率减半，原有攻击落下前 1.2 秒内不出，Q4 猎犬的 3 秒破绽期间不出；
  - 每下伤害：Q4 取攻击力的 5%，D01 取 15%，B01 取 22%。
- **招架**：假面幻影在场时，轻击被“招架”，伤害减半，不消耗次数。
- **原有攻击伤害降为 70%**。
- **玩家**：普攻 1.2 秒一下，伤害减半，硬直 0.8 秒；技能硬直 1.1 秒。
- **规则入口**：
  - 结算：`MPCChapterOneEncounterSession.adoptTempo(_:)`、`resolveLightAttack(enemyID:at:)`；
  - 排程：`MPCLightAttackClock`；
  - 常量：`MPCCombatTempo.profile(encounterID:)`；
  - 步进器事件：`lightAttacks`、`lightResolved`（带 `parried`）、`lightCancelled`。
- **版本号**：升为 `church-battle-v3`、`story-battle-v2`。
- **修了一个旧 bug**：敌人在蓄力中途被打死时，主线战斗永远不结束。
- **验证**：
  - 规则库 564 项测试全过；服务器 22 项全过；
  - 墙关探针不变；
  - 模拟器对比见规划第 6 节：三场时长基本不变，剩余血量接近改前，单下最大伤害降了约三成，每秒可见事件从约 1.5 个升到约 3 个。

## 开始前

1. 从最新 `main` 开新分支，并合入 PR #40（`claude/world-economy-m0-u62oho`）。PR #40 还带着首页雨云的改动，构建通过后一起交用户看。
2. 先读：
   - `AGENTS.md`；
   - 上面的规划；
   - `docs/development/HANDOFF_WALLS_20260929.md` 最上面一节；
   - [Q4 猎犬出招任务单](CODEX_TASK_Q4_HOUND_ATTACK_20261001.md)：Q4 的身体动作要求以那份为准，和本单一起做。
3. 法术特效按 `.claude/skills/mistport-spell-spectacle/SKILL.md` 的流程做。
4. 约束：
   - 构建编号低于 170；
   - DerivedData 和归档放外置 SSD，指向 SSD 的链接不动；
   - 不覆盖玩家存档，装机前后逐文件核对 Preferences；
   - 改了 Unity 资源后先核对导出新鲜度，再构建宿主；
   - 构建、测试、录像都不等于认可，用户在真机上看过才算。

## 任务 T1：App 接规则

1. App 的战斗推进现在是 `ChapterOneTestView.tickContinuousCombat()`，还没用规则库的步进器。三场样板里要做到：
   - 开战时调用 `session.adoptTempo(MPCCombatTempo.profile(encounterID:))`；
   - 每一帧用 `MPCLightAttackClock.advance` 排程和结算轻击，**不要在 App 里另写一套规则**；
   - 普攻间隔、普攻硬直、技能硬直取 `tempo.basicInterval`、`basicRecovery`、`skillRecovery`；`tempo` 为空时保持现在的 2.4 秒、1.65 秒、1.75 秒。
   - 如果直接把这三场改用 `MPCStoryBattleStepper` 和 `MPCChurchBattleStepper` 更省事，也可以，那本来就是计划。
2. **×2 速度**：
   - **所有战斗**都有这个按钮，主线首通、塔、通缉、街头战全包括；
   - 只加快画面：规则照样 50 毫秒一格，×2 时每帧推进两格，Unity 动画和特效的时间缩放跟着翻倍；
   - 选择要记住，下一场照用。存在新的偏好键里，不动玩家存档里已有的键。
3. **飘字**：
   - 伤害数字：白色；会心金色并放大；误认、错位加成的伤害紫色；
   - 状态字：“误认＋2”“错位”“招架”“净化”“护盾”；
   - 主角受击显示红色数字，被招架时显示灰色数字加“招架”；
   - 同一位置同时最多 4 个，旧的加快淡出。
4. **受击反馈**：重击打到主角时镜头轻震，屏幕边缘泛红 0.2 秒；会心和重击打到敌人时停帧 40–60 毫秒。

## 任务 T2：动作自然（Blender 等，先做样板三个模型和主角）

规划第 4.1b 节，要点：
- **现状**：
  - 敌人是 Meshy 模型，配 Meshy 自动生成的通用动作（`Resources/Enemies/Signature/*/Combat.controller` 里的 Idle、Cast、Charge、Hit、Death、Retreat），出招时再用 `MainlineBodyRound2` 用代码扳骨头；
  - Q3、Q4 猎犬出招时腿还在走。
- **要做的模型**：
  - Q4 发条猎犬（`HellHoundBattle.controller` 和相关资源）；
  - D01 石颚：资源在 `Resources/Enemies/Signature/Stonehide`，表现脚本是 `StonehidePresentation20260917`；
  - B01 第七号空壳（`Resources/Enemies/Signature/BountyB01`）；
  - 主角（`FoolBattle.controller`、`Models/Fool`）。
- **Blender**：
  - 用 Homebrew 装：`brew install --cask blender`；
  - 写 Python 脚本批量导入、修骨骼和权重、导出 FBX；脚本放 `tools/animation/`，提交进仓库。
- **每个敌人做 5 条动作**：轻击（0.3–0.5 秒，前冲再弹回）、重击预备、重击出手、受击（叠加层）、战斗待机。猎犬再加扑咬。
- **主角做 7 条**：普攻 3 种（短斩、刺、甩牌）、受击、招架、施法预备、待机（呼吸、斗篷摆动）。
- **动作来源**：
  - 人形可以套现成动捕，例如 Mixamo、CMU 公开动捕库，或用视频转动捕（如 Rokoko Vision、DeepMotion），套上后手修；
  - 四足和怪物在 Blender 里手调关键帧；
  - 来源和授权写进 `tools/animation/SOURCES.md`，只用允许商用的素材。
- **动画基本功**：预备、出手、惯性、回位；身体各部位先后到位；不要整体平移；脚不滑。
- **Unity 里接好**：
  - 状态间过渡不超过 0.1 秒；
  - 冲刺类动作用根运动，打完回到编队位；
  - 用 Animation Rigging 给脚加 IK、让头看向目标；
  - 尾巴、耳朵、披风用弹簧骨物理；
  - 受击用叠加层；
  - 样板三场去掉出招时代码扳骨头的姿势。
- **时间对齐**：轻击动作的“打中”帧必须落在规则的 `landsAtTick` 上，原有攻击同理。动作长短可以调，规则里的时间不改。

## 任务 T3：样板三场的特效

- 敌人轻击：小而快的命中火花，每种敌人一种材质：猎犬火星、石颚碎石、空壳灰铁火花。
- 招架：主角身前幻影抬手，金属脆响，灰白色碎光。
- 敌人重击的预告：
  - 地面红色预告区，形状不得是正圆或直边框；
  - 猎犬双焰、石颚重砸、空壳伏击各用自己的形状。
- 主角三招按技能梳理已认可的道具做：
  - 假面谕令：面具；
  - 双影追猎：两道影子冲刺；
  - 荒谬归结：道具雨加谢幕。
  - 每招整段不超过 1.2 秒，前后招叠着放。
- 先小批录制探针，再做改前改后并排对比。

## 任务 T4：真机与交付

- 构建 169.x（低于 170），装机前后逐文件核对 Preferences。
- 三场各录一段完整战斗，×1 和 ×2 各一段，和改前并排；另录一段主角普攻、受击、招架的特写。
- 单独一个 PR 合回 `main`，写清验证了什么、没验证什么。
- 更新 `docs/development/HANDOFF_WALLS_20260929.md`。
- **用户认可样板之前，不铺到其他战斗。**
