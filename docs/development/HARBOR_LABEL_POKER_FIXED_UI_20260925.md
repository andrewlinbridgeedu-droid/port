# 港城全员标识与固定五张换牌界面

日期：2026-09-25。用户决定 Luna 暂缓，通缉先保持固定案件和固定牌序。本批改游戏界面与交互预览，不改案件正史、证据门槛、奖励、人物路线或牌局胜负规则。

## 已改

- 港城 23 名现有可点击街坊都常显与邮差相同的头顶姓名胶囊；悬停仍使行人暂停，点击仍聚焦并以白泡泡对话。无主角的港城地图保持原样。
- 港城主页真正能进入的三处入口——教会、酒馆、咖啡馆——仍全部有屋顶文字标识。通缉调查图的当案五处地点与教会／酒馆柜台共七处可访问点统一改为无图标的文字胶囊；最终现场在证据达到原有开放条件前仍隐藏，不提前剧透。
- B03 码头老水手、B08 酒馆牌手共用新版五张换牌页面：对手暗牌、玩家可选最多三张、点牌显示“换掉”、摊牌揭开对手固定两对、胜利返回情报、失利可同页重赛或离开查公开档案。B03／B08 原手牌、补牌顺序、对手牌、评分和记录胜负的核心调用不变。
- 交互视觉稿：`output/harbor-label-poker-20260925/index.html`。可切换港城标签、B03／B08，并操作一局固定牌局。此 HTML 是便于评审的界面预览，不是 iPhone 实录。

## 核对

- `xcodebuild -project mistport-ios/Mistport.xcodeproj -scheme Mistport -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO -quiet build` 完整编译成功；改动后的最终增量编译也成功。
- Swift 核心定向测试 `optionalPokerCanLoseRetryOrUsePublicRecords` 通过，覆盖 B03／B08 输后重试与公开档案替代线。
- 预览脚本语法检查通过，引用的两张现有场景图路径存在。独立验证 B03 换 2 张可成同花顺、B08 换 3 张可成四张 A，均胜过既有对手两对；B03 不换牌会输。
- 本批没有重新签名、安装或通过镜像实看 iPhone 页面。HTML 预览也不能证明 SwiftUI 在 iPhone 13 上的实际间距、字号和帧率。

## 边界与后续

当前 23 名街坊在港城主要仍是一句固定街谈，十案分支对白与统一调查入口属于 [`HARBOR_CITY_BOUNTY_PRO_LUNA_20260925.md`](../../mistport-ios/docs/game-design/chapter-one-30/HARBOR_CITY_BOUNTY_PRO_LUNA_20260925.md) 的后续制作。港城主页只有三处已实现的建筑入口；不把画中的邮局、诊所或房屋自动标成可进入。正式通缉调查图按每案可访问地点显示文字标记。Luna 服务端、随机剧情和生成对白均未接入。
