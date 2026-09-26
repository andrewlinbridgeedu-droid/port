# 主动遗落物双态与圣所借物入口（2026-09-25）

- 背包详情的「选为主动遗落物」「已选主动遗落物」不再是橙色六边形与原生叠字。两张独立透明 PNG 延续已定稿的象牙纸、旧金细框；可选态为浅色深墨字，已选态为深紫底浅字。两行中文字直接做在图片中；只改这两种主动遗落物状态，其它物品操作保留原样。已选态禁用重复点击，可选态仍调用现有 `toggleCampaignRelic`。
- 三教会联合圣所的「封存借物处」入口改为同系象牙金边横牌；标题、副标题、右侧箭头均直接入图。原 `RelicDeferredStamp` 沙漏印章仍作为独立资源叠在左侧，以原 52pt 尺寸和 14pt 内边距维持位置；底图左部特意留白，没有重画或覆盖印章。
- 新图片：`mistport-ios/Mistport/Assets.xcassets/ButtonArtInventorySelectActiveRelic.imageset/art.png`、`ButtonArtInventorySelectedActiveRelic.imageset/art.png`、`ButtonArtChurchLoanEntry.imageset/art.png`。均由内置 imagegen 参照已批准的象牙金边按钮生成，精确中文入图，随后仅机械裁切/缩放；新图入包前均逐张目视校对字形、透明边缘与版式。
- 改前 `SceneViews.swift`、`ChapterOneTestView.swift` 留存于 `backups/inventory-active-badges-loan-entry-20260925/prechange/`。不改沙漏原画、其它按钮、遗落物效果或存档结构。

## 验证

- iPhoneOS Debug 整包签名 Build 87 构建通过，`codesign --verify --deep --strict` 通过；`assetutil` 确认三张新图及本批之前两张教会按钮、两张新衣装图均进 `Assets.car`。
- 已覆盖安装并启动 iPhone 13；设备应用列表显示 `0.1.0 (87)`。安装前、安装后、启动后的 `Library/Preferences` 八个文件逐字节一致，副本在 `backups/inventory-active-badges-loan-entry-20260925/device-*`。
- iPhone 镜像当前只返回空白窗口且屏幕捕获报错，无法据此声称真机内页的最终视觉已验收。新图本身已检查，按钮实际触摸区域与圣所印章叠层仍待设备画面复核。

后续用户指出本文件所述圣所入口的浅色底板与场景不合；已在 Build 88 改为深紫黑旧金版本，见 `CHURCH_LOAN_DARK_BUTTONS_20260925.md`。本文件的浅色描述仅代表 Build 87 历史，不是当前外观。
