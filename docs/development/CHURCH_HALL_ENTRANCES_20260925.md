# 圣所入口与资源栏（2026-09-25，Build 92–93）

## 改动

- 用户认可四入口「场景铭文」预览后，圣所首页将原先两块紫／橙发光框改为与门、卷宗板对位的浅金标题、低黑渐变和短金线；「封线维护」「封线装备」合并成一条双入口服务栏。四项均保留原目的地及按钮点击范围。底部「封存借物处」仍用原有图片和左侧实物图，没有重画。
- 后续用户指出借物页标题下的功勋／铜币太不显眼，并要求圣所首页资源也使用游戏图片。新增共用 `ChurchResourceBalanceBar`：复用正式深井奖励已使用的 `RewardReputation`（功勋）和 `RewardCoin`（铜币）资源图，配以 17pt 数值、暗色底和细金分隔线；圣所首页与借物页共用。借物页原灰色小字副标题移除，资源栏改在标题下独立显示。
- 未改变功勋、铜币的来源、金额计算、借物契约、装备、通缉或保存结构。

## 验证

- iPhoneOS Debug 签名 Build 92 与 Build 93 均构建通过；Build 93 `codesign --verify --deep --strict` 通过并已安装在 iPhone 13，设备列表显示 `0.1.0 (93)`。
- 镜像实看首页两主入口、合并服务栏、未改绘的借物入口；逐一点击确认联封深井、悬赏卷宗、封线维护、封线装备及封存借物处均进入相应页面。借物页的资源图和数量在标题下清晰可见，当前契约按钮未遮挡。没有执行战斗、借用／归还、结算或穿戴。
- Build 92、93 安装前后各自的 `Library/Preferences` 逐文件相同，备份在 `backups/church-hall-entrances-20260925/device-*` 和 `backups/church-loan-resource-header-20260925/device-*`。Build 93 启动后为测试「悬赏卷宗」入口打开今日悬赏，游戏正常生成 2026-09-25 的 `dailyBountyIssue`（B05/B02/B01/B09）；其它差异为集合数组序列化顺序，功勋、铜币、已穿装备等值未变。因此不能称启动后的偏好文件逐字节不变。
- 当前只在 iPhone 13 实测；较小屏幕、系统放大字体和横屏未验。

## 留存

- Build 92 改动前源码：`backups/church-hall-entrances-20260925/prechange/ChapterOneTestView.swift`。
- Build 93 改动前源码：`backups/church-loan-resource-header-20260925/prechange/ChapterOneTestView.swift`。
- 本次未生成新图片，继续使用工程已有资源。
