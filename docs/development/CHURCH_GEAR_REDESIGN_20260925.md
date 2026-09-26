# 封线装备页重设计（2026-09-25）

## 页面与操作

- 旧页只是按取得顺序堆放文字卡片，每件未穿戴装备都有一个相同的大按钮；看不出当前两个栏位穿的是什么，也不易比较。现改为「当前装备」武器／护甲双卡 →「更换装备」分栏 → 点一件预览差异 → 底部唯一的「穿戴」按钮。
- 当前装备卡直接显示物品图、名字和已生效的实战属性。列表只显示该栏位已拥有但未穿戴的装备，按既有 `strength` 降序；切换栏位会取消上次预选。选择前不显示最终操作，避免误触。选择后显示与当前装备的伤害、生命和减伤差异；仍允许换回较弱的旧装备。
- 明示规则：武器、护甲各一件；新获得更强装备会自动穿戴，已拥有的旧装备可手动换回。装备发放、属性、自动穿戴优先级、持久化和战斗计算未改。真机 QA 没有点最终穿戴，保留用户当前装备与存档。
- 仅背景使用现成 `ChurchJointSanctuary` 场景图，并与暗渐变叠加。Build 90 的初始画面位于状态栏下方，但后续用户截图证明滚动后页头仍可被推入状态栏；下面的初始位置检查不能代表滚动安全区验收，后续修复另见 `CHURCH_GEAR_HEADER_BUTTON_20260925.md`。
- 本批修改前源码留在 `backups/church-gear-redesign-20260925/prechange/ChapterOneTestView.swift`。

## 美术

使用内置 imagegen（非 CLI），以现有 `ChurchJointSanctuary` 仅作旧金、石板、烛光材质风格参考，生成真正带 alpha 的单件物品插画。原生成文件留在 Codex 的 generated_images，本项目入包副本为：

| 游戏物品 | 图片组 |
| --- | --- |
| 石颚裂刃 | `mistport-ios/Mistport/Assets.xcassets/ChurchGearJawEdge.imageset/art.png` |
| 井口封甲 | `mistport-ios/Mistport/Assets.xcassets/ChurchGearSealPlate.imageset/art.png` |
| 盐痕短刀 | `mistport-ios/Mistport/Assets.xcassets/ChurchGearSaltKnife.imageset/art.png` |
| 双颚护胄 | `mistport-ios/Mistport/Assets.xcassets/ChurchGearJawGuard.imageset/art.png` |
| 金喉铃护 | `mistport-ios/Mistport/Assets.xcassets/ChurchGearBellThroat.imageset/art.png` |

生成提示词共用部分：`Use case: stylized-concept; Asset type: isolated painted equipment art for dark fantasy mobile RPG 雾港; Input images: church sanctuary image as STYLE reference only for old gold, slate and candlelit painterly rendering; polished anime-fantasy game inventory object readable at 90 points; one complete object centered with clear margins; genuinely transparent background; no character, panel, border, room, text, letters or watermark.`

逐件主体提示词：

- 石颚裂刃：单手黑色玄武岩颚骨剑，不对称缺齿刃、旧铜护手和小范围紫色裂纹；强调它是可用的剑而非徽记。
- 井口封甲：深灰金属胸肩甲、旧铜肋条、中央井口封印和褪色红蜡封；强调它是护甲而非盾。
- 盐痕短刀：短而微弯的盐蚀钢刃、淡蓝矿纹、皮柄与窄铜护手；强调是短刀而非长剑。
- 双颚护胄：完整胸甲配向内咬合的双颚肩甲、暗钢、旧金铆钉与微弱紫缝；不生成兽头。
- 金喉铃护：可穿戴的铜金护颈及上胸甲、颈前小铃、绿紫珐琅细节；不生成活蛙或人物。

其它目前未取得的 19 件目录装备仍使用明确的武器／护甲栏位符号，绝不借用别件插画冒充。本批没有声称完成全目录逐件美术。

## 验证

- iPhoneOS Debug 签名 Build 90 构建通过，`codesign --verify --deep --strict` 通过；`assetutil` 确认五张新图入 `Assets.car`。`ChurchGearTests` 2 项通过。
- 已覆盖安装 iPhone 13；设备应用列表为 `0.1.0 (90)`。安装前、安装后、启动后 `Library/Preferences` 逐文件相同，副本在 `backups/church-gear-redesign-20260925/device-*`。
- iPhone 镜像实看新版首页、武器栏、选中后的底部确认、护甲栏及护甲差异；初始位置标题在状态栏下方，图像和文字可见，预选切栏会清除。此轮没有覆盖滚动后的页头位置，因此漏掉了用户随后发现的刘海问题。未做最终穿戴的真机存档变更测试；未来更多装备图片与其它机型、放大字体仍待另验。
