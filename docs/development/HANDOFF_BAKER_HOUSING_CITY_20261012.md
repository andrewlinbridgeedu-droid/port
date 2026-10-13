# 交接：面包师委托、街坊走动及住房面板 · 2026-10-12

本轮接 169.82（上轮提交 `e285d96`）。用户要求：刷新面包师任务供重试；检查在委托板随便点一下就完成的问题；任务 NPC 不要一直定在原地、相邻守灯人不要撞衫；赁屋行“我的住处与饮食”子面板应与前页等高且不露出旧面板。用户此前要求完成后 commit、push 和 handoff，继续适用。

## 查证

手机只读快照（169.82 归档的 `bread-task-audit-20261012-codex-01a12f14/real-save-observed.plist`）显示：第 3 天 `d3-baker`、`baker-salve` 已完成，面包师好感 1、完成委托计数 1、余额 347。实际任务是交 1 罐止痛膏。咖啡馆跑堂和东岸提灯人的委托仍未完成，图中铃铛是待办标记。

委托板通过 `HomeNeighborVisit` 打开远处 NPC 对话，其 `.task` 调用 `talkToNeighbor`，因此在板前也能交货完成。首页实际使用 `HomeStreetScene` 的人物图集，并非任务板内旧 Web 3D 演示：任务人物用 7 秒走到停靠点后长期停住；任务结束后直接回到普通人群规则，缺离场过程。东岸／上坡守灯人共用橙色 `HarborLamplighterWalkAtlas`。住房页则是在已经打开的赁屋行 sheet 上再开一个 sheet，造成后页露出旧页。

## 修改

- 委托板改为只读 `HomeNeighborPosterView`，展示请求及“前往”按钮，不建立 NPC 对话、不交货、不传话、不发奖。前往时关闭面板并定位实际任务目标；对话操作仍从首页真实人物点击入口进入。
- `MPCNeighborLedger.Offer.replayWithoutReward` 为可缺省可选字段，兼容旧档。用户请求的面包师重试仅重开当日已完成的这一条一次，保留原铜币、好感、委托计数、贡献和战斗／体力回执；完成重试不再发这些收益。交货仍需真实止痛膏，未退款或赠送物品。
- 开发启动参数 `--refresh-baker-errand` 执行一次上述范围内的重开；反复启动不再次重开。最终只能在最新手机快照后执行，不用旧备份覆盖真实档。
- 任务人物在已标定人行边上间歇慢走；完成后沿来路离场，再回普通人群。面板打开时仍暂停首页时间，避免交谈中目标走失。
- 上坡守灯人改用已存在的蓝衣／皮围裙人物图集，东岸保持橙衣；未生成或修改新位图。
- 赁屋行、我的住处与选房册改为同一个大面板内切换，移除这几层叠加 sheet。返回先回上一级，顶层才关闭；`GameArtPage.dismissOnClose` 默认仍为 true，只有同面板住房导航关闭自动 dismiss。
- `--baker-board-review` 使用单独 `mistport.baker-board-review.20261012` suite，配置第 3 天和两罐止痛膏，供委托板／真实地图人物／付款与离场／住房切页演练；不接触真实或盲玩 suite。

## 验证与构建

新增两项重试测试：旧档兼容、未领取请求不能随意重开、仅指定任务重开、保存读回、原奖励不重复、其他任务保持一致、重复重开／交货拒绝。相关邻里、街头委托和地图目标共 28 项测试通过。

实时 `devicectl device info apps` 确认 169.82，选择 169.83。归档 `/Volumes/andrew's SSD/Mistport-archives/releases/Mistport-169.83-9cab331-baker-housing-city-20261012-codex-01a12f14`，会话后缀保留；DerivedData、日志与新产物都在 SSD。采用 `scripts/build_hero_v4.sh device 169.83`，Unity 导出 → 新鲜度 → 宿主，均成功。最后两处文案／目标定位修改后再次先检查新鲜度、再增量构建宿主，`build-final-ui-169.83.log` 确认成功；签名严格核验通过。169.83 已安装，实时 App 清单确认 `bundleVersion: 169.83`。

## 存档与范围

本轮真正需要改变真实档的是用户明确要求的面包师重试，不能笼统写“存档完全不变”。安装仍应逐文件 SHA 相同；隔离 QA 的差异单独报告；刷新前再取最新真实档，仅允许目标 offer 的 done／重试标记改变，不能恢复早先 347 铜的只读快照覆盖后来游玩。盲玩按用户要求仍暂停，第一章未盲玩通关。

## 首次 push 时的连接阻塞（已解除）

