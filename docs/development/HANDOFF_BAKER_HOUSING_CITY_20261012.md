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

## 当前交付状态

- 安装前后全量 Preferences 各 266 个，逐文件 SHA-256 完全一致：无新增、删除或改变；真实 `mistport.player-test-01-15.plist` 与盲玩 `mistport.player-test-01-15.audit.plist` 均保持原字节。证据在归档 `preferences-install-report.json`。
- 静音隔离启动使用 `-MistportCityMute YES --developer-tools --baker-board-review`，iOS 返回 `Locked`，未成功启动；没有执行隔离演练或真实任务刷新。镜像经过重连、重试与重开仍提示“未找到 iPhone”。已请用户在 Mac 附近解锁一次再锁屏、确认蓝牙／Wi-Fi，以恢复镜像。
- **面包师任务尚未重开**；当前仍保留玩家已完成 `d3-baker` 的状态。不能把源码支持和规则测试写成真实档已刷新，更不能把住房导航源码修复写成新版真机视觉验收。
- 下一步：恢复镜像，先在独立 review suite 实测委托板只读、前往实际面包师才能交付、待办慢走／完成离场，以及住房各页上下边界一致／无旧页露出；再逐文件检查真实与盲玩档未变。随后再次备份最新 Preferences，正常真实玩家模式静音启动 `--refresh-baker-errand`，确认 `BAKER_REPLAY_READY` 并读回目标任务仅 done=false、replayWithoutReward=true，保留原收益和其他进度。不要在真实档完成重试，留给用户测试。
- 已建档 `build-manifest.json`，记录最终二进制 SHA-256、上轮提交、流水线、最终宿主日志和测试日志。首次发布时真机视觉核验／面包重试刷新仍待完成，盲玩仍暂停。
