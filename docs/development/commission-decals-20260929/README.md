# 城市委托街景贴片 · 待用户看图确认

从 `main` 的 `485b5d67308f2ea9dddac476d74a8d9af4f10cfa` 开分支 `codex/commission-decals-20260929`。本次只交美术图稿和坐标记录，未接 App、未构建、未装机，未改玩家存档；用户视觉认可仍待完成。

[草稿 PR #22](https://github.com/andrewlinbridgeedu-droid/port/pull/22)；图稿确认前保持草稿，不合并。

三处都是在现有画面上加东西：喷泉边的矮石花坛和三串三角彩旗；大道右侧栏杆旁五盏铸铁路灯及落地光晕；货场既有吊臂上挂的深蓝、浅金港务配色帆布和下方八只带港务封签的新货箱。15 张 `City*` 首页原画、原灯光层和原遮罩都未修改。

## 第二版：参考意见后的修订

用户转来的意见属于看图参考，**不作为用户视觉认可或接 App 的授权**。喷泉稿保持原样；路灯增加普通／冬雪两张纯光晕层，五块分别随对应灯的 R/G 顺序开关；货场参照现有 `HomeHarborOfficeEmpty20260929` 的深蓝与金色，帆布增加清晰锚记，货箱从五只改八只并适度放大。旧货场贴片保存在 `assets/history/yard-v1/`。

![原 PR 图稿与第二版](revision-v2-overview.jpg)

[货场按手机宽度的可辨识度对比](yard-phone-width-v2.jpg)：原画按高度 760、宽 390 的地图视口比例缩放，截取货场所在一屏；这是离线图，不是真机界面或装机证据。

## 看图

每幅对比左边是贴前，右边是贴后。这些是**离线美术叠图，不是真机截图或验收通过的证据**。黄昏、夜晚的贴前、贴后均叠同一份现有城市灯光，新增路灯另按同样的 R/G 开关顺序亮起。

![秋景白天三处总览](autumn-day-overview.jpg)

| 地点 | 全部 15 场景 | 原尺寸逐幅对比 |
| --- | --- | --- |
| 喷泉广场 | [春夏秋冬冬雪 × 三时段](fountain-all-seasons.jpg) | `comparisons/fountain-City*.png` |
| 台阶大道 | [春夏秋冬冬雪 × 三时段](boulevard-all-seasons.jpg) | `comparisons/boulevard-City*.png` |
| 工坊货场 | [春夏秋冬冬雪 × 三时段](yard-all-seasons.jpg) | `comparisons/yard-City*.png` |

全部 45 幅的文件名及所用贴片见 [comparison-manifest.json](comparison-manifest.json)。PNG、JPG 通过仓库现有 Git LFS 规则提交。

## 贴片与坐标

`assets/` 根目录内为本版 512×512 贴片：每处普通版白天／黄昏／夜晚三张，加冬雪白天／黄昏／夜晚三张，共 18 张 RGBA；另有一张 RGBA 灯芯发光层、普通／冬雪两张 RGBA 落地光晕层，以及灯芯／落地光两张 RGB LightOrder 数值图。共 21 张 RGBA 和 2 张 RGB 数值图；历史六张货场图不参与本版显示。雪面随时间独立配色，因此雪版也分三个时段；其余四季共用普通版。

坐标写入 App 读取的 [`home-map-layout.json`](../../../mistport-ios/Mistport/WisteriaMap/home-map-layout.json) 的 `commissionDecals`。记录以原画高度 2305 为 1，x、y 都除以画高，`at` 为贴片完整方形画布的中心，`size` 为方形画布宽高，透明边距也计入。`file` 指向本目录美术原件。每条均 `enabled: false`、`reviewStatus: pending-user-art-approval`；现有 `HomeMapLayout` 没有新增读取或绘制逻辑，图片也没加入 App 资源。

| 地点 | 原画局部框 `(x, y, w, h)`，像素 | 中心，画高单位 | 宽高，画高单位 |
| --- | --- | --- | --- |
| 喷泉广场 | `(2090, 1000, 690, 690)` | `(1.05639913, 0.58351410)` | `(0.29934924, 0.29934924)` |
| 台阶大道 | `(1290, 1280, 820, 820)` | `(0.73752711, 0.73318872)` | `(0.35574837, 0.35574837)` |
| 工坊货场 | `(3296, 1000, 800, 800)` | `(1.60347072, 0.60737527)` | `(0.34707158, 0.34707158)` |
| 路灯落地光 | `(1150, 1225, 1080, 1080)` | `(0.73318872, 0.76572668)` | `(0.46854664, 0.46854664)` |

路灯发光层与灯体分离。`CommissionBoulevardLightOrder.png` 沿用 `City*LightOrder` 的 R＝1−开启时点、G＝关闭时点、B 不用的协议；发光层 alpha 只预乘一次，随后用 `plusLighter`。本次仅在离线对比中演示：黄昏 `on=.20`、强度 `.60`，夜晚 `on=1`、`off=0`、强度 `1`。真实 App 的按时间亮灯、委托完成后显示及雪季选择，均等用户确认图稿后再接。

第二版落地光晕是图像生成器绘制的暖色光层，没有替换石砖或积雪；独立的大画布避免近处光晕在原灯体小框边缘截断。五块纯光按灯脚放置、偏向道路一侧，使用同样的五组开启／关闭时点，额外强度为 `.28`。`lighting.ground` 单独记录其文件、顺序图、中心和尺寸；大道对比框也扩大到 1080 原画像素，以展示完整光脚，灯体坐标不变。首版带出石砖纹理的光晕稿已淘汰，不作为交付图。

## 原图、提示词与复现

- `references/`：原画同一区域的秋景及冬雪三时段裁片；仅作生成和目视比色参考。
- `generated/`：图像生成器输出的原尺寸透明图；喷泉、货场还保留秋景白天的局部重绘输入稿。局部重绘稿**未替换任何首页原画**。
- `prompts/`：逐次生成的完整提示词，含修订。早期被淘汰的放大、漂移或重复旧建筑版本不作为交付贴片。采用的原图与提示词对应见 [generation-paths.json](generation-paths.json)。
- [registration.json](registration.json)：透明提取后的坐标配准。白天花坛平移回喷泉台面，彩旗不移；其余花坛版本按白天的画布范围配准，雪帽保留少量向上余量；五个灯芯分别按灯体玻璃的位置配准。脚本只做画布尺寸、裁切和位置配准，不绘制物体，不批量调暗或替代时段配色。
- [ground-lighting.json](ground-lighting.json)、[ground-registration.json](ground-registration.json)：灯脚、五块光晕的落点、大小、画布以及纯光层配准；光的形状和颜色来自图像生成器，脚本不画光。
- [originals-manifest.json](originals-manifest.json)：15 张首页原画的 SHA-256 和尺寸。复查必须与这里一致。
- `prepare_assets.py`：复现货场尺寸、花坛配准和灯芯配准；`prepare_ground_assets.py`：配准纯光层；`prepare_light_order.py`：生成数值顺序图；`render_review.py`：重做全部离线对比；`validate_delivery.py`：核对原画、资产和布局覆盖。

黄昏、夜晚、冬雪各时段均由图像生成器根据对应原画单独配色，再按 3 处 × 15 场景逐幅目视复核。图稿的美术是否合格由用户确认，本记录不会把生成成功、数据检查通过当作用户认可。

复现离线对比需要 Python 3、Pillow 和系统宋体：

```sh
python3 docs/development/commission-decals-20260929/prepare_assets.py
python3 docs/development/commission-decals-20260929/prepare_ground_assets.py
python3 docs/development/commission-decals-20260929/prepare_light_order.py
python3 docs/development/commission-decals-20260929/render_review.py
python3 docs/development/commission-decals-20260929/validate_delivery.py
```

检查结果见 [validation.json](validation.json)。没有运行 iOS 构建或规则库测试，本批未修改 Swift 或玩法规则。
