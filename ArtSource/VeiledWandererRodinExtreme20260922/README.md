# 乌檀 Rodin Extreme-High 试作（2026-09-23）

原画：`reference.png`，与先前试作同一张，SHA256 见 `generation-record.json`。

- [本次独立 Rodin 成品](https://hyper3d.ai/workspace/rodin/ca53b99e-7965-4314-8c90-1b6b5770d9d4)：Gen-2.5 Extreme-High 几何，Detail 5，Front 参考，确认阶段选择 Triangle 2M；Native High 材质，勾选 8K 和 Face Restore 后重做并确认。模型设为私有。
- [旧版 Rodin 成品](https://hyper3d.ai/workspace/rodin/03b62c22-c7db-48cc-a578-41828e618885)：Gen-2.5 High，旧版 Blender 四视角见 `../../output/veiled-wanderer-rodin-20260922/index.html`。
- 12K 材质在当前账户弹出 Business 订阅限制；没有订阅。Pack 页的 8K 选项点击后未成为选中态，因此不能宣称 8K 已导出。网页中确认的是材质生成时勾选 8K。

视觉观察：本次紫黑袍、青绿袖里、金纹、铃与法杖轮廓比旧版稳定；帽顶白斑缩小，但帽檐仍有明显浅色片。正面脸仍被帽檐和头发遮住，三分之四角度略能看见面部；单张正面原画推断的背面较素。Face Restore 没有解决几何遮挡。画面仍不能达到原画精度或正式角色标准。

曾用 4K Pack 尝试 GLB（Shaded+PBR、仅 PBR、仅 Shaded）；每次网页打包进度结束后都未收到下载事件，本地 Downloads 也无该文件。故本目录只有参考图和记录，未导出新 GLB、未重导 Blender、未验证实际三角面数及贴图分辨率，也未做减面、绑定、动画或游戏接入。`inspect_rodin.py` 和 `make_blend.py` 只是为后续成功取回 GLB 预备，尚未运行。
