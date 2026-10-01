# 交接：墙关调数、按天推进、每日玩法与共享服 · 2026-09-30（第六轮）

## 现在在哪（2026-09-30，先读这一节）

### 2026-10-01 新增

- **各页米色纸面铺到底**：用户指出警察厅正文下面深色留白，要求各处铺成上方米黄色。继续在 [PR #42](https://github.com/andrewlinbridgeedu-droid/port/pull/42)（可审，未合并）修改：`GameArtPaperScroll` 使柜台、通用纸面页及日刊／附刊填满正文区域，并覆盖底部安全区。保留深色标题栏、金边按钮和原画，报馆人员切换文字改为墨色。[28 张新版模拟器截图](return-buttons-20261001/paper-review.html) 已逐张观察，包含 20 张首屏和 8 张长页滚到底；最终编译通过，[验证记录](return-buttons-20261001/paper-validation.json)。滚到底由隔离 DEBUG 参数定位，不是手动手势证据。**未装机、未访问手机 Preferences、未作真机验收，未改玩家存档、规则、原画、Unity 或 SSD 链接。**下条 25 张图为铺底修正前的返回按钮历史记录。
- **港城返回按钮统一**：用户认可警察厅的金边切角“返回港城”，要求报馆及其他页面一致。[PR #42](https://github.com/andrewlinbridgeedu-droid/port/pull/42)（可审，未合并），独立分支 `codex/unify-return-buttons-20261001` 从最新 main `758d409` 开始，`GameArtReturnButton` 复用原有柜台按钮样式；报馆改为“返回港城”，附刊、角色、行囊、构筑、街区、教会、战斗标题栏等复用，返回上一级仍显示对应文字。回调、教学退出限制和结算逻辑保持原样；构筑页攻略文字挤压已修正。[范围与验证](return-buttons-20261001/README.md)、[25 页模拟器原样截图](return-buttons-20261001/review.html)。正式 Swift 源码在隔离 iPhone 13 模拟器宿主编译通过，逐页检查默认字号；宿主不含 Unity，战斗图仅证明标题栏布局。**没有装机、没有访问手机 Preferences，未作真机验收；没有改规则、生产图片或 SSD 链接。** PR #41 的战斗／主角资源仍在原分支，本分支不包含它们。
- **Q4 猎犬出招像在散步**：用户真机反馈。原因是出招时走路循环照播，身体动作只动脖子和下颚 5–7°。Mac 任务单：[CODEX_TASK_Q4_HOUND_ATTACK_20261001.md](CODEX_TASK_Q4_HOUND_ATTACK_20261001.md)。
- **体力灯罩动画**：用户要求加动画，SwiftUI 实现在 [PR #38](https://github.com/andrewlinbridgeedu-droid/port/pull/38)，合入 H3 草稿分支 `codex/housing-h3-verification-20260930`。
  - 云端未编译，需要 Mac 构建并在真机上核对光晕是否对准灯罩玻璃。
  - 网页预览：https://claude.ai/artifact/XXKqCC5QV5optZpwLZY6og

### 第一章技能梳理（用户 2026-09-30 认可，云端已改规则）

- [技能梳理稿](../../mistport-ios/docs/game-design/chapter-one-30/SKILL_IDENTITY_REVIEW_20260930.md)，用户认可：
  - 错影追猎改名“双影追猎”；
  - 十件舞台道具；
  - “帷幕牌”卡牌样式；
  - 九种新签名和蜡、纸两种材质；
  - 后手改写补规则。
- 云端已改：
  - 双影追猎改名，覆盖规则库、App 对白和教学、现行设计稿、录制脚本标签；Unity 显示名留给 Mac。
  - 后手改写不带遗落物也生效：先净化一项敌方持续伤害（翠焰毒雾只降回初始浓度），再让下一张铺垫多 1 层误认。记忆蛭标本再净化一项、再多 1 层。
  - 规则库 559 项测试全过。墙关探针与 main 原版逐行一致。
- 未定：身份错置是否改名“张冠李戴”，遗落物是否改回“无主假面”。
- Mac 下一步：[卡牌与特效任务单](CODEX_TASKS_SKILL_CARDS_20260930.md)。先画 3 张样张交用户看。
- 另注：`progression-sim-20260929/walls-tuned/walls.txt` 是旧记录。现在 main 跑出来 Q18、Q26、Q30 裸打都输，最低塔层等于要求，与该文件不同。这个差异在本次改动之前就有。

### 最新地理修正（用户 2026-09-30 指定，优先）

- 首页原画左侧远景为高级住宅区，右侧远景住宅带为贵族区；贵族区很少能进去住，不列入常规租房卡片。住处规则中的 `highland_house` 对应左侧高级住宅区，不把右侧贵族区当作普通高档租屋。
- H1 的独立五区地图初稿被用户指出偏离港城地貌，已撤回，禁止接 App。改用首页全景原样缩览，区名和选房数据另外叠加；不改岸线、地势、道路、建筑或 15 张首页原画。见 [修正版地理提案](housing-art-20260930/map/geography-v2.json) 和 [预览](housing-art-20260930/map/geography-preview-v2.html)。位置仍待复看，特殊贵族入住条件尚未定义。

### 当前 Mac 任务：H3 169.13 已装，剩余镜像验证等待手机空闲

- H0 三张风格板用户“认可”，PR #32 已合 main；H1 [PR #33](https://github.com/andrewlinbridgeedu-droid/port/pull/33) 已合（`7b85f0f`）。H1 最终视觉认可仍待真机；地图用首页原样缩览，左侧高级住宅区可选，右侧贵族区不列普通租房。
- H2 [PR #34](https://github.com/andrewlinbridgeedu-droid/port/pull/34) 已合（`bfdb800e`）。赁屋行、五步租房、换餐、太平洋日付费、住房接口账本、体力回执、首页门牌／灯和高地入口已接；规则库 557 项通过。共享服时钟、真实房量和排队尚未接入，没有离线模式或旧存档迁移。
- H3 [草稿 PR #35](https://github.com/andrewlinbridgeedu-droid/port/pull/35)，分支 `codex/housing-h3-verification-20260930`，未合并。用户最新要求已修正 find/pest 和实际赶塔怪入口为 `errandThreeStep` 15 点；送货 10、传话 15。住房自检增加一项，直接执行四种生产委托入口，确认撤退重试不重复扣费。
- 租屋文案改为港城人物的说法；各任务入口保留规则库单次体力花费，嵌套页返回文字也已修正。用户随后明确要求合入 PR #38，该 PR 带入灯罩摇摆、雾、光点、飞蛾与点灯反馈，并恢复体力数字和回满提示；此前无数字的描述仅为历史状态。
- [PR #38](https://github.com/andrewlinbridgeedu-droid/port/pull/38) 已合入 H3（`5ba38b4`）。**当前签名 Debug 169.13** 已通过 USB 装入同一台 iPhone 13（iOS 26.6），真机住处 **22 项**及原有 **11 组**自检全部通过。紧接安装前备份 **229 份** Preferences，装机／自检后的中途核对为 **246 份**：真实玩家与 audit 逐字节不变，仅两个隔离测试 suite 改变，17 个新文件均为自检 suite；整轮剩余测试结束后还要再次核对。较早玩家备份已有差异，不追认旧安装核对，原始文件只留 SSD、不反写手机。
- **169.12 历史手动证据**：从首页实际点击五步租屋、逐层返回、三个室内细节点、滚动换餐与封蜡已完成，[19 张原样手动图](housing-app-20260930/device/manual/)含四帧封蜡。它们不代替 169.13 的灯罩、首页小灯和任务花费新图。
- **修订前证据**：此前 169.12 已装 iPhone 13（iOS 26.6），住房 21 项＋11 组自检真机通过，11 张 1170×2532 阶段图，原有 194 份 Preferences 逐字节不变、新增 18 份隔离测试 suite。编号相同不代表内容相同，旧证据不能证明本次修订。原始备份仅在 SSD，不反写真实存档。
- 新增 DEBUG `--housing-manual-record`，仅记录隔离账户手动点击后的页面、细节点和四帧封蜡，原样导出；没有自动点击／切页。不能用阶段跳转图冒充手动流程。
- 169.12 曾发生环境音 Core Audio 崩溃；PR #38 增加输出时钟与路由／中断恢复。169.13 在未传静音参数时观察到扬声器输出推进，未出现本轮新崩溃报告，但角色覆盖页不触发首页退出，不能计入十次。手机被其他操作切页后，用户表示先用手机，镜像操作已停；**十次主线地图往返、受控 App 切换、三种灯罩新图、十秒手动点灯录屏与光晕检查均未完成**。用户没有耳机，插拔未测。见 [音频记录](housing-app-20260930/device/AUDIO-MIRRORING.md)。
- PR #35 保持草稿。补齐剩余真机证据和最后 Preferences 核对后再转可审；用户视觉认可之前不合并、不记 H3 完成。按用户顺序，之后才从最新 main 开 Q3／Q4 猎犬动作分支；任务单已阅读、尚未修改 Unity。复现与范围见 [H3 记录](housing-app-20260930/VERIFICATION-H3.md)。
- 15 张首页原画、原灯光保持不变，城市委托贴片继续禁用。构建低于 170，DerivedData／归档在 SSD，不动链接；真实玩家 Preferences 不豁免。

### 分支

- 本轮云端的工作已通过 [PR #23](https://github.com/andrewlinbridgeedu-droid/port/pull/23) 合进 `main`：
  - 共享服 M0 技术小样；
  - 用户授权代定的经济与选型；
  - EC2 部署清单；
  - 台阶大道不加路灯；
  - 本交接。

  新会话从 `main` 开始。PR #22 已同步本轮 main 后合并，没有冲突。
- [PR #22](https://github.com/andrewlinbridgeedu-droid/port/pull/22) 的**喷泉、货场第三版已由用户在 2026-09-29 明确认可，并合入 main（`1f6a859`）**。当前交付为 12 张透明贴片、30 幅离线对比，未接 App、未装机；不新增路灯。认可原话、图稿哈希及运行时状态见[认可记录](commission-decals-20260929/art-approval.json)。
- **用户合并后明确：图稿先只保存在仓库，等城市贡献度第 4 档的“城市委托”（`.cityCommission`）功能做进 App，玩家完成对应委托并保存完成状态后，才显示对应首页贴片。**美术认可、PR 合并或达到第 4 档本身都不会直接显示变化；当前 12 条坐标继续 `enabled:false`。本次只补充交接与显示条件，不接 App、不装机。

### 本轮做了什么（云端，Linux）

1. **共享服 M0 技术小样**（用户定“做共享服”）。[记录](shared-server-m0-20260929/README.md)。
   - 规则库 `ChurchBattleDriver.swift`：
     - `MPCChurchBattleStepper`：教会系战斗（塔层、通缉、街头战、亮灯公共目标）50 毫秒一格推进，只收玩家的五种操作，并返回给 Unity 播放的事件；
     - `MPCChurchBattleDriver`：录制和复算操作记录。
     - 规则库 534 项测试全过。
   - 服务端 [`mistport-server/`](../../mistport-server/README.md)：Swift、Hummingbird 2.17、SQLite，16 项测试全过。
     - 账本：铜的发行、转账、销毁分开记；物品批次带来源；操作号防重复；挂单托管、钱货一次交换（40 人抢最后一件只成一笔）。
     - 战斗：开战前从城市预算预留奖励；服务器用自己保存的角色复算操作记录，确认打赢才付，只付一次。
     - 另有本地铜带入和审计。
     - HTTP 端到端跑通了“一笔交易＋一场亮灯公共目标”。
2. **用户说“你帮我定”，以下已代定**。依据见[共享服经济判定“定案”](shared-economy-decisions-20260929/README.md)。
   - 经济：保留 24/12，单机数值不动。共享服每日玩法按单机的 15% 付，由城市预算出（城市预算每天最多从 NPC 销售额收 20%）；玩家每个活跃日买一份篮子。
   - 没选“NPC 物价乘 16”：在那个量级下模型测不出通胀，而且每天一份篮子会让三到五成玩家低于恢复线。
   - 本地铜：最多计 12,000，按 15% 折成共享铜，服务端已实现。
   - 其他数值：交易费 5% 进城市预算；亮灯公共目标奖励 12 铜。
   - 定案复核：9 个情景全部过线。但玩家每天买篮子以后，价格线挡不住小额凭空发币，所以通胀监控以账本按来源的发行为主，价格只作辅助。
   - 服务端选型：Swift＋SQLite 单服务；Caddy 或已有网页服务做 HTTPS，Litestream 备份到 S3；扩到 2,000 注册前压测，不过线再换 PostgreSQL。
3. **部署用现有 EC2**（之前生成 4K 酒馆图用过的那台 Ubuntu），**现在不用改任何设置**。M2 小服开测前要改安全组、弹性 IP 和域名、S3 备份权限等，清单在 [M0 记录](shared-server-m0-20260929/README.md#部署到-ec2-时要改的设置m2-小服开测前做现在不用动)。云端连不到这台机器，要由有 SSH 权限的人操作。
4. **台阶大道不加路灯**（用户定）。城市委托第一批街景改为喷泉、货场两处。原任务单“一排 4–5 盏”是写任务单时加的细节，不是用户的要求。设计稿 6.5 节和[城市贡献度任务单 2.5 节](CODEX_TASKS_CITY_CONTRIBUTION_20260929.md#25-城市委托的街景贴片画景色)已改。

### 用户 2026-09-30 的新决定（先读）

- **没有单机，只有共享服。**以前“单机”“共享服按单机 15% 付”“单机存档带入”的说法都要重新理解，见下一轮；在这之前不要按“单机、共享服两套”继续实装。
- 服务器的一天从太平洋时间零点开始（`America/Los_Angeles`），已改进服务端。
- 装备和遗落物可以交易。
- **加急委托、街区难题、城市委托在第一章不给铜**，改给好感、贡献度和外观；第一章之后给铜（数额随“只有共享服”后的经济重定）。
- **主线 Q1–Q30 的战斗也搬进规则库，由服务器复算**：云端已完成规则库和服务端部分（[记录](shared-server-m0-20260929/STORY_BATTLE_V1_20260930.md)，规则库 550 项、服务端 22 项测试全过，调数结论几乎不变）。App 改用推进器交给 Mac 上的 Codex（共享服任务单 2.5 节）。
- **铜币数额**：用户让“计算一个最合理的”。结果见[只有共享服时的铜币方案](shared-only-economy-20260930/README.md)：
  - 一次性奖励总额不变，Q3、Q5 首通各 +100，Q26–Q30 各 −40；
  - NPC 价格不变；
  - 每日玩法付 15%；
  - 送信只在恢复线以下能做，每天 1 单；
  - 加一个每天 12 铜的基本篮子（新机制，形式待用户定）。
  - 两套模型都过线，App 还没改。
- **旧存档不迁移，所有人从头开始**；**不能离线玩**（用户 2026-09-30 定）。
- **加每天的基本篮子，并扩展成住处、饮食和体力系统**，还要有富人区专属任务、雾港建筑文化和找住处界面（Codex 画）。设计稿见 [HOUSING_STAMINA_ARCHITECTURE_20260930.md](../../mistport-ios/docs/game-design/chapter-one-30/HOUSING_STAMINA_ARCHITECTURE_20260930.md)。用户已认可体力节奏、住处饮食档位和价格、富人区任务奖励、雾港三层建筑；找住处另开房屋中介“赁屋行”。已完成：
  - 服务器模型加住处档重跑：9 个情景全部过线，发行量不变；
  - 模拟器加体力和住处自选：第一章 9／9 按时通关；
  - 规则库 `HousingStamina.swift` 已写好，555 项测试全过。

  见 [housing-economy-20260930](housing-economy-20260930/)。房屋中介改名“赁屋行”（用户定）。Mac 上的实装见 [Codex 住处任务单](CODEX_TASKS_HOUSING_20260930.md)：先画 3 张风格板给用户认可。
- 用户要等全部接进游戏再测。

### 接下来

**Mac（Codex），按顺序：**
1. 首页任务 1 真机收尾：截图、11 组 DEBUG 自检、Preferences 比较，交用户看。
2. PR #22 美术已获用户认可并合入 main，图稿先留仓库：
   - 当前交付及 `commissionDecals` 中的大道新增灯和全部配套光效已移除；旧稿只留历史目录，不参与显示。
   - 等第 4 档“城市委托”功能做进 App 后，再按存档里对应委托的完成状态显示喷泉、货场贴片。App 接入与装机是后续任务；当前 12 条坐标继续 `enabled:false`，`reviewStatus:user-art-approved`。
3. [首页任务单](CODEX_TASKS_HOME_MAP_20260929.md)的任务 2（送信）、任务 3（B07 六环）。
4. [城市贡献度任务单](CODEX_TASKS_CITY_CONTRIBUTION_20260929.md)第 1 步（记分和迁移）；第 2 步（按档开放）等送信做完。
5. [共享服 App 任务单](CODEX_TASKS_SHARED_SERVER_M0_20260929.md)：
   - 先把 App 教会战斗的现行规则搬进 stepper，已列出 6 处差别；
   - 再让 App 由 stepper 推进，Unity 只负责播放。

**2026-09-30 云端已完成：**共享服 App 任务单第 1 步。App 的教会战斗规则（8 处差别）已经搬进规则库推进器，规则版本改为 `church-battle-v2`；塔层验证模型和模拟器都改走推进器；调数结论不变。见 [v2 记录](shared-server-m0-20260929/CHURCH_BATTLE_V2_20260930.md)。Mac 上接着做任务单第 2 步：App 改用推进器。

**2026-09-30 云端已完成：**三类新内容的铜币重算（[记录](city-contribution-economy-20260930/README.md)）。单机没问题；共享服第一章阶段照给，“供给减半”情景不过线。建议共享服第一章不给铜，等用户定。

**2026-09-30 云端已完成：**服务端按天放开（塔层首通每天 4 层，开打前拒绝，旧库自动升级；服务端测试 20 项全过），以及[共享服角色成长设计](shared-server-m0-20260929/CHARACTER_GROWTH_DESIGN_20260930.md)（提案，4 项待用户定）。设计里记下一个漏洞：服务端重打已通关的楼层，每赢一次都掉材料，没有上限，M2 前必须补。

**云端也能做：**

### 还要用户定或认可

- 首页标注位置（在任务 1 的真机截图上复核），以及首页、柜台分层、八方向行走、底栏缩小的真机认可。
- **每天的内容时长**：模拟器估算一般速度每天只有约 12 分钟正经内容，离“每天 1–2 小时”差很远。改目标（例如每天 15–30 分钟）、加内容，还是两者结合，还没定。见[人类计时记录](human-timing-20260929/README.md)。

### 没验证的

- 共享服：
  - App 没接；驱动器现在和调参模型一致，和 App 不一致；
  - 服务器上的角色是运营工具设的；
  - 没有正式登录、TLS、限流、备份演练和压测。
- 经济判定都是模型结论，不是游戏实测，也不能证明不会通胀。
- 本轮没改 App 代码，不需要在 Mac 上重新编译。

## 2026-09-29 深夜的状态（历史，已由上一节更新）

`main` 已包含：
- 首页港城设计稿（含城市贡献度第 6 节）；
- 城市贡献度规则库；
- Codex 的首页任务 0 和任务 1（PR #19，Build169.10）。

合并后 Linux 上规则库 526 项测试全部通过。

**已完成：**
- **首页任务 1 已合入**，但真机验收还没做完：
  - 169.10 已装 iPhone 13，但手机锁屏，新版截图和最终 11 组 DEBUG 自检都没做。
  - 装机前后 194 份 Preferences 逐字节一致。
  - 用户还没在真机上认可首页、柜台分层、八方向行走和底栏缩小。
  - 详见 [任务 1 记录](home-map-task1-20260929/README.md)。
- **城市贡献度**：用户已确认门槛 120／220／300、四档名称和各档开放内容。
  - 规则库 `CityContribution.swift` 已写好，App 没接。
  - 街景变化用小块贴片，不重画 15 张首页原画（设计稿 6.5）。
  - 用户最新明确**不加灯，只做喷泉和货场，变化要更明显**。大道新增五盏灯及所有配套光效／顺序图已撤回，原画既有灯不变；旧稿仅留历史目录，不得接入。分支 `codex/commission-decals-20260929` 从 `485b5d6` 起步。
  - [草稿 PR #22](https://github.com/andrewlinbridgeedu-droid/port/pull/22) 第三版：喷泉重画更饱满、色块更清楚的花带，保留三串彩旗；货场帆布用绳环挂原吊臂，锚记更清楚，较大的封签货箱堆移到前景空地。两处的旧稿／新版及手机宽度对比见[图稿目录](commission-decals-20260929/README.md)，仍待用户看图确认。
  - 本版普通／冬雪三时段共 12 张 512×512 RGBA、30 幅贴前／贴后对比；15 张首页原画 SHA-256 全部一致，PNG/JPG 按 LFS 提交。`commissionDecals` 仅留两处的 12 条禁用坐标，去掉大道及 `lighting.ground`；图片留在 docs。**未接 App、未构建、未装机、未合并 PR**。另一位 agent 的前次意见是补地面光晕，没有要求更多灯；最新“不加灯”指令优先。

**接下来（Mac 上的 Codex）：**

当前先把这批街景图交用户确认；确认前不接 App、不装机。以下旧任务保持待办。

1. 亮屏后补做任务 1：真机截图、11 组 DEBUG 自检、最终 Preferences 比较，交用户看。
2. 首页任务单的任务 2（送信）、任务 3（B07 六环），见 [首页任务单](CODEX_TASKS_HOME_MAP_20260929.md)。
3. [城市贡献度任务单](CODEX_TASKS_CITY_CONTRIBUTION_20260929.md)：
   - 第 1 步（记分和迁移）可以先做；
   - 2.5 节本批按用户最新要求只画喷泉和货场，不加路灯；两处先交对比图确认。原三处提案在[任务单 2.5 节](CODEX_TASKS_CITY_CONTRIBUTION_20260929.md#25-城市委托的街景贴片画景色)，新增灯部分已由本次指令撤回；
   - 第 2 步（按档开放）等送信做完再做。
4. 世界事件服务区、委托板上的街坊委托改流程，留到下一单。

**还要用户定：**
- 首页标注位置在任务 1 真机截图上复核；
- 共享服财富上限 12,000；
- 街景贴片两处美术的视觉认可；本批不加灯已明确。

**注意事项：**
- 任务 1 让资源包从约 422 MiB 涨到约 487 MiB（分层柜台和新人物），要留意包体。
- 加急委托、街区难题、城市委托三类新内容的铜币还没进经济模拟。

## 首页港城任务 0：Mac 编译与真机坐标核对

基线 main `7e3731a`；518 项核心测试、两次 iOS Debug 构建与 11 组真机 DEBUG 自检通过。Build169.1 已装 iPhone 13，真实玩家 Preferences 逐字节不变。两张 LFS 标注图、三段首页原始截图和叠图见 [任务 0 记录](home-map-task0-20260929/README.md)。发现广场、货场部分路径穿墙及固定岗位偏离入口，用户已授权按实际路面修正，任务 1 提供新叠图复核；此记录不代表用户认可最终界面。


## 首页港城任务 1：地图、人物与柜台分层（已合入 main，PR #19；真机验收未完成）

分支 `codex/home-map-task1`，基线 `d39e0ed`。用户后续要求包括路线修正、八方向行走、前后景人物比例、日刊移报社及原生报纸文字、店主与莫尔少量全城外出、柜台美术和四枚图标略减。所有柜台固定无人的背景，换人只换透明人物，并保留柜台前景遮挡；已接入地图层、八个柜台、报馆、咖啡馆、餐厅与酒馆。合入最新 main `931a81a` 后 526 项规则测试通过。最新要求把任务条移到地图底部、导航栏上方，并将底栏图标、文字、间距和内容高度整体再缩小 10%；Build169.10 已构建并安装，系统应用清单确认版本。安装期间手机再次锁屏，系统拒绝启动，新版真机截图与最终 11 组自检尚未完成。169.10 安装前后 194 份 Preferences 全部逐字节一致。用户已重新要求推送当前分支，此次布局和验证记录一并提交。任务 1 已通过 PR #19 合入 main；送信及 B07 六环还未实装。记录见 [任务 1](home-map-task1-20260929/README.md)。

## 最新（2026-09-29 夜）：首页港城设计定稿

首页港城与街头任务的设计已由用户定稿（[设计稿](../../mistport-ios/docs/game-design/chapter-one-30/HOME_MAP_STREET_TASKS_20260929.md)），Mac 上的实装见 [Codex 任务单](CODEX_TASKS_HOME_MAP_20260929.md)：先编译并生成标注图，再做首页地图层、送信、B07。

城市贡献度（设计稿第 6 节）：规则库 `CityContribution.swift` 和测试已写好，全部 522 项规则测试通过（Linux）；进度模拟器已在各结算点记分（`contributionByDay`、`contributionTierDays`）。App 接入见 [Codex 任务单](CODEX_TASKS_CITY_CONTRIBUTION_20260929.md)，排在首页任务单之后。门槛 120／220／300 已由用户确认。

## 第五轮：用户决定与云端改动（2026-09-29 晚）

用户的决定：

1. **教会 Q7 后开放**（深井、通缉、教会工作）。
2. **真人计时改用模拟器来做**。
3. **共享服经济的几项候选用模拟计算来定**（已完成，见下文）。
4. **`codex/profile-ui-fixes-20260929` 先开 PR 合并**：已作为 PR #14 合进 `main`，没有冲突；该分支只做过类型检查，没装机。
5. **其余 15 名街坊的委托和小故事补写完**。

本轮云端改动（规则库 518 个测试全过；App 只做了语法解析，**没编译、没装机**）：

- **教会 Q7 后开放**：
  - 规则库：`MPCChurchTowerCatalog.isUnlocked` 改为完成第 7 关或之后任意一关，新增 `lockText`；`todaySummary` 在 Q7 前显示“深井在第 7 关后开放”。深井首通额度仍从第 1 天起每天 4 层累积，第 5 天一开就有 20 层。
  - App：`cityServiceIsUnlocked(.church)` 同一判断，教会页和日刊的深井、通缉两行显示锁定原因。
  - 自检夹具（新档直接进教会的地方）已改：`verifyChurchTower`、`verifyDailyPacing`、`verifyDailyWorkshopIntegration`；按天推进走查默认档改为第 5 天、Q1–Q7 已打、今天 20 层已用。
  - 模拟器的 `churchOpen` 改为调用同一规则。**Mac 上要重跑 11 组自检。**
- **23 名街坊都写好了**：每人 3 条委托、2 段小故事。23 人按固定顺序轮流上门（`MPCNeighborCatalog.rotation`），小故事改在好感 2、3 解锁（原 3、6）。
  - 街头乐师仍是第 7 天第一次上门（赶塔怪），走查夹具 `--daily-street-kind=pest` 不受影响。
  - App 里对话页的好感提示改为读规则库常数；`verifyNeighborsIntegration` 的“人人两段故事”断言改为按好感核对。
- **人类计时模拟器**：[记录](human-timing-20260929/README.md)（`ProgressionSim human`）。
  - App 的技能是自动出招，所以人的差别在战斗外。
  - 按现有内容，一般速度每天约 12 分钟正经内容、全章约 6 小时，**离每天 1–2 小时差很远**；要填满 1 小时得每天再刷 12–18 单巡检/维护。
  - 邮务一单约 20 秒，不是原假设的 150 秒。
  - 结论需要用户定方向（改目标或加内容）。
- **共享服经济判定**：[记录](shared-economy-decisions-20260929/README.md)，脚本在 `tools/economy-decisions/`。模型结论，未实施。
  - 用 V3 整服模型跑了 870 局，另在 2000 账户市场模型上测了交易费和本地财富带入；验收线和判定规则先写进脚本再跑。
  - 结果：
    - 每日玩法的铜在共享服由城市预算付，只付得起单机的 5%；玩家每天买一份篮子时可到 15%。照单机全额发会通胀，开放服务价格峰值 2.1–2.3 倍。
    - 保护篮子覆盖每活跃日一份。
    - 价格验收用严格线：1.25 倍／15%／15%。
    - 地下委托 560 铜可以加。
    - 银行与投资不进首版。
    - 恢复基金维持 96 万。
    - 交易费 5%。
  - **待用户定两件**：
    - 单机每日玩法一天约 142 铜，是 12 铜篮子的 12 倍。三个选项：共享服打折、NPC 物价乘 16、单机本身降下来。
    - 本地财富带入：用户已定**带进共享服**（上限暂按模拟支持的 12,000 铜，待确认）；本地存档可被改的风险由用户接受。
  - 过程里修过三个模型问题：
    - 预算多收的钱闲置在国库，NPC 缺钱。
    - 多收的钱全付给了 NPC 家庭，结果税越高越稳。
    - 交易费判定把两个负数的比值算反。

## 第四轮最新状态：Build169 与设备断线（2026-09-29）

任务0、1.1–1.7的实现已逐项通过PR合并。任务1.8本轮修复真机街道空白：统一离线资源根目录和文件路径规范化，避免`/private/var`与`/var`误判。三类街头战在较早169候选取得胜利和清晰帧；最后169包安装后168份Preferences全一致，地图23人加载及实际到达邮差回调通过。随后iPhone断线，地图图片未取回、收话人实走、最终包三场复测/全套自检/测试后存档复核未完成。不要把本轮标成完整视觉验收通过。

证据、初次安装前后引导标记变化的失败记录、后续比较、待连接步骤见 [1.8设备检查](daily-device-review-20260929/README.md)。真实玩家存档未回灌或覆盖；无法归因的引导标记变化不能被后续比较通过抹去。最近完整规则回归仍是518项/92 suites，11组App自检在Build168通过。

任务2无真人正常玩法计时样本，未替换模型数字。已交付[采集模板、校验器与经济研究](daily-timing-research-20260929/README.md)：16类各至少3次，当前48条样本均缺；5项校验测试通过。预算脚本仍混有候选内容，正式计时与更新压力模型未完成。用户视觉认可、教会开放口径决定仍未收到。以下各构建条目保留历史，不代表最终全部验收状态。

## Mac 最新验证（2026-09-29）

任务 1.2 工坊已接入，当前 Build 164；新工坊自检、旧检修流程17项检查及原六组自检通过，真实玩家仅新增工坊账本键。见 [工坊接入记录](daily-workshop-app-20260929/README.md)。事件效果读取接口已预留，随任务1.4账本接通；后续日刊/事件/街坊/残余案、真机计时未完成。

任务 1.1 已接入四类重复工作递减，新增独立账本及迁移回执，Build 163 真机六组自检通过；同时补齐任务 0 的塔战直接开战日额度检查。见 [任务 1.1 记录](daily-work-app-20260929/README.md)。当前仍未取得用户视觉/手感认可，任务 1.2–1.8、2 待做。

每日玩法任务 0 已完成编译、自检及存档差异核对，Build 161 已装 iPhone 13；516 个规则测试及五组 DEBUG 自检通过。修正深井地图层号未按每日额度变灰的问题。详情、截图、真实旧档通缉迁移的额外变化和待用户验收项见 [任务 0 记录](daily-loop-task0-20260929/README.md)。以下云端“未编译”记录保留为历史，不代表当前构建状态。

接手前按顺序读：本页 → [共享服 M0 记录](shared-server-m0-20260929/README.md) → [共享服经济判定](shared-economy-decisions-20260929/README.md) → [每日玩法第二阶段记录](daily-content-phase2-20260929/README.md) → [第一阶段记录](workshop-phase1-20260929/README.md) → [每日玩法与经济设计](../../mistport-ios/docs/game-design/chapter-one-30/DAILY_LOOP_AND_ECONOMY_20260929.md) → [按天推进报告](progression-sim-20260929-daily-pacing/README.md) → [第二轮调数报告](progression-sim-20260929-tower-check/README.md) → [第一轮调数报告](progression-sim-20260929/README.md) → [HANDOFF_PROGRESSION_UI_20260928.md](HANDOFF_PROGRESSION_UI_20260928.md) → [HANDOFF_M0_20260928.md](HANDOFF_M0_20260928.md)。回复用户用中文。

## 仓库与分支

- **工作仓库：`github.com/andrewlinbridgeedu-droid/port`**（用户 2026-09-29 定为以后唯一的工作仓库）。换 Claude 账号也可以继续：新账号连上有这个仓库权限的 GitHub 账号，开会话时选这个仓库，先读本页。
- **从 `main` 起步。** 2026-09-29 已通过 PR #1 把所有分支的工作合进 `main`（合并提交 `9b62e55`）。新会话从 `main` 开始，`claude/world-economy-m0`、`claude/world-economy-m0-u62oho` 都已并入。`claude/nifty-planck-80307c` 在 2026-09-30 的工作也已由 PR #23 合入。
- 第一轮交接提到的 `showcase.py` 冲突已合好（保留 PIL 画字，字体优先用 main 选的华文黑体）。

## 第四轮：按天推进第二步（App 接入，云端写，没编译）

- 规则库 `DailyPacing.swift` 新增 `MPCDailyPacingStart`：存档的第 1 天，只写一次。没有记录时，有主线或塔进度的旧存档按 `migratedStart` 迁移（`origin = .migrated`，`recordedAt` 就是迁移回执），没有进度的新档记今天。另有 `missionLockText`（“第 N 关明天开放”／“N 天后开放”）、`towerLockText`、`todaySummary`。新增 2 个测试，规则库 **516 个测试全过**（云端 Linux；读地图文件的街坊测试需要保持仓库目录结构才能跑）。
- `GameStore.swift`：
  - 存档键 `mistport.daily-pacing.start.v1`；`init` 末尾（所有进度和重置参数处理完后）调用 `resolveDailyPacingStart()`，旧档在这里迁移一次。
  - `missionIsAvailable`：未通关的关要 `isMissionOpen`；已通关的重打不受限。发奖路径（`settleActiveMissionRewards`）没有加任何判断，打赢一定发奖。
  - `enterDistrictMap`：下一关还没开放时回城，不再停在黑屏地图。
  - `churchTowerSession`：新层要 `towerFloorIsOpenToday`；已封堵的层随时重打。
  - `restart()` 清掉记录并按新档重记；`debugJumpToOldClockMission`（工坊、第二章走查存档用它播种）清掉记录后按迁移重记，下一关当天可打。`--reset-to-chapter-one-q3/q4` 的清理列表里加了这个键。
  - DEBUG：`debugSetPacingDay(_:)`；`verifyPlayerGrowthPersistence` 改为先断言 Q30 在第 1 天锁住、推到第 40 天后可打；新自检 `--verify-daily-pacing`（新档第 1 天、Q4 明天、重打、次日、重开、深井每天 4 层、旧档只迁移一次、重开新档），通过时打印 `DAILY_PACING_VERIFY_PASS`。
- 界面：城市页“下一关”标题在锁住时显示“第 N 关明天开放”（`ContentView.swift`）；深井页（`ChapterOneTestView.swift`）新层按每日限额禁用并显示原因，胜利页的“下一层”按钮同样判断。任务板上锁住的关沿用原来的“未开放”样式，没有单独写原因。
- 只做了 `swiftc -parse` 语法检查，**没有类型检查、没有编译**。`todaySummary` 还没放到任何界面上。

## 用户 2026-09-29 的决定（第三轮已实装）

1. Q18、Q26 不是墙 → 先选“拉陡塔装备曲线”；实测需要每 20 层战力翻倍后，改为**塔层装备检定**，曲线只温和拉陡。
2. 验收第 3 条改为“只做通缉卡在 Q8”。
3. 通缉战败只扣铜，不再丢随身遗落物。
5. **按天推进**：玩家不能靠投入更多时间取得领先，多玩只能多赚铜币；按每天 1–2 小时、约 30 天打完第一章设计。验收第 4 条改为这个时间预算。用户同意分两步做：第一步规则和模拟器（本轮已完成），第二步 App（见“下一步”）。
4. 验收第 4 条只算过墙必需的支线。

## 本轮完成

- **塔层装备检定**：Q18 第十三击、Q26 押运车猛砸、Q30 总签官猛砸，身上没有来自 F50/F70/F90 或更深的塔装备时按基础生命 140% 结算。新字段 `MPCChurchGearStats.towerDepth`，判断在 `MPCProgressionWalls.meetsTowerFloor`，数值在 `towerCheckBlowHealthPercent`。
- **塔装备曲线**：F2–F10 不变；F20 起每 10 层约 +10% 攻击，护甲生命和减伤同步加快（表见报告）。
- **机制墙跟着加重**：Q12 强化上限 95%；Q22 失败重击 140% 生命、钟匠 5000 血；Q30 总签官 6500 血。
- **Q18、Q26 这一仗本身加压（用户要求）**：裁定者 5200 血 / 140 攻，押运车 5600 血 / 150 攻。满足塔层后中熟练首次剩 36%、37% 血（原 65%、53%），检定不变。
- **通缉战败只扣铜**：`MPCBountyDefeatRisk` 不再返回遗落物；App 两处说明文字和风险自检已改。
- **失败提示**：`defeatHint` 新增 `wornTowerDepth`（App 调用处已传），打到过要求层但身上装备不够深时，提示换装备。
- **测试**：规则库 472 个全过（云端 Linux）。新增 `towerWallsNeedTheirFloor`、`towerDepthComesFromTheDeepestWornPiece`；三个旧测试随改动更新。
- **模拟器**：新打法 `hinted`（按失败提示只补必需支线）；止痛膏重试改为换整套打法（修正了第一轮“低熟练卡 Q8 是因为丢遗落物”的误判，真正原因是机器人总把唯一一瓶药用在同一套会输的打法上）；探针新增 `GEAR_SCALE`，`WALLS=` 新增三个检定键。
- **验收**：六条全过（第 4 条有分母口径说明，见报告）。

| 关 | 状态 | 要求 |
|---|---|---|
| Q3 | 放宽（不是墙） | — |
| Q8 W1 | ✅ 数值墙 | 塔 F10 |
| Q12 W2 | ✅ 机制墙 | B01 七号缺齿剑 |
| Q18 W3 | ✅ 塔层检定 | 身穿 F50 或更深的塔装备 |
| Q22 W4 | ✅ 机制墙 | B04 伪造者倒签笔 |
| Q26 W5 | ✅ 塔层检定 | 身穿 F70 或更深的塔装备 |
| Q30 W6 | ✅ 塔层检定＋机制墙 | 身穿 F90 或更深的塔装备 ＋ B10 绯月寿账签 |

## 按天推进（第三轮，第一步已完成）

- 规则：`DailyPacing.swift` 的 `MPCDailyPacing`。第 1 天开 Q1–Q3、之后每天一关（Q30 在第 28 天）；塔首通每天 4 层、可累积；旧存档用 `migratedStart`。只是判断函数，**还没接进 App 的开战和领奖流程**。新增 4 个测试（规则库共 476 个）。
- 模拟器：主线、塔首通按天开放，逐天记时长，`PACING=` 可临时改参数，`report.py` 输出按天推进表。原“每天打 3 关”的假设已删除。
- 结果：所有熟练度都在第 28 天打完；边推主线边爬塔时单日战斗最长 20–79 分钟、平均 5–9 分钟。

## 需要用户定的

- **第一天已改为开 Q1–Q3**（用户定），Q30 在第 28 天开放；模拟结果改为第 28 天打完。
- **每天剩下的时间怎么填**：已写[每日玩法与经济设计候选](../../mistport-ios/docs/game-design/chapter-one-30/DAILY_LOOP_AND_ECONOMY_20260929.md)（估算脚本 `tools/daily-loop/budget.py`），用户已定（第 8 节）：工坊提前到 Q5 且可以出装备（档位对应塔层、穿戴要求打通该层、属性不超过同档塔装备、计入塔层检定、会磨损）；重复工作按单递减、功勋每天前 2 单；四场事件用设计稿主题；先做街坊委托和无名残余清剿。实施分期见第 10 节。**阶段 1 已完成**（规则库＋模拟器，[记录](workshop-phase1-20260929/README.md)）：`DailyWork.swift`（重复工作递减、功勋每天前 2 单）、`Crafting.swift`（塔材料、四个基础配方、十件工坊装备配方、制作账本、NPC 订单）、`ChurchGear.swift`（工坊装备：档位、穿戴要求、磨损修理、计入塔层检定），工坊开放改到 Q5。**阶段 2 已完成**（规则库＋第一批文案＋模拟器，[记录](daily-content-phase2-20260929/README.md)）：`CityEvents.swift`（四场本地世界事件，事件战每天最多记 2 场，成功改城市、失败只罚一周）、`RemnantCases.swift`（通缉结案后每天一个无名残余小案，铜走递减）、`NeighborErrands.swift`（23 名街坊每天 2–3 条委托，第一批 8 人有专属委托和小故事）、`StreetEncounters.swift`（街头战复用塔恶魔身体和塔战演出路径）。规则库 514 个测试全过。App 都还没接入。

- **模拟器的教会开放时间**（阶段 2 发现）：模拟器假设教会（塔、通缉）Q7 后才开，App 和规则库里教会一直开着。打完天数不受影响，但前几天的塔进度、材料和第 5 天的时长偏了。改不改请用户定，改了以后前几轮报告的单日最长会变。

## 没验证

- **iOS App 从 `cee125a` 起没编译过**，第四轮的按天推进接入也没编译（见上）。 阶段 2 改了 `GameStore.swift` 的工坊开放判断（阶段 1 只改了文字，按钮实际还要 Q16），改成和规则库一样“完成第 5 关或之后任意一关”，也没编译。 本轮 App 只改了：两处通缉说明文字、`verifyBountyDailyRisk` 自检、`wallDefeatHint` 多传一个参数。规则库里 `MPCChurchGearStats` 多了带默认值的字段。
- 没有真机、没有真人试玩；机器人熟练度只能相对比较。Unity 端没有塔层检定、Q12 叠层、Q22 校验失败、Q30 狂暴的专门演出。

## 下一步（按优先级）

**Mac 上的工作已整理成 Codex 任务单：[CODEX_TASKS_DAILY_LOOP_APP_20260929.md](CODEX_TASKS_DAILY_LOOP_APP_20260929.md)**（编译与按天推进验证、每日玩法阶段 3、真机计时与经济阶段 4）。


1. **每日玩法阶段 3（App，Mac）**：日刊；工坊界面接 `MPCCraftingLedger`、`MPCWorkshopOrderBoard`（带事件的 `bonus`、`surcharge`）和工坊装备的穿戴修理；事件板（交货、事件战入口、`MPCCityEventLedger` 的回执和结算）；地图上街坊的委托对话（`MPCNeighborLedger`，传话要走到收话人那里再调 `relay`）；残余案卷（`MPCRemnantLedger`，领奖走 `MPCDailyWorkLedger`）；商店止痛膏价加上 `effects(day:).salveSurcharge`；递减和“今天已记满”的提示。新账本都要进存档并有迁移回执，旧存档读入为空账本。街头战要在 Unity 里各看一场。
2. **按天推进第二步：在 Mac 上编译并验证第四轮的接入**。`xcodebuild` 修掉类型错误；跑 `--verify-daily-pacing` 和 `--verify-player-growth`；真机上先备份 Preferences，确认用户真实存档第一次打开时被迁移（下一关当天可打），并逐文件核对只多了 `mistport.daily-pacing.start.v1` 一个键。可选：把 `todaySummary` 放到城市页；任务板上锁住的关显示原因。
3. 交给 Codex（Mac）：拉 `main`，`xcodebuild`，按惯例备份 Preferences 后装机；看“封线装备”页通缉栏、通缉案卷的遗落物说明、墙关失败提示（含“换上深井第 N 层或更深的装备”）、通缉战败说明，以及几个新机制的实际手感。装机、编号、SSD、存档隔离规矩见 `HANDOFF_PROGRESSION_UI_20260928.md` 和 `AGENTS.md`。
4. 用户对上面两条可选项的意见。
5. 其余 7 件遗落物效果；第二章核心人物战、死亡与继任；服务端账户与可信战斗结算小样（2026-09-29 已在云端做出，见本页顶部“共享服 M0”）。

## 常用命令

```sh
# 规则库测试（Mac）
cd mistport-ios/MistportCombatCore && swift test
# 模拟器：六堵墙探针（约 5 秒）
swift run -c release --package-path tools/progression-sim ProgressionSim walls <输出目录> 8,12,18,22,26,30 high,medium,low
# 临时改墙值扫参数，不改代码
WALLS="q18GearCheckHP=160,q30SovereignHP=7000" swift run -c release --package-path tools/progression-sim ProgressionSim walls <输出目录> 18,30
# 估算塔装备曲线要多陡（只影响探针）
GEAR_SCALE="attack=2,hp=2,reduction=1.5" swift run -c release --package-path tools/progression-sim ProgressionSim walls <输出目录> 18
# 单关逐套打法；TRACE=1 打印每次敌人行动
swift run -c release --package-path tools/progression-sim ProgressionSim fight 22 medium 50 bounty_relic_b04_reverse_seal
# 串行全流程（约 1 分钟）与汇总（含按天推进表）；PACING= 临时改按天参数
# PACING="towerFloorsPerDay=3" swift run -c release --package-path tools/progression-sim ProgressionSim <输出目录> 0,30,90
swift run -c release --package-path tools/progression-sim ProgressionSim <输出目录> 0,30,90
python3 tools/progression-sim/report.py <输出目录>
```

可调键名见 `tools/progression-sim/Sources/ProgressionSim/Walls.swift` 的 `WallTuning`。

```sh
# 共享服服务端（Swift 6.0 起，Linux 需 libsqlite3-dev，首次要能连 GitHub 拉依赖）
cd mistport-server && swift test
MISTPORT_DB=./dev.sqlite MISTPORT_ADMIN_TOKEN=<至少16位> swift run mistport-server
# 共享服经济：定案复核（约 20 秒）与全部判定（约 6 分钟）
python3 tools/economy-decisions/final_check.py --out <目录>
python3 tools/economy-decisions/shared_decisions.py --out <目录> --workers 4
```

## 在 Linux 云端跑 Swift

官方下载被网络策略拦截。从 `archive.ubuntu.com/ubuntu/pool/universe/s/swiftlang/` 取 `swiftlang`、`libswiftlang` 的 6.0.3 deb（`6.0.3-2build1`），再从 `pool/main/libx/libxml2/` 取 `libxml2-16`（`2.14.5+dfsg-0.2ubuntu0.2`），`dpkg -x` 解到临时目录，设 `PATH=<目录>/usr/libexec/swift/bin:$PATH` 和 `LD_LIBRARY_PATH=<目录>/usr/lib/x86_64-linux-gnu:<目录>/usr/lib`。`S9TalentEditorTests` 里一个 `@MainActor` 测试在 Linux 的测试自动发现下编不过：跑测试时在临时副本里去掉这个文件，它只在 Mac 上跑。

每日玩法任务 1.4 已接入：城市事件板、交货和战斗回执、三处城市价格效果。当前装机 Build165；8 项自检通过，事件板四日期截图和存档比较见 `daily-city-events-app-20260929/README.md`。为使日刊入口都有实际目标，先做 1.4–1.6 再汇总 1.3。Unity 三类街头战演出复看、用户视觉认可及任务 2 正常游玩计时仍未完成。

每日玩法 1.5 已接入街坊委托和地图交谈桥接，当前装机 Build166；规则库 9 项、自检 9 项通过，真实存档只新增街坊账本。证据见 `daily-neighbors-app-20260929/README.md`。现行 3D 街道原有 12 人，本次对齐规则库 23 人；实际地图走近触发与赶塔怪 Unity 演出仍待 1.8 检查，不冒充视觉验收。

每日玩法 1.6 已接入无名残余案，当前装机 Build167；8 项规则测试、10 项 App 自检通过，真实存档只新增残余案账本。证据见 `daily-remnants-app-20260929/README.md`。普通记录保留 7 天；在途战斗及已胜未领报酬受保护。接下来汇总日刊（1.3）并执行 1.7/1.8；视觉认可和正常游玩计时仍未完成。

每日玩法 1.3 日刊已接入，当前装机 Build168；11 项 App 自检与规则库 518 项/92 suites 全通过。真实存档只新增日刊回执。四日期截图和存档比较见 `daily-newspaper-app-20260929/README.md`。1.1–1.6 的代码接入已具备；1.7 提示审查、1.8 实地导航/Unity 演出检查和任务 2 真人正常游玩计时尚未完成，不等同用户认可。

任务 1.7 提示审查完成，实际修正酒馆解锁原因、日刊状态、工坊逐项灰按钮原因和任务板 VoiceOver；见 `daily-limit-hints-20260929/README.md`。Build169 候选已编译，但设备仍为 Build168；最终 169 将随 1.8 验收夹具一起装机、归档。
