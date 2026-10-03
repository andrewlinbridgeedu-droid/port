# Meshy 主角 v2 · 三套衣装与共享施法动作

本版以用户带贴图 GLB 为身体基础，按用户的金紫长外套参考重做背影。用户白模保留作形体对照；两份下载原件、v1 模型、旧动画和早期静态试验均原路径保留。这里是候选模型，精细度与动作效果仍由用户复看决定，未记录为视觉认可。

先看 [三衣装／动作预览](review.html)。Blender 图来自可编辑模型渲染，Unity 图和视频来自 Mac 实际播放，不是 iPhone 图或录像。近景按模型当前全身高度、45° 视角取景；正式战斗图保留生产场景和机位。没有把角色参考图贴成卡片冒充模型。

## 模型与衣装

- 保留来源身体比例、皮肤 UV、手与腿；焊接几何 UV 接缝后细分，重新制作分层发束、闭合头皮与颈部、袖口、衣尾厚度与褶皱、内衬、金属叶饰、链扣、宝石和靴带。链饰跟随衣尾表面，靴带贴合实际靴面。
- 雾港夜行：黑紫金长衣尾，紫衬与单侧青色飘带。
- 星辉魔术师：白蓝金外套，更长的蓝衬衣尾、短披肩、双侧青色飘带。
- 午夜嘉年华：黑红金短些的非对称衣尾，红衬与红飘带、肩部金流苏。
- 三套有独立服装网格，按现有三个 outfit ID 选择一套；共同身体、28 骨骼和控制器保留，换衣不重建 Animator、不换场景。所有衣装合计 185,657 顶点，不代表手机上同时显示三套；未选衣装的 renderer 禁用。材质分组合并以减少绘制批次；真实手机性能仍未测。
- ImageGen 先生成三张织锦布料的颜色贴图，再用于实际 3D UV 表面；完整提示词与原图见 [texture-prompts.json](texture-prompts.json) 和 `textures/`。原图未经程序重绘或补画。

## 动作

14 条 Blender 原创动作共用，包括待机、普攻、刺击、出牌、招架、受击、准备，以及七种施法手势：翻出假面、转身递面、双影展开、双影交错、抬幕收场、掷幕谢场、展牌。

施法有肩、肘、腕传递，躯干重心变化和衣尾／飘带延迟跟随。假面、双影、收场各交替两个动作；服装不决定手势。身体动作的播放速度与已有命中时间匹配，未改 Swift 规则、伤害或奖励；法术主体与既有 VFX 本轮未改。

Unity 只替换 Q4、D01、B01 三场样板的主角；离开样板恢复原模型。`--hero-v1` 只用于 Mac 历史对照，iOS 不开放这个命令。

## 验证与交付状态

最终运行结果见 [unity-verification.txt](unity-verification.txt)，资产和源代码哈希见 [verification.json](verification.json)，Mac 构建来源见 [mac-build.json](mac-build.json)，31 段视频完整解码与帧数见 [media-check.json](media-check.json)。最终实际播放通过：三套 × 七动作共 21 次、十二次生产施法。检查三套独立衣装可见性、共享控制器、生产场景机位不随服装改变、七动作各回到待机、两档速度的命中回执、换装保留动作时间与离开样板取消延迟回执。新增实际蒙皮全身取景与生产机位可见性检查。

21 段动作各 48 帧、30 fps；三段连续版按动作顺序拼接。七段 v1／v2 并排保持各自完整帧序列，采用相同全身取景规则，未抽帧或快放。作者观察和探针通过都不等于用户视觉认可。

本版尚未重新导出 Unity iOS、构建宿主或装机。手机最新已知为独立界面任务的 169.24，没有本版主角；本轮没有连接或改动手机 Preferences。后续装机仍须 Unity 新鲜度、SSD 宿主构建（169.x，低于 170）和安装前后 Preferences 逐文件核对。PR #41 保持草稿，不铺其他战斗。

## 可复跑原件

[HeroMeshy-v2.blend](HeroMeshy-v2.blend) 是实际带蒙皮、材质和动作的 Blender 文件，Unity 运行资产在 `UnityBattleSource/Assets/Resources/CombatTempo/RefinedHeroV2/`，与 v1 分目录保存。

在 SSD 工作区运行：

```sh
MISTPORT_HERO_SKIP_RENDER=1 /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/animation/build_meshy_hero_v2.py -- "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/animation/render_meshy_hero_v2.py -- "$PWD"
```

Unity CLI 必须传项目绝对路径，不能把 `UnityBattleSource` 相对路径误解析到其他 checkout。执行 `RefinedHeroV2Import.BuildPreview` 并将 `-previewPlayerOutput` 明确放到 SSD。

打包需要 Python `imageio-ffmpeg==0.6.0`，本轮安装在 SSD 的独立 `media-venv`，未改 App 依赖。

每轮 `MISTPORT_HERO_CAPTURE` 指向新的空目录，运行 Mac player `--verify-refined-hero`；另建目录用同一个 player 加 `--hero-v1` 生成历史对照。只有最终两个目录均包含通过记录且没有失败文件时，才用 `tools/animation/package_meshy_hero_v2.py <v2目录> <v1目录>` 打包。`--hero-bounds-only` 是局部排查取景命令，不算完整通过。
