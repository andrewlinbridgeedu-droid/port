# H3：住处自检与界面复看 · 2026-09-30

**[PR #35](https://github.com/andrewlinbridgeedu-droid/port/pull/35) 保持草稿、未合并，等待修订版真机操作和用户复看。** 最新要求已修正找东西／赶塔怪为三步委托，生产入口各扣 15 点，送货仍 10 点、传话仍 15 点。住处文案改成港城里的说法；首页灯罩与体力页不再显示体力统计数字、恢复率、回满表或全部活动清单，任务入口仍显示从规则库取的单次花费。修订版签名 Debug 169.12 构建通过，模拟器住处 **22 项**与原有 **11 组**自检通过。修订版尚未装机：手机当前开发连接不可用，iPhone 镜像提示未找到设备。

此前 169.12 已安装在 iPhone 13，21 项住处与 11 组自检通过，并取得 11 张阶段截图和 194 份 Preferences 不变的证据。**同一编号下这些旧真机证据不能证明本次修订已装入或手动流程已完成。** 后续须重新备份、装入修订包、跑 22 项和原有 11 组、手动操作后再核对 Preferences；完成后按用户最新要求取消草稿，合并仍等待用户视觉认可。

H2 已由 [PR #34](https://github.com/andrewlinbridgeedu-droid/port/pull/34) 合入 main（`bfdb800e8fd8e81bde830cd86f43aee3dd839355`）。H3 从该 main 新开 `codex/housing-h3-verification-20260930`。下面的结果只证明已执行的范围，不能替代用户复看。

## 上一次真机装机与存档核对（修订前 169.12）

- 设备为 iPhone 13、iOS 26.6，传输使用局域网。1.8 GB 包第一次 60 秒安装超时后核查仍为 169.10，延长等待重试成功；设备 App 清单确认 169.12。
- 先完整备份 Preferences 到 SSD 私有目录，确认 194 份文件和真实玩家 plist 可读，才安装。截图账户为 `mistport.housing-device-walk.20260930`，没有进入真实玩家存档。
- 真机 `--verify-housing` 21 项和原有 11 组自检通过（工坊单独启动；正式塔 Swift 规则 100/100）。[报告与哈希](device/validation-device.json)、[自检日志](device/selfchecks.log)及三份 JSON 都由设备导出，正式塔报告明确为 `shipping-core-on-device`，Unity 视觉认可仍为 false。
- [11 张原样真机截图](device/)为 1170×2532，包含柜台、五步选房、住处／饮食、体力、高地入口和首页昼夜门牌／灯。`capture.json` 记录最后一次补拍；完整截图清单在 `validation-device.json`。手机最终停在隔离账户首页，可从首页打开真实的赁屋行 sheet 继续检查返回和完整流程。
- 再完整备份并执行逐文件比较，[比较报告](device/preferences-comparison.json)通过：194 份原有文件全都逐字节不变，没有新增／修改真实玩家键；新增 18 份均为已知隔离测试 suite，无需豁免任何旧文件。原始备份与逐文件哈希仅留 SSD，不入仓库，也没有把备份反写到设备。

## 修订版已验证

- 签名 Debug 设备包 169.12 构建通过，DerivedData 在外置 SSD；修订版尚未装机，没有新归档。
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

- 真机中的返回、滚动、室内三细节点、连续五步操作和实际封蜡盖章动画；模拟器截图只是选定真实页面阶段，搬家阶段确实签隔离账户租约，不代表手动走完流程。
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
5. 完成以上操作、交真机图后，按用户本次要求解除草稿；用户视觉认可后才能完成 H3 并合并。本次因设备连接中断尚未开始重装；自动导出的旧真机阶段截图不代表手动走完流程。

`tools/housing/capture_device.py` 可复现隔离截图，要求传入已经成功读取的 Preferences 备份，并核对设备已装 169.12；它不执行安装、真实存档写入、恢复备份或像素编辑。设备 App 参数使用 `--` 与 devicectl 选项分隔。

手动流程启动参数在 `--housing-device-walk --housing-screen=home` 后另加 `--housing-manual-record`，再从首页**实际点击**赁屋行；不得用 `--housing-screen=lease/moving` 的阶段跳转当作手动流程证据。封蜡和页面原样导出器仅记录自己的独立 Documents 子目录；再次启动后不会自行播放流程。
