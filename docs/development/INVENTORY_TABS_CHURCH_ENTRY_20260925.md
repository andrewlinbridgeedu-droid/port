# 行囊分类栏与封印塔入口 · 2026-09-25

## 本次接入

- 行囊分类栏改为等宽的纯文字按钮，数量仍显示在标签旁；全部、补给、素材、遗落物、剧情在同一行，选中态为旧金文字与细下划线。移除分类图标、分类色实心胶囊和横向滚动。原遗落物解锁条件及分类筛选逻辑保留，切换分类时直接选中该分类首件物品。
- 封印塔的“进入封印 / 重返封线”使用独立的新绘底图 `ButtonArtChurchTowerEntry`。原通用 `ButtonArt29ChurchAction` 留给教会其他操作；动态按钮文字与原点击行为保留。
- 封印塔奖励行使用已有 `RewardCoin` 铜币图与 `RewardReputation` 紫金徽章图。后者在现有素材中最接近功勋标记，目前复用于功勋显示；没有新建货币种类或修改奖励数值。
- 移除入口下方“失败不掉层 · 无入场费用”说明。未解锁时的原因提示仍显示。

## 新绘底图

- 内置 imagegen 生成透明背景的横向封印板；保留生成原件于 `/Users/andrewlin/.codex/generated_images/01a0c79c-3f4d-78e0-93c6-601df50a3999/exec-4db4d3ec-cb52-4763-9d0e-53382ee3d0dc.png`。
- 游戏版裁去透明外边距并缩至 866×148 RGBA，路径为 `mistport-ios/Mistport/Assets.xcassets/ButtonArtChurchTowerEntry.imageset/art.png`。两侧纹章位于九宫格不拉伸区域，中央留给运行时标题。
- 生成提示词（内置 imagegen）：

> Use case: ui-mockup. Asset type: production-ready 2D game UI button background for a dark Japanese fantasy tower-seal entrance. Create ONE very long, slim horizontal button plate only, approximately 6:1 width-to-height. Genuine transparent background outside the plate. The design should feel hand-painted and premium, with a flat, clean silhouette rather than a chunky cartoon or a generic web button. Deep ink-black and indigo-plum interior; restrained muted antique-gold double hairline border; tiny engraved seal/arch crest contained only in the far left 14% of the plate, drawn as an original ornamental mark rather than a simple white outline icon. Subtle distressed-gold corner inscriptions and fine asymmetric etched details on the ends. Keep the central 65% quiet, dark, and highly legible for text that will be overlaid by the game at runtime. Top and bottom edges through the central 65% must be straight and uniform so the plate can be stretched horizontally with 9-slice resizing; keep all decoration at the ends. A few fine gold glints are okay, but no glossy 3D bevel, no heavy shadows, no bright cyan, no candy colors, no figures, no scenery. Absolutely no letters, words, Chinese characters, numbers, watermark, or extra buttons. Match the solemn gold-on-dark church seal map UI shown in the surrounding game.

## 验证与界限

- iPhone 设备目标 Debug 编译及签名通过；`Assets.car` 包含新按钮、铜币与紫金徽章图。
- 已安装并启动 iPhone 13 上的 `0.1.0 (75)`，设备安装列表确认版本号。安装后进入标题页成功。
- 真机检查中误触进入一次战斗；没有施放技能或领取奖励，已终止该次运行并重新启动到标题页。当前未获得封印塔入口和行囊分类栏的可靠真机定帧，因此按钮在塔背景上的最终观感、五类实际触控范围仍待用户实看。
