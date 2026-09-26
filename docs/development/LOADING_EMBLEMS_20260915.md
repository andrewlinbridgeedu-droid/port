# 加载与入场徽记原画
采用内置 image_gen 生成两张带透明通道的紫金游戏位图，保留原始生成文件，项目资产存入 Assets.xcassets 的 LoadingHourglass 与 BattleRitualSeal。
旧 SwiftUI 与项目配置备份：backups/loading-emblems-20260915。

- 加载：实物金属沙漏替代系统符号及虚线圆环，160pt，轻微悬浮与呼吸光；移除翻转造成的薄片视觉。
- 入场：浮雕钟盘、紫晶与厚金属边替代细线圆阵，210pt，保留阶段缩放/旋转/淡出，移除放射细线。
- 不修改剧情、关卡、战斗机制、存档与测试入口。

## 生成提示词（内置工具）
1. Premium dark fantasy RPG UI ornate ancient hourglass, heavy antique gold and blackened bronze frame, thick beveled caps with violet gems, shaded glass with luminous violet sand and warm golden sand below, embossed gothic detailing. Upright frontal symmetry, readable at 160px, realistic material depth and crisp highlights, purple/gold palette. Actual transparent background, isolated object, no diagram, lettering, watermark or UI.
2. Production dark fantasy RPG battle entrance emblem, ornate circular ancient clockwork ritual seal, front view. Thick layered antique gold and blackened bronze concentric rings, sculpted gothic relief, twelve substantial gold hour markers, amethyst gems, recessed purple enamel, central violet diamond in raised golden bezel. Readable at 220px, transparent background, no text, numbers, thin schematic lines or watermark.

## 验证边界
两张生成图已目视检查，sips 确认 alpha 通道。原生构建和真机安装结果以构建日志与设备返回为准；尚无新图在手机中的实拍验收。

Build 8：xcodebuild BUILD SUCCEEDED；已安装并启动 iPhone，设备回执见备份目录。安装前后存档比较：False。测试入口：True。
