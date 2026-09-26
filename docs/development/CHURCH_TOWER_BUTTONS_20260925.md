# 封印塔统一按钮 · 2026-09-25

后续用户在真机指出浅色与联封深井页面不搭，已改为暗紫旧金并缩小约 1/7；现行版本见 `CHURCH_TOWER_BUTTONS_DARK_COMPACT_20260925.md`。本文保留 Build 77 的历史记录。

## 交付范围

- 用户认可去羽笔、浅灰褐字与封印压印方向。四个正式按钮统一为暖纸面、细金框、右端压印；仅文案不同：进入封印、重返封线、准备下一层、返回深井。
- 四张 RGBA 图片均为 1400×327，位于 `mistport-ios/Mistport/Assets.xcassets/ButtonArtChurchTower{Entry,Return,Next,Back}.imageset/art.png`。高分辨率裁切母版与 350px 手机宽度预览在 `output/church-tower-buttons-20260925/final/`。
- `ChapterOneTestView.swift` 用同一个 `ChurchTowerArtButton` 接四处，图片按原比例缩放，取消塔按钮九宫格拉伸和运行时叠加文字；保留原点击行为及 VoiceOver 名称。其它教会按钮仍用原 `ButtonArt29ChurchAction`。
- 城市场景原有编译错误：`HarborPlace` 定义 `point` 而绘制处引用不存在的 `markerPoint`。仅将两处绘制坐标改为 `place.point`，不改坐标值、路径或交互。

## 生成方式和提示词

使用内置 imagegen。参考 `BattleRitualSeal` 的中央菱形及放射纹，但最终只保留纸面右端的小型旧金/暗紫压印，不复用整张大徽章。最终母版保留透明底，源图由内置工具保存在 `/Users/andrewlin/.codex/generated_images/01a0c79c-3f4d-78e0-93c6-601df50a3999/exec-ba78ae6d-208f-42a3-ba8f-2b50b3c8a068.png`。

最终图案编辑提示词：

> Use case: precise-object-edit. Image 1 is the BUTTON TO EDIT. Image 2 is ONLY a motif reference from the game's existing ritual-seal art: use its central faceted-diamond and radiating-point identity, but simplify it radically. Make exactly one change to Image 1: remove the upper-right feather and replace it with a SMALL, quiet, refined blind-embossed ritual-seal mark on the far right of the parchment face, entirely inside the border, at most 15% of button width and about 55% of the face height. Render it as pale antique-gold engraved linework/low relief, with a tiny muted deep-plum center, not a glossy gem badge, not a colorful sticker, not a generic web icon. The mark should feel hand-stamped onto the paper and be secondary to the title. Preserve the warm paper body, clipped corners, thin borders, tiny side diamonds and horizontal rules, true transparent exterior, and exact softly colored centered Chinese text '进入封印' at approximately #786E60 completely unchanged in placement, size and style. No feather or quill anywhere. No extra decoration, text, background, shadow, chunky medallion or watermark. One shippable isolated game button.

其余三张按同一母版分别使用 `text-localization`：只将中部文案改为 `重返封线`、`准备下一层`、`返回深井`；保持约 `#786E60` 的暖灰褐字色、宋/明体质感、右侧封印、纸面、边框、透明底和尺寸不变。手机缩图已逐张查看四处字形。

## 验证与界限

- 签名 iPhoneOS Debug Build 77 构建成功，`Assets.car` 含四个按钮资源。
- 已覆盖安装并启动连接的 iPhone 13；`devicectl` 安装列表确认 `0.1.0 (77)`。
- 安装前后 `Library/Preferences` 逐文件一致。启动后仅 `mistport.player-test-01-15.plist` 的 `mistport.campaign-relics.v1` 两个已有 ID 在数组中互换顺序，文件字节不同；其它键和值未变。三份副本在 `backups/church-tower-button-unify-20260925/device-*`。
- 已核对 350px 缩图、资源打包与构建；尚未取得封印塔入口及通关弹窗的可靠真机定帧，也未为视觉验证启动一场新战斗。最终场景观感仍待用户在手机上看。
