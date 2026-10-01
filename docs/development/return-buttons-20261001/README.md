# 港城返回按钮与米色铺底统一 · 2026-10-01

用户认可警察厅的金边切角“返回港城”按钮，要求报馆及其他地方保持一致。从最新 main `758d409` 单独开 `codex/unify-return-buttons-20261001`，没有混入草稿 PR #41 的战斗资源。

## 米色铺底修订（用户最新反馈）

用户指出警察厅正文下面仍有大片深色留白，要求各处用正文的米黄色一直铺到底。本修订继续提交到 [PR #42](https://github.com/andrewlinbridgeedu-droid/port/pull/42)。最新结果见 [28 张原样截图](paper-review.html) 和 [构建、源码及截图记录](paper-validation.json)。下文的 25 张截图保留为返回按钮首轮历史记录，拍摄时间早于本次铺底修正。

- `GameArtPaperScroll` 让纸面至少填满可见正文区域，并用同色背景覆盖底部安全区。各柜台的 `HomeCounterScene` 和通用正文页的 `GameArtPage` 共用它，短页不再露出深色空白，长页滚到底也保持米色。
- 报馆日刊和报纸附刊也改为连续纸面，使用原报纸米黄色与纸面阴影色；报馆编辑／排字工文字改成墨色以保持可读。标题栏和金边按钮保留原样。
- 覆盖柜台、赁屋行、租约、商人、设置、技能说明、委托、通缉、城市事件、邻里等共用纸面页面。场景画、人物贴层、功能按钮、玩法规则与返回回调没有改变。
- 最终模拟器编译 `BUILD SUCCEEDED`。逐张观察 20 张页面首屏和 8 张滚到底截图，包含警察厅、邮局、委托板等短页，以及市政厅、日刊、附刊、设置、商人、租约、咖啡馆、旧街铺面底部。均为正式 SwiftUI 页面原样导出，1170×2532，PNG 按 LFS 提交。
- 滚到底截图通过现有隔离 DEBUG 模式的 `--daily-ui-review-bottom` 跳转滚动位置，不能记为手动点击或手势测试。未测全套系统字号、手动回弹手势、真机布局或 Unity；没有装机、没有访问手机 Preferences、没有修改玩家存档。DerivedData 仍在 SSD，已有链接保持原样。

复跑本次截图（先构建并安装到独立模拟器）：

```sh
python3 tools/ui-art/capture_simulator.py --simulator <UUID> --destination docs/development/return-buttons-20261001/paper-screenshots --screens police cityhall harbor board post clinic oldstreet cafe agency newspaper supplement settings skill tasks bounty shop offers lease events neighbors cityhall-bottom newspaper-bottom settings-bottom shop-bottom supplement-bottom lease-bottom cafe-bottom oldstreet-bottom
```

## 改动

`GameArtReturnButton` 复用警察厅原有的 `GameArtButtonStyle(compact: true)`，统一深色底、双层金边、切角、字体、按压反馈与至少 44 点的点击高度。字号跟随系统设置，不将文字绘进图片。返回动作仍由原页面提供。

- 报馆由圆角胶囊“收起报纸”改为“返回港城”；标题栏和正文改成上下正常布局，去掉顶部 48 点占位。返回按钮保持在标题栏，正文可单独滚动。
- 报纸附刊、各柜台、赁屋行、百工坊、设置、技能说明、角色／天赋、行囊／构筑、酒馆／牌桌及玩法说明、街区／任务地图、教会／塔层／通缉／维护、世界航图与盐岸页面复用同一控件。
- 返回上一级的页面保留对应文字，如“返回角色”“返回看区”“收起附刊”“暂离牌局”。战斗入口仍调用原退出结算，教学的退出限制与锁图标保留；没有改变返回目的地或结算逻辑。
- 构筑页去掉“愚者攻略”的放大镜装饰，文字保持单行，避免新返回按钮使其挤成两行。
- 翻页箭头、卡牌排序、首页信息展开／收起、街景对话气泡及战斗快捷技能弹框、正文的完整行动按钮、战后主行动不属于页面标题栏返回控件；保留其用途与布局。DEBUG 工具面板的系统工具栏不属于玩家页面。

## 首轮返回按钮验证（铺底修正前）

模拟器使用独立的 iPhone 13 / iOS 26.5 实例和 `local.mistport.housing-integration` 包；正式 Swift 源码与资产目录编译，Unity 运行时不包含在该核查宿主。所有页面通过既有 DEBUG 隔离账户打开，截图不访问真实手机容器。

- 编译通过：初次构建、修复构筑页换行后的构建，以及补齐牌桌玩法按钮后的最终构建，均为 `BUILD SUCCEEDED`。最终日志及产物的哈希见 [validation.json](validation.json)。
- [25 页原样截图](review.html) 已逐页观察：报馆、附刊、警察厅、市政厅、港务处、委托板、邮局、诊所、旧街铺面、咖啡馆、赁屋行、角色、行囊、构筑、任务地图、街区地图、教会、深井、百工坊、设置、技能说明、酒馆、横向牌桌、牌桌玩法、主线战斗标题栏。默认字号下检查了返回文字、金边切角、点击区域布局以及与标题的间距。构筑页发现的换行已经修正并重新截图。
- `battle-hud.png` 是未开打的 Q4 准备页，只核对标题栏；中间黑色区域是核查宿主未包含 Unity，不作为战斗画面、动作或性能证据。
- 截图通过既有 DEBUG 路由直接打开对应生产视图，不模拟手动导航；没有逐页点击返回、验证完整战斗结算或覆盖所有系统字号。返回回调、教学退出限制与结算调用通过源码 diff 核对，保持原逻辑。
- 模拟器截图不记为真机证据或用户对新增页面的视觉认可。本轮没有安装手机、没有访问手机 Preferences、没有修改真实存档、规则、生产图片、Unity 资源、生产工程设置或已有 SSD 链接。Scratch 工程与 DerivedData 在 SSD。

复跑：

```sh
python3 tools/housing/build_simulator_harness.py --output "/Volumes/andrew's SSD/Mistport-build-cache/return-buttons-20261001"
# 安装到独立模拟器后运行；不针对真实设备。
python3 tools/ui-art/capture_simulator.py --simulator <UUID> --destination docs/development/return-buttons-20261001/screenshots --screens newspaper supplement police cityhall harbor board post clinic oldstreet cafe agency profile inventory build chapter-map district-map church tower workshop settings skill tavern poker poker-help battle-hud
```
