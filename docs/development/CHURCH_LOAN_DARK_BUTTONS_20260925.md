# 教会借物按钮与入口降亮度（2026-09-25）

- 用户指出圣所底部「封存借物处」入口的象牙白与阴暗教会场景不合。保留原横牌版式、精确标题/副标题、右侧箭头、左部留白与原独立 `RelicDeferredStamp` 沙漏印章的位置，仅将底板改为深紫黑纸面、细旧金双框及低饱和暖金字。原浅色图保存在 `backups/church-loan-dark-buttons-20260925/prechange/Assets.xcassets/ButtonArtChurchLoanEntry.imageset/art.png`。
- 借物页「装备借物」「归还并结清」改为同系深紫黑金边的文字入图按钮；为保持装备开关的两态一致，补画「卸下借物」图。正式资源为 `ButtonArtChurchLoanEquip`、`ButtonArtChurchLoanUnequip`、`ButtonArtChurchLoanReturn` 三个 `Assets.xcassets` 图片组。仅替换显示层，既有装备、卸下、归还、禁用条件、音效和账目结算原样保留；未改契约签订按钮及其它教会动作。
- 四张图均使用内置 imagegen：入口从上一版横牌定向调整配色，三枚操作按钮参照该深色材质分别将精确中文直接画入图。机械裁切/缩放入包后逐张目视校对文字、边框、透明外缘。SwiftUI 继续使用 `ChurchIllustratedActionButton` 的按钮语义与无障碍名称，不叠系统文字。修改前 `ChapterOneTestView.swift` 留存于同批备份。

## 验证

- 签名 iPhoneOS Debug Build 88 构建通过，`codesign --verify --deep --strict` 通过；`assetutil` 确认四张正式图都在 `Assets.car`。
- 已安装并启动 iPhone 13，设备应用列表显示 `0.1.0 (88)`。安装前、安装后、启动后的 `Library/Preferences` 八个文件逐字节一致，副本在 `backups/church-loan-dark-buttons-20260925/device-*`。
- iPhone 镜像再次因屏幕捕获流失败而无法显示，故场景中的实机亮度、印章叠层与触摸手感仍待用户在手机上复核；不可把资源检查或构建通过写成真机视觉验收。
