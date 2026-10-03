# 三套原画直接生成施法动画 · MiniMax 试样

**接入状态**：用户看过全身投掷后明确“好啊，接入游戏”。三套各五段现已接到 Q4、D01、B01，见 [游戏内预览](integration/review.html) 与 [接入验证](integration/README.md)。下面的“不接 App”是首轮生成时的范围，不代表最新状态；游戏内效果仍待复看。

最新：用户已表示首轮“很好”，允许三套动作不同，随后确定每套 5 段。见[五组动作选稿](motion-library/review.html)，包含首轮三段；作者暂未选入的两类另有[完整原片预览](motion-library/rejected-review.html)，用户正在复看，不代表用户否决。下面是首轮制作记录。

用户在指出 3D 动作整条手臂反扭后，要求用三张现有原画直接试 AI 动画，并提供本轮 MiniMax 凭据。先保留 Blender 工作，改做这个独立试样；不接 App、不装机，不更改真实存档。

- 来源：此前已生成的三张 2160×3840 透明背影原图，见每套 `*-request.json` 的来源路径和 SHA-256。
- 预处理：原尺寸人物原样铺在暖灰纯色底上，转换 RGB PNG 供图生视频；没有重绘角色。
- 请求：`MiniMax-Hailuo-2.3`，每套各 6 秒、1080P，关闭 prompt optimizer，三套使用相同完整动作提示词。调用状态与 task ID 保留，但凭据及临时签名下载链接不入仓库。
- 动作：固定背面全身镜头，脚不移动；短蓄势、自然抬右臂、快速前挥、收回原位；衣尾、飘带和头发跟随。不加光效，以便观察手部与细节。
- 三次独立生成不等于三套共享一份动画，也不能宣称逐帧一致。结果为视频，还不是透明序列帧或可交互的游戏角色；是否适合继续由观看结果决定。

[并排查看](review.html)。生成与下载记录见 `*-task.json`、`*-status.json`、`*-result.json`。三套已完成，实际各为 1080×1920、24 fps、141 帧、5.875 秒；全部完整解码通过，见 `media-check.json`。作者抽看每套 12 张全身帧及施法中的上半身局部，观察记录见 `quality-review.json`。

画风、服装线条和原图更接近，但动作没有严格按提示词执行：夜行偏双手对称抬起，白衣和红衣出现较长的交替手势；三套的主手、节奏和幅度不同，手部及局部饰纹仍有变化。首尾未保证无缝，当前不能直接作为共用的一套战斗动作。此次仅生成三条，未额外付费重试。

官方接口依据：[图生视频](https://platform.minimax.io/docs/api-reference/video-generation-i2v)、[任务状态](https://platform.minimax.io/docs/api-reference/video-generation-query)、[下载](https://platform.minimax.io/docs/api-reference/video-generation-download)。

复跑工具：`tools/animation/minimax_hero_trial.py`，凭据从仓库外权限为 600 的文件传入；已存在 task ID 时拒绝重复提交，使用 `status` 查询及下载。
