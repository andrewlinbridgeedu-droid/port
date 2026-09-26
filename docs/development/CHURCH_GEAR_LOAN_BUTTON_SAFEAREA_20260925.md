# 封线装备／借物处按钮与安全区（2026-09-25）

- 针对截图圈出的两处按钮，沿已定稿的浅象牙色、旧金细框和留白样式另绘独立位图。装备「穿戴」右上角是极简金色扣饰，借物「签立借物契约」右上角是金色封印；不使用羽毛。两处文字均直接烘焙在 PNG 中，游戏仅使用对应图片作为按钮标签，保留原点击、可用性与无障碍名称。
- 新图片分别在 `mistport-ios/Mistport/Assets.xcassets/ButtonArtChurchGearEquip.imageset` 和 `ButtonArtChurchLoanContract.imageset`，均 866×192、带 alpha。使用内置 imagegen 参照既有 `ButtonArt25MainAction` 生成象牙底板，分别替换右上装饰并写入精确文字；机械裁切和缩放为可入包尺寸。其它教会按钮不变。
- 此批曾尝试用顶部留白避开刘海；用户在 Build 88 的真机截图中确认标题与返回按钮仍压到状态栏。原因是整个页面仍设置了 `ignoresSafeArea()`，滚动视口也因此延伸到刘海区域。真正修复见 `CHURCH_BUTTON_SIZE_SAFEAREA_20260925.md` 的 Build 89。
- 修改前 `ChapterOneTestView.swift` 在 `backups/church-gear-loan-button-safearea-20260925/prechange/`。新图属于新增资源，没有覆盖旧按钮。
- iPhoneOS Debug 整包构建通过（临时版本号 87），`assetutil` 确认 `ButtonArtChurchGearEquip`、`ButtonArtChurchLoanContract` 和三套人物立绘均进入成品 `Assets.car`。CombatCore 全包 386 项测试通过；这两处按钮仅改 UI 资源与布局，不改交易规则。同批签名 Build 87 已安装并启动 iPhone 13，Preferences 逐文件一致，详见 `INVENTORY_ACTIVE_RELIC_BADGES_LOAN_ENTRY_20260925.md`。真机截图复核尚未进行，不把代码里的安全区留白当成实机视觉验收。
