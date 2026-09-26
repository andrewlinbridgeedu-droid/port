# 通缉牌局：五张换牌、赌注与新版牌背（2026-09-25）

用户要求解释规则、加入赌注，并重做粗糙的牌背。B03 码头老水手和 B08 酒馆牌手保留为可选线索；不打牌、输牌或铜币不足仍可查公开档案，不锁死通缉案。

## 已接入的规则

- 一副标准 52 张牌随机洗牌，双方各五张。玩家可换 0–3 张；对手仅按自身牌型决定留牌，也最多换三张，不读取玩家手牌或牌堆未来牌。
- 同花顺＞四条＞葫芦＞同花＞顺子＞三条＞两对＞一对＞高牌。同牌型比较组成牌点数、再比踢脚牌。A 可做高牌，也可做 A-2-3-4-5 最小顺子。完全相同为平局。
- 发牌前选 10／20／40 铜币押注，当即寄存。赢：返还押注并赢同额铜币、取得约定口供；负：失去押注；平：退回押注。暂离牌桌保存本局手牌与押注，回来继续；同一 `roundID` 只结算一次。赢得口供后不能再靠同一牌手重复刷钱。
- 游戏内铜币赌注仅是案件线索玩法；通缉战败的铜币／随身普通遗落物风险另行结算，牌局失败不会触发战败损失。

核心牌型／对手换牌和结算数据在 `mistport-ios/MistportCombatCore/Sources/MistportCombatCore/BountyPoker.swift`；铜币寄存、恢复、幂等和线索入账在 `mistport-ios/Mistport/GameStore.swift`；手机界面在 `mistport-ios/Mistport/BountyPokerRound.swift`。旧存档新增的牌局状态字段均有解码默认值。

## 牌背与界面

原紫色底加 sparkle 的临时牌背已从牌局中移除，新资源是 `mistport-ios/Mistport/Assets.xcassets/BountyPokerCardBack.imageset/art.png`（1024×1536）。使用内置 imagegen 生成，提示词：

> Production texture for a vertical fantasy harbor detective playing-card back; symmetrical nautical astrolabe and clockwork compass rose, subtle waves and lighthouse silhouettes, midnight indigo/deep teal lacquer, antique gold filigree and pearl enamel, centered flat full-bleed 2:3 art, no letters, numbers, suits, logos, hands or extra cards.

手机界面先展示对手身份、线索交易、五张新牌背、押注选项、胜负收益、完整牌型顺序；发牌后显示双方手牌、换牌数和赌注，摊牌后显示双方牌型及铜币净变动。底部背景已延伸至屏幕下缘。UI 视觉已通过 iPhone 13 镜像查看，但用户审美认可仍待反馈。

## 验证与存档保护

- 核心 `BountyPokerTests` 三项覆盖牌型等级／踢脚、52 张唯一性与三张换牌、赢／输／平三种钱包结果；与每日通缉／十案链合计 13 项定向测试通过。
- 签名 Build 98 构建、签名校验与 iPhone 13 安装成功。安装前后的 Preferences 逐文件一致，备份在 `backups/bounty-poker-20260925`。
- 设备独立 suite 断言 `BOUNTY_POKER_VERIFY_PASS`：押注仅扣一次、重启后继续原局、重复结算不会重复得失、结果和线索可恢复。控制台命令因应用持续运行而超时，断言本身已通过。
- 真机镜像隔离预览：押 20 铜、换三张，摊牌显示“高牌对葫芦，损失 20 铜”，下一局余额从 100 变 80；再押 10 铜后重启，仍是相同 A♥／5♠／3♦／8♠／8♥ 手牌与 10 铜押注。预览使用 `mistport.bounty-poker-preview-20260925`，未在玩家真实档下注。
- 最后已从预览参数切回普通启动，手机保留 Build 98；iPhone 镜像上已看见普通标题页。玩家档 `mistport.player-test-01-15` 在预览前后只有 `mistport.campaign-relics.v1` 数组顺序变化，两件物品集合相同；安装 Build 98 前后 Preferences 完全相同。

边界：真实调查中 B03／B08 各自完整找人、入屋、开牌局、胜后交案尚未从用户存档实玩；随机牌局不会按情节强制给某种牌型，视觉评价也不能由测试断言替代。
