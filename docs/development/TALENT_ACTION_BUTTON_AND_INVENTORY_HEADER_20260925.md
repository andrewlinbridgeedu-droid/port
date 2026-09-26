# 天赋操作按钮与背包重复卡片（2026-09-25）

## 本次范围

- 将天赋星图底部操作按钮改为与已确认的塔按钮一致的暗紫黑、旧金风格；按钮图自身写字，不叠加系统文字或羽笔。
- 四种状态分别为「点亮天赋」「天赋点不足」「前置未满足」「已掌握」，原有点亮和禁用规则不变。
- 移除「补给与背包」标题下重复的「旅途行囊」统计卡；分类栏、物品格、详情和实际数据保留。

## 位图制作

使用内置 imagegen，以现有 `ButtonArtChurchTowerReturn` 图作风格参考；提示词组的共同要求是：保持紧凑横向比例、暗紫黑底、克制的旧金细边和非羽笔的封印图案，背景透明，不增加花哨装饰；分别将图中文字替换为上述四种状态，保持其余样式一致。游戏使用的裁切图为 1400×327，另有 300×70 实际宽度预览。

交付图位于 `output/talent-action-button-20260925/`；正式资源为 `mistport-ios/Mistport/Assets.xcassets/ButtonArtTalentInvocation*.imageset/`。旧 `ButtonArt01TalentInvocation` 仍被别的测试页面使用，本次未删除。

## 接入与验证

- `CharacterProfileView.swift`：`LegacyHermitTalentTreeView` 按状态选用四张资源图，保留点击动作和禁用条件，并为图像按钮提供文字无障碍标签。
- `SceneViews.swift`：删除 `InventoryWalletHeader` 及其唯一调用，不改背包其他功能。
- 四张手机宽预览已目视检查，图片集 JSON 已校验。两处改动合并后，独立 DerivedData 的 iPhoneOS Debug 构建成功（Build 78）；`assetutil` 在成品 `Assets.car` 中确认四个新图片集均已入包。构建仅有工程既有警告。
- 首次验证时设备已有 Build 81，故没有安装旧的 Build 78。Build 81 的构建记录位于 `output/harbor-npc-route-20260925/xcodebuild-build81.log`，使用同一工作区并在构建命令中覆盖 `CURRENT_PROJECT_VERSION=81`；工程文件保留 78 不代表缺少 81 的源码。
- 随后按用户要求，在包含 Build 81 港城内容及其后续更新的现行源码上，用命令行版本号覆盖构建签名 Build 85，不覆盖工程文件。成品 `Assets.car` 含四张天赋按钮图和港城资源，`harbor-pedestrians.json` 已入包，`codesign --verify --deep --strict` 通过。构建时另一个工作流已生成并装机 Build 84，本次因此从设备 Build 84 直接升级到 85，未降级。
- Build 85 已安装并启动 iPhone 13；设备应用列表确认为 `0.1.0 (85)`，进程列表确认运行。安装前、安装后、启动后的 `Library/Preferences` 逐文件相同，三份副本位于 `backups/talent-inventory-build85-20260925/device-{before-build85,after-install,after-launch}/`。尚未在真机逐页实看天赋与背包的主观视觉，不称真机视觉验收通过。
