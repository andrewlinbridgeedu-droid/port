# 封线装备页页头与穿戴按钮修复（2026-09-25，Build 91）

## 原因与修改

- Build 90 的 `ChurchSceneHeader` 在 `ScrollView` 内。初始位置看似避开状态栏，但列表滚动后页头一起上移，用户截图中返回键和标题进入刘海／时钟区域。Build 91 将页头放到滚动内容外，给页头独立暗底和细金分隔线，并裁切滚动视口；背景图仍铺满整个画面，内容继续留在安全区。
- 原穿戴图是浅象牙色，小字与教会深色装备页不合。新建 `ButtonArtChurchGearEquipDark.imageset/art.png`：炭黑偏紫底、低饱和旧金双框，中央直接写入较大的“穿戴”，两侧仅短线和圆点。最终图片为 2169×725 RGBA。UI 将可见图高限制为 52pt、最大宽度 220pt，以裁掉生成图的透明上下留白；只影响此按钮，不改变其他借物按钮的图片布局。
- 不改装备取得、属性、穿戴逻辑、存档结构及其它页面按钮。

## 图片制作

使用内置 imagegen 的编辑模式，以既有 `ButtonArtChurchLoanEquip` 深色按钮为风格参考：移除旧字和多余图案，改写准确的“穿戴”，保留透明外缘、暗紫材质及旧金切角双边框。第二次局部编辑提示词：`Make ONLY the two center Chinese glyphs approximately 35% larger and a little bolder, still on a single line and centered, exact 穿戴; keep the charcoal-purple, muted old gold double border, cut corners, transparency and layout.` 最终原图为 `/Users/andrewlin/.codex/generated_images/01a0c79c-3f4d-78e0-93c6-601df50a3999/exec-97e82cd4-19b3-4203-ac49-d5790ee432a7.png`，入包副本为 `mistport-ios/Mistport/Assets.xcassets/ButtonArtChurchGearEquipDark.imageset/art.png`。未修改旧按钮原图。

## 验证

- iPhoneOS Debug 签名 Build 91 构建通过，`codesign --verify --deep --strict` 通过；`assetutil` 确认新图入包。真机设备应用列表确认版本 `0.1.0 (91)`。
- iPhone 13 镜像实看：进入封线装备页、选择武器、切护甲、选择金喉铃护；列表滚动后卡片发生位移，页头和返回键仍固定在状态栏下方。新暗色穿戴按钮、放大的字和受控尺寸均在底部确认栏可见。没有点击最终穿戴。
- 安装前后 `Library/Preferences` 逐文件相同。启动后只有 `mistport.campaign-relics.v1` 两个既有 ID 的数组顺序互换（集合内容不变）；未见装备、货币或其它字段差异。因此不能称启动后偏好文件逐字节不变。副本保留于 `backups/church-gear-header-button-20260925/device-*`。
- 其它机型、系统放大字及滚动极限仍待另测。Build 90 的遗漏已在 `CHURCH_GEAR_REDESIGN_20260925.md` 更正。
