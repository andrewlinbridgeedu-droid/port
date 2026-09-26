# 《秘仪：雾港升序》游戏设计文档

版本：0.4  
状态：单人固定技能回合制产品基线

本目录收录当前 iOS 游戏的正式上游设计文档。所有旧版实时多人、自由移动和团队副本方案均已废止。

## 推荐阅读顺序

1. [GAME_BLUEPRINT.md](GAME_BLUEPRINT.md) —— 产品承诺、边界、核心循环、玩家经济与商业模式；
2. [STORY_BIBLE.md](STORY_BIBLE.md) —— 宇宙规则、阵营、九联邦、身份成长与终局；
3. [PROGRESSION_SYSTEM.md](PROGRESSION_SYSTEM.md) —— 新手节奏、规则权限、技能、遗器与晋升；
4. [COMBAT_MODEL.md](COMBAT_MODEL.md) —— 固定技能回合制战斗、事件管线、UI 与人物表现；
5. [CHAPTER_ONE_FOOL_VERTICAL_SLICE.md](CHAPTER_ONE_FOOL_VERTICAL_SLICE.md) —— 旧钟区纵切范围、教学节奏和验收标准；
6. [OLD_CLOCK_QUESTS.md](OLD_CLOCK_QUESTS.md) —— 旧钟区 NPC、四项主要调查、首领与区域结局；
7. [REVISION_NOTES.md](REVISION_NOTES.md) —— 版本变化与废止内容。
8. [NETWORK_AND_COOP_BOUNDARY.md](NETWORK_AND_COOP_BOUNDARY.md) —— 经济交易驱动的联网与少量协作边界；
9. [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) —— 当前工程迁移进度与 legacy 清单。

## 最高优先级规则

出现冲突时按以下顺序处理：

1. `GAME_BLUEPRINT.md` 的产品边界；
2. `PROGRESSION_SYSTEM.md` 的成长与晋升规则；
3. `STORY_BIBLE.md` 的世界观与叙事事实；
4. `COMBAT_MODEL.md` 的技术实施；
5. 纵切和区域任务文档。

任何下游文件不得重新加入：

- 实时移动战斗；
- 玩家组队、AI 队友或多人副本；
- 团队坦克、治疗、仇恨或协同职责；
- 需要寻路与自由探索的大型战斗地图；
- 强制签到、体力或现实时间晋升锁；
- 主线章节付费门槛；
- 付费战力或付费市场优势。

产品负责人补充确认：本作仍是网游。玩家互动以经济、交易、供需与异步城市事件为主，并允许少量不阻塞单人主线的轻协作；这不恢复传统组队副本或实时多人战斗。

## 文件边界

- `mistport-ios/README.md` 保留在工程根目录，作为运行、实装状态和调试入口；
- 早期心理健康卡牌项目已从工作区移除，不属于本项目依据；
- 名称带 `(3)` 的 `GAME_BLUEPRINT(3).md`、`PROGRESSION_SYSTEM(3).md` 和 `STORY_BIBLE(3).md` 是旧版重复文件，不应继续引用，建议移入 `legacy/` 或删除；
- `*.original.md` 仅用于追溯修订前内容，不属于正式设计依据。
