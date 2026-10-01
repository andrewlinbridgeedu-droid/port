# H3：住处自检与界面复看 · 2026-09-30

## 当前：169.13 已安装，镜像复验暂未完成（2026-09-30 晚）

按用户要求将 [PR #38](https://github.com/andrewlinbridgeedu-droid/port/pull/38) 合入 H3 分支，合并提交 `5ba38b4`。签名 Debug **169.13** 在外置 SSD 构建并装入同一台 iPhone 13（iOS 26.6）；设备 App 清单确认编号。没有新归档，没有修改 SSD 链接。新包真机 `--verify-housing` **22 项**与原有 **11 组**全部通过，包含找东西／赶塔怪各 15 点、送货 10 点、传话 15 点及重试不重扣。

安装前通过 USB 再完整备份 **229 份** Preferences；安装与自检后取回 **246 份**并逐文件比较。真实玩家文件及 audit 文件逐字节不变；原有文件只有两个明确的隔离测试 suite 改变，17 份新文件全部属于本次自检 suite。见 [本轮装机中途比较](device/preferences-install-interim.json)。原始文件、全部哈希和完整备份只留 SSD，不反写手机。较早的 212 份备份与本轮安装前玩家文件已有差异，无法据此追认旧安装后的核对；本轮以紧接安装前的 USB 备份为基线。

PR #38 增加输出时钟确认与路由／中断恢复处理，以及灯罩的雾、摇摆、光点、飞蛾和点击反馈；它也恢复了体力数字与回满提示。此轮遵循用户明确要求合入该 PR，不把此前“无数字”的历史描述当作当前界面。本分支补充仅限 DEBUG 隔离账户的三种灯罩状态夹具、原样 ReplayKit 录屏和只读音频诊断。没有改变体力价格、恢复速率或生产游戏规则。

未使用 `-MistportCityMute` 启动并观察到扬声器输出时钟推进、环境音循环节点运行，进程未退出；但角色页只是覆盖首页，不能算音频重新启动。后续手机被其他操作切到设置、快捷指令和主屏幕，**未完成可计数的十次首页进出**，没有把这些非计划切换记为通过。用户随后表示先完成其他手机操作，已停止镜像点击。用户没有耳机，耳机插拔未测；这些范围见 [音频记录](device/AUDIO-MIRRORING.md)。

**仍待：**独占镜像期间从主线地图实际进出首页至少十次、切换其他 App 后声音恢复，三种灯罩页及首页小灯／任务花费的新真机截图，含手动点灯的十秒原样录屏，玻璃中心光晕检查，以及完成整轮后的再次 Preferences 核对。当前阶段 PNG 仍为历史 169.12，未冒充 169.13。PR #35 保持草稿、未合并；按用户指定顺序，Q3／Q4 猎犬动作的新分支尚未开始。

## 169.12 修订版当时记录（以下为历史）

**修订版签名 Debug 169.12 已装入 iPhone 13，真机住处 22 项与原有 11 组自检通过，手动租屋流程已走完，19 张手动截图完整取回。** 最新要求已修正找东西／赶塔怪为三步委托，生产入口各扣 15 点，送货仍 10 点、传话仍 15 点。住处文案改成港城里的说法；首页灯罩与体力页不再显示体力统计数字、恢复率、回满表或全部活动清单，任务入口仍显示从规则库取的单次花费。当前 [PR #35](https://github.com/andrewlinbridgeedu-droid/port/pull/35) 仍为草稿、未合并：局域网开发连接再次中断，新版阶段图与安装后 Preferences 比较尚未完成。不能提前认定真实存档核对通过。

此前同编号 169.12 的 21 项报告与存档核对保存在 [prior-169.12](device/prior-169.12/)。旧截图在历史提交中保留。**编号相同不代表包内容相同，旧证据不能替代本次修订证据。** 本次安装的源码为 `f93210d`；签名包中启动程序与 `Mistport.debug.dylib` 的哈希分别记录，旧字段误把动态库称为 executable 的问题已纠正。

H2 已由 [PR #34](https://github.com/andrewlinbridgeedu-droid/port/pull/34) 合入 main（`bfdb800e8fd8e81bde830cd86f43aee3dd839355`）。H3 从该 main 新开 `codex/housing-h3-verification-20260930`。下面的结果只证明已执行的范围，不能替代用户复看。

## 本次真机操作（修订版 169.12）

- 安装前在 SSD 私有目录完整备份 212 份 Preferences，全部 plist 可读，真实玩家文件存在。安装命令成功，设备 App 清单确认 169.12；构建包与本次修订源码一致，没有改构建编号或重建 SSD 链接。
- 真机 `--verify-housing` 22 项与原有 11 组全部通过，见 [设备自检日志](device/selfchecks.log)和 [住处报告](device/housing-verification.json)。正式塔报告为 `shipping-core-on-device`、Swift 规则 100/100；不包含 Unity 视觉认可。
- 通过 iPhone 镜像从隔离账户首页实际点击赁屋行，依次看区、房屋卡片、进屋、签七天约、收门牌。检查了卡片回地图、室内回卡片、租约回室内、搬家回柜台、住处回柜台与柜台回首页；室内窗／壁炉／门印三处分别显示不同文字。住处页实际滚动后从面包坊换成汤棚，选中标记随之改变。
- 封蜡按钮实际点击后呈现“伊蕾娜正盖上封蜡…”，随后进入搬家页。[19 张手动 PNG](device/manual/)已完整导出，包括四帧封蜡，均为 1170×2532；PNG 分块 CRC、结束块与文件哈希核对通过。新的 11 张阶段图仍待补齐，上一级旧阶段 PNG 暂未替换，新版报告不把它们列为本次证据。
- 手动流程使用隔离 suite `mistport.housing-device-walk.20260930`；安装后的完整 Preferences 比较尚未完成。原始备份不提交、不反写设备，真实玩家 suite 不豁免。
- 镜像时发现首页环境音导致一次 Core Audio 崩溃；住房流程在已有 DEBUG 环境音静音参数下完成，未改生产音频，未保存静音偏好。见 [异常与验证限制](device/AUDIO-MIRRORING.md)。这次交互证据不能证明开启环境音的镜像稳定性。

## 上一次真机装机与存档核对（修订前 169.12，历史）

- 设备为 iPhone 13、iOS 26.6，传输使用局域网。1.8 GB 包第一次 60 秒安装超时后核查仍为 169.10，延长等待重试成功；设备 App 清单确认 169.12。
- 先完整备份 Preferences 到 SSD 私有目录，确认 194 份文件和真实玩家 plist 可读，才安装。截图账户为 `mistport.housing-device-walk.20260930`，没有进入真实玩家存档。
- 真机 `--verify-housing` 21 项和原有 11 组自检通过（工坊单独启动；正式塔 Swift 规则 100/100）。[报告与哈希](device/prior-169.12/validation-device.json)、[自检日志](device/prior-169.12/selfchecks.log)及三份 JSON 都由设备导出，正式塔报告明确为 `shipping-core-on-device`，Unity 视觉认可仍为 false。
- [11 张原样真机截图](https://github.com/andrewlinbridgeedu-droid/port/tree/0b062c4/docs/development/housing-app-20260930/device)为 1170×2532，包含柜台、五步选房、住处／饮食、体力、高地入口和首页昼夜门牌／灯。`capture.json` 记录最后一次补拍；完整截图清单在 `validation-device.json`。手机最终停在隔离账户首页，可从首页打开真实的赁屋行 sheet 继续检查返回和完整流程。
- 再完整备份并执行逐文件比较，[比较报告](device/prior-169.12/preferences-comparison.json)通过：194 份原有文件全都逐字节不变，没有新增／修改真实玩家键；新增 18 份均为已知隔离测试 suite，无需豁免任何旧文件。原始备份与逐文件哈希仅留 SSD，不入仓库，也没有把备份反写到设备。

## 修订版已验证

- 签名 Debug 设备包 169.12 构建通过并已安装，DerivedData 在外置 SSD，没有新归档。
- 生产 GameStore、HousingService、HousingStamina 规则和 SwiftUI 放进独立模拟器宿主，`--verify-housing` 的 22 项通过。包括规则价格、并发首次打开、重开不重付、七天约不预收、换餐不续租、不领取未付费加成、太平洋日日结、体力扣除／恢复、同回执不重扣、实际主线入口不扣体力、体力不足不改变账本、午夜后恢复降回基础速率、欠费降档、避难屋、满房拒绝、损坏账本不覆盖、夏令时，以及中断日结回执恢复匹配的钱包与体力。新增一项直接执行生产委托入口：送货扣 10，找东西／传话／赶塔怪扣 15；赶塔怪撤退再开只扣一次。
- 原有 11 组 App 自检通过：日限、重复工作、日刊、余案、街坊委托、城市事件、每日工坊、教会服务、遗落物商人、本地工坊、正式塔 100 层。商人组同时执行晋阶采购检查；正式塔为 Swift 规则执行 100/100，不含 Unity 表现认可。
- [11 张模拟器截图](simulator/)来自真实 SwiftUI，PNG 原样导出，包括柜台、五步选房、住处、体力、高地入口和首页昼夜灯。模拟器为现有 `Mistport Workshop Integration`、iOS 26.5、1206×2622；不是 iPhone 13。独立宿主包名为 `local.mistport.housing-integration`，宿主的包构建号 78 不作为设备交付编号。
- 15 张首页原画哈希与 H2 基线全部一致。原 City Lights／LightOrder 未改，城市委托贴片继续禁用。

[验证数据与文件哈希](validation-h3.json)、[自检日志](simulator/selfchecks.log)、[住处报告](simulator/housing-verification.json)、[工坊报告](simulator/local-workshop-verification.json)、[正式塔报告](simulator/church-tower-100-verification.json)。日志中的旧工坊截图检查有 UIKit appearance 提示和模拟器系统 accessibility 重复类提示；没有断言失败或崩溃。这些日志不能证明真机没有表现问题。

## 截图复看与用户反馈后的改动

- 租屋页去掉“第几步”、恢复线、档位加成和统计表的说法；用房钱、伙食、门牌、柜员安排来解释行为。价格仍来自规则库，未改经济规则。体力页只显示灯火强弱；任务入口单次花费保留。
- 选房／住处的嵌套页用“返回”，收好门牌也返回上页，避免显示“返回港城”却只是退到柜台。
- 新增 `--housing-manual-record`：只在 DEBUG 且隔离住房账户下记录**实际点击**引起的页面变化、细节点和四个封蜡帧；不点击按钮、不自动切页、不改存档、不替代人工观察。原样 PNG 和时间清单写进 Documents；没有启用标志时不记录。
- 铜门牌的港册标题和玩家名字改为浅金色，按钮用白字，改善深底文字可读性。
- 首页灯按六处住处的远近分别定尺寸，点击范围至少 44 点。拱廊合租间锚点从 `(0.265, 0.600)` 调到建筑墙面 `(0.145, 0.560)`，避开栏杆和咖啡馆名牌；坐标单位仍为画高 1，最终位置待真机复看。
- 地图保持 `CityAutumnDay` 原样缩览。左边高级住宅区可选高地石宅；右边贵族区只作极少开放的地标，没有普通租房卡片。没有增加贵族入住规则，没有再次重画港城地势。
- 所有 `--verify-*` 的外层启动账户与 `--housing-device-walk` 截图账户都使用独立 suite；住处自检另建 UUID suite，仅清理自己的测试数据。截图账户种下 2000 铜和 Q8 进度，不能当成玩家账户。禁止用这些夹具覆盖真实存档。

## 尚未验证

- 新版阶段截图导出和安装后的 Preferences 逐文件比较；局域网开发连接在手动图导出后再次中断。此前阶段跳转图不能替代本次手动记录。
- 开启首页环境音时的镜像稳定性；已发现一次 Core Audio 崩溃，尚未修复。
- 真机上的门牌位置、夜灯比例、六处住处／赁屋行最终美术，以及用户认可。H0 已认可，不推定 H1–H3 也已认可。
- 共享服时钟、真实房量、跨玩家排队和房间锁定。本单使用规则账本适配器，不宣称服务器已连入，也没有新增离线产品模式。

## 复现模拟器结果

独立宿主去掉 Unity 依赖，保留生产 Swift 源码、规则包、Assets 与 WisteriaMap 资源。原生产 Xcode 工程不改。先选已有模拟器，再执行：

```sh
python3 tools/housing/build_simulator_harness.py \
  --output "/Volumes/andrew's SSD/Mistport-housing-simulator-host"
xcrun simctl install <SIMULATOR_ID> \
  "/Volumes/andrew's SSD/Mistport-housing-simulator-host/Derived/Build/Products/Debug-iphonesimulator/Mistport.app"
xcrun simctl launch --terminate-running-process --console <SIMULATOR_ID> \
  local.mistport.housing-integration \
  --verify-housing --verify-daily-pacing --verify-daily-work --verify-newspaper \
  --verify-remnants --verify-neighbors --verify-city-events --verify-daily-workshop \
  --verify-church-services --verify-early-relic-shop --verify-local-workshop \
  --verify-church-tower-100
python3 tools/housing/capture_simulator.py --simulator <SIMULATOR_ID>
```

等待自检 PASS 和 JSON 输出齐全后，再启动截图。`--console` 随 App 保持运行，下一次 `--terminate-running-process` 启动会结束该进程。截图脚本只复制新生成的 PNG 和报告，不修改像素。

## 已执行的真机操作顺序（再测试时沿用）

1. 把 `com.yourcompany.mistport` 的 `Library/Preferences` 全目录复制到 SSD 私有备份；确认成功并记录逐文件哈希。真实数据不提交仓库。备份失败则不装。
2. 安装已签名 169.12，只使用隔离的 `--verify-*` 或 `--housing-device-walk --housing-screen=…`。后者仅在 DEBUG 截图模式保持亮屏。
3. 跑住处及原有自检，导出真实设备截图；手动点查返回、五步租屋、细节点、换餐和盖章。
4. 再备份 Preferences，用 `tools/daily-loop/verify_preferences.py` 逐文件比较。真实玩家 suite 不豁免；允许明确列出的隔离测试 suite 变化，新文件逐一报告。若出现意外真实数据变化，先调查，不用备份反写覆盖。
5. 完成以上操作、交真机图后，按用户本次要求解除草稿；用户视觉认可后才能完成 H3 并合并。本次修订已安装，手动流程与 19 张手动图导出完成，仍需连接恢复后补拍阶段图、比较安装后 Preferences。旧阶段图不代表本次修订。

`tools/housing/capture_device.py` 可复现隔离截图，要求传入已经成功读取的 Preferences 备份，并核对设备已装 169.12；它不执行安装、真实存档写入、恢复备份或像素编辑。设备 App 参数使用 `--` 与 devicectl 选项分隔。

手动流程启动参数在 `--housing-device-walk --housing-screen=home` 后另加 `--housing-manual-record`，再从首页**实际点击**赁屋行；不得用 `--housing-screen=lease/moving` 的阶段跳转当作手动流程证据。封蜡和页面原样导出器仅记录自己的独立 Documents 子目录；再次启动后不会自行播放流程。