- 安装前后全量 Preferences 各 266 个，逐文件 SHA-256 完全一致：无新增、删除或改变；真实 `mistport.player-test-01-15.plist` 与盲玩 `mistport.player-test-01-15.audit.plist` 均保持原字节。证据在归档 `preferences-install-report.json`。
- 静音隔离启动使用 `-MistportCityMute YES --developer-tools --baker-board-review`，iOS 返回 `Locked`，未成功启动；没有执行隔离演练或真实任务刷新。镜像经过重连、重试与重开仍提示“未找到 iPhone”。已请用户在 Mac 附近解锁一次再锁屏、确认蓝牙／Wi-Fi，以恢复镜像。
- 首次 push 时面包师任务尚未重开，仍保留玩家已完成 `d3-baker` 的状态；当时没有将源码支持／规则测试冒充真实档刷新或视觉验收。
- 当时待办为：恢复镜像，先在独立 review suite 实测委托板只读、前往实际面包师才能交付、待办慢走／完成离场，以及住房各页上下边界一致／无旧页露出；核对真实与盲玩档未变后，再备份最新 Preferences 并刷新面包师。已完成，详情如下；重试交货留给用户。
- 已建档 `build-manifest.json`，记录最终二进制 SHA-256、上轮提交、流水线、最终宿主日志和测试日志。首次发布时真机视觉核验／面包重试刷新仍待完成，盲玩仍暂停。

## 恢复连接后的真机核验与最终状态

用户确认解锁后，镜像重试恢复。以下均为已安装的 169.83 真机观察，修复源码已在 `3a9cdde2e7a0c486f6fde8f22f7e7b0b8528f8df` 推到 `codex/playtest-ui-20261012`。

- 委托板的面包告示只有请求、说明和“前往”，没有交货按钮。查看并前往后读回，`d3-baker.done` 仍为 false，邻里记录和库存完全相同（两罐止痛膏）。点击地图上的面包师后才出现交付按钮，交货消耗一罐、发 29 铜、好感 0→1、完成计数 0→1；关闭对话后面包师沿路离开。证据：`board-readonly-audit.json`、`board-baker-readonly.png`、`actual-baker-delivery.png`、`baker-delivered-once.png`、`baker-depart-sampled-mirror.mp4`。
- 东岸提灯人、咖啡馆跑堂在停靠点间歇走动；25 秒录制含走路和停歇。相邻上坡守灯人为蓝衣／皮围裙，东岸为橙衣。证据：`neighbors-wait-sampled-mirror.mp4`、`lamplighters-distinct-clothes.png`。录像为带时间记录的镜像截图采样编码，非原生 30 fps 屏幕录像。
- 赁屋行 → 我的住处 → 返回 → 选房册 → 返回 → 返回港城均成功。三个住房页共用同一面板，上边界一致、底部填满，没有旧页露出；截图 `housing-agency-full-panel.png`、`housing-residence-same-panel.png`、`housing-search-same-panel.png` 及并排图 `housing-three-panels.png`。没有租房或切换饮食。
- 隔离演练后 Preferences 为 267 个：仅新增 `mistport.baker-board-review.20261012.plist`，原 266 个全量文件逐字节未变，真实与盲玩档均未改。证据 `preferences-review-report.json`。
- 随后停止隔离 App，再取最新 `preferences-before-baker-refresh`，在真实玩家模式静音执行 `--player-test --preview-city --refresh-baker-errand`，日志出现 `BAKER_REPLAY_READY: d3-baker; original reward preserved`。
- 刷新后 267 个文件只有真实玩家 plist 改变，其余 266 个逐字节相同（含盲玩）。解码严格对照：仅 `d3-baker.done: true→false` 和新增 `replayWithoutReward: true`；主线、铜币、物品、好感、完成计数、贡献、其他委托及回执都保留。遗落物持有集合的数组序列化顺序变化，成员完全相同；这是 `Set` 写回次序，不是权益变化。证据 `preferences-baker-refresh-report.json`、`real-baker-refresh-audit.json`、`real-refresh-semantic-diff.json`。
- 真实档余额仍为 347、面包师好感仍为 1、委托完成计数仍为 1。真实止痛膏库存原本为 0，仍为 0，没有退款或赠送；已告知用户重试交货需先到工坊制作一罐。任务保持待办，未替用户完成重试。真实告示明确显示“这次是重试，原报酬已领取”，证据 `real-baker-retry-poster.png`。
- 手机保持真实玩家模式静音运行，面包重试可供用户继续。盲玩仍暂停；本轮未继续主线或宣称第一章通关。
- 真实档查看重试告示、点击“前往”回到面包师街区后，最终全量 Preferences 与刷新后的快照 267/267 逐字节相同，没有追加奖励、交货或其他存档变化；证据 `preferences-final-report.json`、`real-final-baker-street-pending.png`。最终状态已复核并推送交接记录。
