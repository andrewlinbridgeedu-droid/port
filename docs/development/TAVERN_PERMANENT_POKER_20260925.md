# 暮钟酒馆 · 灰筹莫尔常驻牌桌

2026-09-25。B08「借脸人·弥伦」**交案领奖后**，酒馆的牌手灰筹·莫尔成为常驻角色；在此之前可和他交谈，但牌桌锁定。莫尔曾是港务抵押登记员，B08 时出售蜡面交易线索，结案后继续在酒馆经营三人牌桌。酒馆从主页和港城都先进入室内，再由「悬赏告示」或莫尔对话进入相应玩法。姓名胶囊与对话是游戏内交互。首次独立立绘生成曾返回 401；再次调用成功，以原酒馆场景中的深色头巾牌手为参考，生成透明底莫尔立绘 `Mistport/Assets.xcassets/BountyNPCMor.imageset/art.png`。点莫尔对话时人物显现在酒馆右侧，牌桌入场说明也展示同一立绘；背景原画仍保留。

普通局长期开放：五张换牌押 10／20／40 铜，胜净赚同额，负失押注，平退注；斗地主是三人两副 108 张，胜按原叫分／炸弹规则获得倍数铜币，负只失本局押注。未完成局离桌会保存。与 B03/B08 **线索局**分离：常驻局不发案内口供，五张换牌没有第五局保底，斗地主一直完整随机。旧案件牌局、公开档案退路与赌注规则保留。

彩头约每三天出现一次；只从玩家已完成对应主线节点、尚未拥有的物品中选，包含较高价值且当前启用的遗落物，以及三件现有晋级主材。当天首次打开酒馆即固定公告，反复进出不重抽；无合格物品的日子为空。当天可押 40 铜进行**一次**彩头斗地主；赢退 40 铜并得到公告物品，不叠加倍数铜利；输失 40 铜。离桌保存当前局，重进继续。结算后当天不再开第二局。若停局期间玩家从别处得到同一唯一物品，赢后只退押并补偿 40 铜，不重复发物品。

实现：`MistportCombatCore/TavernPokerPrize.swift` 固定每日候选，`GameStore.swift` 将彩头日期、未完局、结算与背包／货币放进同一待恢复凭证；奖励重启恢复和重复回调不重复发。晋级主材使用现有 `AdvancementIngredient` ID，遗落物使用现有 `MPCChapterOneCatalog` ID，没有虚构背包条目。`BountyPokerRound.swift` 共用两种牌的规则与帮助页，并标出普通／彩头的真实收益和风险。

验证：CombatCore 全包 **404 项测试通过**；无签名 iPhoneOS 整包编译、签名 Build 115、`codesign --verify --deep --strict`、iPhone 13 覆盖安装通过。首次安装 Build111、Build112 前后的 `Library/Preferences` 逐文件相同；最终 Build115 的真实玩家 `mistport.player-test-01-15.plist` 与本批首次安装前逐字节相同，副本在 `backups/tavern-permanent-20260925/device-*`。设备独立 suite 打印 `TAVERN_PRIZE_VERIFY_PASS`，覆盖 B08 交案解锁、40 铜押注、遗落物／晋级主材胜利入包、重启恢复及重复结算拒绝。该测试用构造的最后一手牌验证结算，**不是**完整随机斗地主真机胜率或整个 B08 实玩。

镜像本轮因 iPhone 正在使用而无法连接；改由测试包在设备自身截取实际 UIWindow：`backups/tavern-permanent-20260925/tavern-feature-preview-final.png` 确认酒馆内莫尔头顶姓名和今日彩头；`tavern-poker-preview-final.png` 确认横屏开局页可同屏看到奖品、押注和开局按钮。两张图用独立测试 suite 的 B08 已结案/Q9/200铜 fixture，未消耗真实玩家的钱。普通启动已恢复。真实用户手指选择彩头／完成整局斗地主，以及镜像动态交互仍待另验。

普通启动后再次读取玩家 plist，唯一变化是 `mistport.campaign-relics.v1` 中原有两件遗落物的数组排列互换；集合内容、其它键和值不变。这来自现有 Set 写回的非确定顺序，不是本次发放奖励，也不能称普通启动后 plist 逐字节不变。

## 莫尔立绘重试与真机复看

同日再次生成成功。原件为 1024×1536 RGBA 透明背景，原始生成文件保留于 `~/.codex/generated_images/01a0c7b3-3f58-7f01-a3ac-6cb40f6af233/exec-af66c403-990e-42b8-9ac7-8ec97d9d10eb.png`，游戏用图逐字节复制进 `BountyNPCMor.imageset`。人物为深蓝头巾、港务罗盘徽、白袖黑背心、红腰带并手持装饰牌的日漫牌手。没有改变酒馆既有原画和牌局规则。

签名 iPhoneOS Build 117 编译及 `codesign --verify --deep --strict` 通过，已覆盖安装 iPhone 13。设备自身 UIWindow 截图 `backups/tavern-permanent-20260925/tavern-dialogue-preview-build117.png` 复看人物对话位置、姓名胶囊和下缘渐隐；`tavern-poker-preview-build116.png` 验证牌桌入场说明中的同一立绘。后者是第一版图像布局的真机静态截图，最终 Build117 仅微调酒馆立绘下缘与姓名位置，牌桌入场布局未改。两张预览都用独立 fixture，非真实玩家进度。已恢复普通启动；普通玩家 plist 与安装前语义相比仅原有两件遗落物数组顺序互换，物品集合和其余字段一致。真机手指点击和完整牌局的动态镜像检查仍未完成。
