# 背包背景重绘（2026-09-24）

用户否定“补给与背包”页背后的明亮房间图，要求回到天赋页图1的深色星象气质，并明确要求**重新画，不复用原图**。

使用内置 imagegen 生成独立竖版位图 `mistport-ios/Mistport/Assets.xcassets/SceneInventoryCelestialArchive.imageset/art.png`（863×1823）。最终画面为靛黑旧纸/漆面、稀疏不规则旧金星轨与边缘微紫雾，中央留暗部供物品格覆盖；没有房间、窗户、大理石地面、界面字样或物品图。它与天赋页 `TalentAstrolabeBackdrop` 是两个不同的资源，不是复制或改名。旧 `SceneInventoryTreasury` 原件仍保留，未删除。

`HubFeatureView` 的 `.inventory` 背景切换到新资源，原浅米色蒙层改轻黑蒙层；背包卡片底色从青绿调为深紫黑以避免与背景冲突。物品原画、布局、数量、功能及其它页面没有改。代码与项目文件的改前备份在 `backups/inventory-background-redraw-20260924`。

内置 imagegen 的最终提示词：

```text
Use case: stylized-concept
Asset type: original painted background asset for a portrait mobile fantasy game's inventory and supplies screen, behind a dense grid of real item icons and translucent cards.
Primary request: create a NEW artwork, not a copy of any existing game background. It should have the same luxurious mysterious visual language as a dark celestial talent-map screen: near-black midnight indigo, aged inked parchment/lacquer, delicate tarnished antique gold engraving, restrained amethyst mist and tiny stars.
Scene/backdrop: an abstract enchanted archive of constellations and treasured records, conveyed through layered surface texture and sparse irregular golden astronomical etchings rather than a literal room. Distinct inventory identity: subtle asymmetric traces of a celestial ledger, thin hand-engraved winding paths and a few restrained brass corner inlays. No central circular astrolabe, no pedestal.
Style/medium: high-quality hand-painted Japanese fantasy game UI background, richly textured but elegant and controlled, crisp fine linework with imperfect handmade variation, no flat vector graphics.
Composition/framing: tall portrait mobile wallpaper, approximately 9:19. Keep the central 70 percent of the image dark, low-contrast and spacious so inventory cards and text remain legible; concentrate the ornament toward the top and outer edges. Make the artwork work after slight side-cropping on phone screens.
Lighting/mood: quiet magical depth, soft edge glints only, not bright or glaring.
Color palette: charcoal indigo, smoky violet, black plum, muted old bronze and fine warm-gold highlights.
Constraints: background art only; absolutely no user interface, no inventory item icons, no cards, no readable writing, no title, no logo, no watermark.
Avoid: bright cathedral or shop interior, architecture, windows, white marble floor, realistic treasure room, large regular geometric circles or frames, strong repeated patterns, visual clutter behind the item grid.
```

验收边界：已检查原图尺寸与内容、资产 SHA 及源码引用；模拟器构建因 UnityFramework 设备版与模拟器平台不匹配而在链接阶段失败，不能声称模拟器实看。设备版 Build 67 以 `CODE_SIGNING_ALLOWED=NO` 完整编译通过，`assetutil --info` 证实新资源在 `Assets.car` 内。签名构建失败：本机 `security find-identity -v -p codesigning` 返回 0 个有效身份，Xcode 报无开发账户/证书；Build 67 未装机，手机仍为已装的 Build 66。尚无真机背包页截图或用户视觉认可。
