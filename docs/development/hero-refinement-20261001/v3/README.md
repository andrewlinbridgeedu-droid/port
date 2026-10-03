# 主角 v3：手绘质感与动作微调

用户看过 v2 后要求继续细化、动作略放大，且不要明显的 3D 感。本版在 v2 的三套服装与共用骨骼上继续制作，v2 及更早稿原路径保留作对照；**没有记录为用户视觉认可**。

先看 [新版与 v2 并排预览](review.html)。主图和动作视频是 Unity 实际播放；Blender 检查图使用独立的柔和灯光，并非最终 Unity 材质效果。仍是真实蒙皮模型，没有把人物图片贴成卡片冒充动画。

## 本版改变

- 头发改成更薄、宽窄不同的分层发束，加入不规则细碎发和绘制般的深浅层次；清掉后颈旧模型残留边缘。
- 肩背增加贴合衣料的细线卷叶刺绣与藤茎，收细原来的金属线；靴面重新使用保留的来源 UV 贴图，显示原有纹样、缝线和材质细节。
- 全部角色与服装使用柔和的插画材质：取消物理镜面高光、金属反射、光滑轮廓反光和凹凸高光。衣料颜色与织锦保留，黑衣提升少量色阶以保留褶皱，只用少量平滑明暗表现形体，避免白衣被强高光冲掉。它仍在 3D 场景中运行，不能把作者的风格判断当作用户认可。
- 施法手臂目标轨迹扩大 10%，转体、手腕稍增幅；肘部继续限制在自然臂长内，衣摆保留延迟跟随。由于关节限幅，不能宣称每个画面位置都精确扩大 10%。释放时间、动画时长、伤害和结算未改。
- 三套现有 outfit ID 共用 28 骨骼、14 条动作，分别制作衣装。只接 Q4／D01／B01 三场样板；退出恢复旧模型。换衣不重建 Animator，也不更换场景。

## 验证与限制

运行报告见 [unity-verification.txt](unity-verification.txt)，源文件哈希见 [verification.json](verification.json)，Mac 构建来源见 [mac-build.json](mac-build.json)。最终检查三套衣装各七次动作播放、十二次生产施法（×1／×2），以及实际材质是否全部使用受支持的插画 shader、衣装选择、机位、回位、唯一命中回执、换衣时保留动作进度与离开样板取消延迟回执。

21 段动作各 48 帧、30 fps，三套连续版按顺序拼接；七段与 v2 并排使用同一 Unity player、同一场景和相同全身取景规则（45° 视角，按当前蒙皮高度取景），保留每段全部帧、不快放。[媒体完整解码记录](media-check.json)核对全部片段。[实际位移对照](motion-excursion.json)测得七手势右手最大位移增加约 9.7%–11.4%，不把这个单项指标当作自然度认可。900×1350 的查看截图与片段不是 iPhone 录像。

本版未重新导出 Unity iOS、未构建宿主、未装机，真实手机上的外观与性能未测。手机最新已知是另一项界面任务的 169.24，没有 v3。本轮没有连接或更改手机 Preferences；后续装机仍须 SSD 构建、新鲜度检查和 Preferences 逐文件核对。PR #41 继续草稿，不铺其他战斗。

## 原件与复跑

[Blender 原件](HeroMeshy-v3.blend)、[动作与模型清单](manifest.json)。原用户 GLB 与 v2 保持不变；三张 ImageGen 织锦沿用 v2 原图，提示词保留在 [texture-prompts.json](texture-prompts.json)。本版没有程序补画 PNG，也没有外部动作库。

在 SSD 工作区：

```sh
MISTPORT_HERO_SKIP_RENDER=1 /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/animation/build_meshy_hero_v3.py -- "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/animation/render_meshy_hero_v3.py -- "$PWD"
```

Unity CLI 传项目绝对路径，执行 `RefinedHeroV3Import.BuildPreview`，`-previewPlayerOutput` 放 SSD。每轮选新的空目录，设 `MISTPORT_HERO_CAPTURE` 并启动 Mac player 的 `--verify-refined-hero`；另一新目录加 `--hero-v2 --hero-reference-capture` 生成 v2 对照。两个目录完整通过后才用 `package_meshy_hero_v3.py <v3目录> <v2目录>` 打包（Python 依赖 `imageio-ffmpeg==0.6.0` 安装在 SSD 隔离 venv）。`--hero-bounds-only` 是局部排查，不算完整验证。
