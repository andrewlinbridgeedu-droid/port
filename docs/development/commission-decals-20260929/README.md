# 城市委托贴片 · 第三版，用户已认可

[PR #22](https://github.com/andrewlinbridgeedu-droid/port/pull/22) 已合入 main（`1f6a859`）。用户于 2026-09-29 明确认可喷泉、货场第三版；认可记录及 12 张贴片的 SHA-256 见 [art-approval.json](art-approval.json)。**本版只做喷泉和货场，不新增路灯**。本 PR 仅交图稿、坐标和离线对比。

**首页显示条件（用户合并后明确）：**图稿先保存在仓库，等城市贡献度第 4 档的“城市委托”（`.cityCommission`）功能做进 App，玩家完成对应委托并保存完成状态后，才显示对应贴片。美术认可、PR 合并或达到第 4 档本身都不会直接显示变化。当前 12 条记录保持 `enabled:false`，App 接入与装机留后续任务。

## 本版变化

- 喷泉：保留三串彩旗，重画更饱满的花带，白、黄、粉、紫花形成较大的色块。矮石花坛留在喷泉台面，避免向前放大后悬在栏杆上。
- 货场：深蓝与浅金帆布加大锚记，用绳环挂在原有吊臂，去掉旧稿额外的黄铜立柱。较大的多层木箱堆移到前景可见空地，浅色封条和深蓝锚记更醒目，避开建筑墙面和原有设备。
- 台阶大道：取消新增五盏灯、灯芯光、普通／冬雪地面光及两张顺序图。本版没有大道候选坐标或发光贴片。原画已有的灯、City*Lights、City*LightOrder 全部保持原样。

另一个 agent 的参考意见提的是“补地面光晕”，没有要求加更多灯；五盏来自最初的 4–5 盏要求。用户最新明确不加灯后，该要求已撤回。旧稿只供追溯，不能用于 App 接入。

## 看图

以下图内“待确认”字样是出图时的记录；用户已认可第三版，图片与认可时保持一致。

![上一版与第三版](revision-v3-overview.jpg)

[手机宽度对比](phone-width-v3.jpg)：两个 390×760 比例的地图视口，左旧稿、右新稿，检查远看是否明显；**离线图，不是真机截图**。

![原画与第三版](autumn-day-overview.jpg)

| 地点 | 全部 15 场景 | 原尺寸对比 |
| --- | --- | --- |
| 喷泉广场 | [春夏秋冬冬雪 × 三时段](fountain-all-seasons.jpg) | comparisons/fountain-City*.png |
| 工坊货场 | [春夏秋冬冬雪 × 三时段](yard-all-seasons.jpg) | comparisons/yard-City*.png |

当前共 **30 幅贴前／贴后对比**，左原画、右本版。黄昏与夜晚的两边叠同一份既有城市灯光，没有新灯或新光效。清单见 [comparison-manifest.json](comparison-manifest.json)。PNG/JPG 按 Git LFS 提交。

## 贴片与坐标

assets/ 根目录只有本版 **12 张 512×512 RGBA**：两处各有普通白天、黄昏、夜晚，以及冬雪白天、黄昏、夜晚。普通版四季共用；冬雪在露天上表面补雪，三时段分别绘制。黄昏和夜晚参考对应原画单独绘色，不用脚本统一调暗。

| 地点 | 原画局部框 (x,y,w,h)，像素 | 说明 |
| --- | --- | --- |
| 喷泉广场 | (2090,1000,690,690) | 花坛留在喷泉台面 |
| 工坊货场 | (3016,1000,1080,1080) | 扩到可见前景地面，吊臂仍是原吊臂 |

[home-map-layout.json](../../../mistport-ios/Mistport/WisteriaMap/home-map-layout.json) 的 commissionDecals 仅保留这两处的 12 条记录，全部 enabled:false、reviewStatus:user-art-approved。图稿已获认可，运行时接入尚未开始。坐标 x、y、宽、高均除以画高 2305；at 是完整透明方形画布中心。file 指向 docs 图稿，原有布局字段不变。没有增加 Swift 读取或绘制逻辑，没有把图加入 AssetCatalog。

## 提示词、原件与复现

- references/*-v3-City*.png：从未修改的秋景、冬雪三时段原画裁下的参考，货场用扩大的框。
- generated/Commission*V3*.png：本轮图像生成器原件及明确标成 Day-registered 的组装输入。喷泉保留单独的新花坛原件；初次放大过头的候选标 Day-initial，不参与本版显示。
- prompts/*-v3-*.txt：完整生成、提取和逐时段配色提示词，对应关系见 [generation-paths.json](generation-paths.json)。采用内置 image_gen，未使用 API/CLI 回退。
- [registration.json](registration.json)：裁切、缩放、旋转和位置配准。脚本不绘制物体或雪，不统一调色；旋转的是透明帆布，原吊臂没有改动。
- [originals-manifest.json](originals-manifest.json)：15 张首页原画的 SHA-256，复核必须全部一致。
- assets/history/ 和 history/v2/：旧花坛、货场、撤回的路灯与光效，以及旧说明和对比。只供追溯，不是当前交付。第二版完整可复现状态在 Git 提交 f040d1c。

依次运行本目录 prepare_assets.py、prepare_layout.py、render_review.py、validate_delivery.py，可复现透明贴片、禁用坐标和全部离线对比。需要 Python 3、Pillow 和系统宋体。

验证见 [validation.json](validation.json)：15 张首页原画与既有灯光不变；两处 × 15 场景覆盖，12 张透明贴片、12 条禁用坐标；贴片哈希与用户认可记录一致。未运行 iOS 构建或规则测试，未修改玩法、设备或玩家存档。本版的视觉认可来自用户本次明确回复，不来自生成结果或数据检查。
