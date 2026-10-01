# 雾港界面美术统一（2026-09-30）

本轮承接在用页面审查，按用户“全部优化”执行。基于 `5ba38b4`，保留现有场景、人物、卡面、房屋、封蜡与工坊按钮素材，补齐默认系统表单和纯色操作按钮。

## 实装范围

| 页面/入口 | 本轮变化 |
| --- | --- |
| 城市事件 `CityEventsView` | 对应事件的现有场景插图、纸质内容面板、交付按钮和主行动按钮；城市变化分组 |
| 通缉现场 `HomeBountyInteractionView` | 地点插图、调查档案布局、统一调查/答案/交案按钮 |
| 同地点多任务 `HomeTaskChoicesView` | 默认 List 改为委托登记页和独立任务牌 |
| 街坊旧对话 `NeighborConversationView` | 白底系统页改为邮局/委托所插图和纸质面板；兼顾旧入口与隔离预览 |
| 技能长按介绍 `ChapterSkillDetailSheet` | 技能卡面、档案标题、完整效果文字、独立收起按钮，内容可滚动 |
| 租屋 `HousingViews` | 房源/租约/住处共用页框；饮食菜单改为直接显示价格和选中状态的卡片；保留封蜡动画 |
| 建筑柜台 `HomeCounterScene` | 人物与场景保持原图；返回按钮、内容纸面、柜台操作牌统一 |
| 残余案 `RemnantCasesView` | 保留报纸版式；接案、领取、前往清理与调查选项统一 |
| 百工坊 `LocalWorkshopView` | 保留原有绘制按钮；补齐交货、装备维护和返回按钮 |
| 角色 `CharacterProfileView` | 技能强化、装备购买/修复和相关操作使用统一按钮；保留技能长按说明 |
| 酒馆与牌桌 `BountyPokerRound` | 酒馆行动、玩法切换、押注、彩头、开局、叫分、提示、不出、出牌、再开局统一铜金/纸质外观 |
| 预留随机货架 `VenueView` | 购买按钮和已售/买不起状态统一；货品卡增加高度，容纳更大点击区域 |
| 三类街头战结果 | 事件战、赶塔怪、残余案共用胜负徽章、结果文字与返回按钮，不改结算调用 |
| 设置 `GameSettingsView` | 系统 Form 改为旅人手册，姓名/声音/效果分组；保留设置键、监听与完成保存行为 |

## 组件与边界

- `GameArtComponents.swift`：铜金切角描边、纸质页框、`ButtonArt25MainAction` 现有绘制主按钮、页面框架与战后反馈。文字仍为动态文本，不烘焙价格或任务状态。
- 常规新按钮最小点击高度 44pt，支持禁用态、选中态和按下反馈；长标签可换行。牌桌保留原有紧凑布局，在原控件上替换装饰。
- 没有修改 `GameStore`、CombatCore 规则、奖励、租金或真实存档。所有截图来自独立模拟器；未连接、安装或覆盖真机。
- 旧 HTML 地图与已断开入口的历史结局/战前页面不属于当前玩家路线，本轮没有重做。Unity 演出和法术资源没有变化。
- 美术可见性检查与用户真机认可分别记录；模拟器编译或截图不代表新版真机已验收。

## 复现

```sh
python3 tools/housing/build_simulator_harness.py --output "/Volumes/andrew's SSD/Mistport-build-cache/ui-art-polish-20260930"
# 将构建结果安装至专用 iOS 模拟器后：
python3 tools/ui-art/capture_simulator.py --simulator <UUID> --destination docs/development/ui-art-polish-20260930/screenshots
```

构建器从正式项目读取源文件与资源，在 SSD 生成无 Unity 的模拟器宿主。新预览入口必须同时带 `--daily-pacing-device-walk` 和 `--daily-ui-review=<page>`，使用已有隔离夹具。胜负页面截图展示明确的结果态夹具，不宣称完成了 Unity 战斗。

## 验证记录

- iOS Simulator / arm64 宿主完整构建通过，复用正式 Swift 源码和 Asset Catalog；没有编译/导出 Unity。
- `swiftc -frontend -parse` 与 `git diff --check` 通过；新增共享组件的图片引用逐项核对存在。
- 首轮截图检查发现百工坊返回按钮叠着系统工具栏底，以及主行动按钮文字偏上；已改为独立页眉，并按既有羽毛按钮的有效文字区调整垂直留白。城市事件重复标题已去掉。
- 截图入口、时间和来源见 `screenshots/capture.json`，可通过 [截图画廊](index.html) 查看。
- 原有 `--preview-tavern` 路径会先执行历史结算自检，该旧夹具在 `GameStore.swift:3353` 的 `try! startChurchBountyDou` 抛错。美术截图改用每日隔离预览宿主，仅调用 `prepareTavernPreview` 和实际酒馆视图；本轮没有修改或宣称通过该旧结算自检。
- 图片是实际 SwiftUI 窗口截图，部分不包含系统状态栏；胜负两张为结果态夹具。实际战斗、真机安装与用户视觉认可均不在本轮验证结果之内。

核对当前入口后确认：正式铜币商人使用 `HomeCopperShopView` / `HomeCounterAction`，已统一；旧 `VenueView` 随机商品货架受 `CityService.isReleased` 门控，尚未开放，本轮顺带更新其商品卡组件。`shop.png` 是正式商人柜台的隔离截图，`offers.png` 仅是原商品卡组件预览，不表示货架已开放。

最终交付包含 16 张原始截图。横屏斗地主通过实际 UI 点击，将押注从 10 铜切换为 20 铜，已核对选中态和“押20铜 · 洗牌开局”文案同步变化；没有为此次视觉检查扣款或运行牌局结算。图片逐页复看，检查的是所示画面，不宣称覆盖每个分支或完成全游戏回归。
