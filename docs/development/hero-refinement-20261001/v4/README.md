# 三套新 GLB 主角：材质、蒙皮与施法精修

用户提供 Amethyst Sovereign、Starlit Sovereign、Crimson Regent 三份带贴图 GLB，要求按原型 2D 质感继续细化、去掉不自然的“膜感”，并接上现有动作。过程中用户明确指出的是**整条手臂反扭与手掌后翻**，不能把这一问题仅解释为袖口拉伸。

**当前状态（用户转向 AI 动画试验时）**：Blender 手臂修正版已保存，14 条动作 752 帧的骨骼朝向检查通过；尚未重新导出本次修正的 Unity Mac 运行预览。下列 Unity 与媒体打包是待完成验证项，已有 SSD `runtime-v4-final` 实为手臂修正之前的版本，不可当作本次修正后的证据。用户要求先试三张 2D 原图直接生成动画，见 `../../hero-ai-animation-20261002/`。

待补全入口：[三套衣装与动作预览](review.html)。右侧主图与动画为实际 Unity Mac player；2D 原型、Blender 独立检查图分别标明。原型是质感与配色参考，Meshy 重建的部分饰纹仍与 2D 原图不同，不能声称逐笔还原或用户已认可商业成品。

## 已做的修改

- 分别保留三份下载原件与 SHA-256。源模型约 84 万／105 万／135 万三角面，无骨骼、无动画；运行网格各保留 18 万三角面，三套轮廓、原有 UV、饰纹和衣料不混成一套换色材质。
- 取消物理镜面、金属环境反射和凹凸高光；使用原色、浅接触阴影和有限的插画明暗。头发区域另有顶点遮罩，压掉来源图中的绿色残色，不改变青色衣带。
- 每套烘焙 4096×4096 运行图集。**原始颜色贴图只有 2048×2048，4K 图集加入的是高模浅接触阴影，不等于重新画出原生 4K 色彩细节。**原贴图与 GLB 留存，未将放大写成新增画面细节。
- 三套 T 姿势适配一套 50 骨骼和一份 Animator：保留原 28 骨骼体系，补 20 根手指骨与两根袖带骨；星辉原件较短的手臂先校准，再共用动作。
- 蒙皮限制每点最多四项权重，按网格边的实际距离平滑，避免简化网格中的长边将上臂权重带入袖口。重新区分鞋、裤腿、衣摆和飘带。
- 针对整条手臂反扭：上臂以肩背朝向建立完整旋转坐标，肘部采用向外的稳定弯曲提示，前臂沿同一肘部弯曲，不再独立求一套会翻面的上臂朝向。动画四元数逐帧保持同号，避免等价旋转在插值时走反方向。另给加长的手掌留出躯干避让空间。
- 手指在蓄势和出招间轻微开合；夜行袖带保持下垂与跟随，不随手臂刚性横穿后背。14 条动作的名称、时长、释放点继续沿用；七种施法共用同一套动画，服装切换不改场景、机位或动画进度。
- Unity 仍只用于 Q4、D01、B01 样板，退出样板恢复原主角。保留 `--hero-v3`／`--hero-v2`／`--hero-v1` Mac 对照入口，旧资源与历史图稿不覆盖。

## 验证证据与边界

- [骨骼朝向检查](arm-orientation.json)：检查 14 条动作的每一帧，包含上臂朝向、前臂轴向偏差、四元数连续性和角速度跳变。此项针对“反扭”，不同于只验证手的位置有移动。
- [蒙皮诊断](skin-diagnostics.json)：三套 × 14 动作 × 六个阶段，252 个姿势；检查有限坐标、归一化权重、影响数和网格拉伸分布。保留实际最大值，不把有限坐标或某个阈值当作“没有任何穿插”的证明。
- [Unity 运行检查](unity-verification.txt)、[运行来源与资源哈希](verification.json)、[Mac 构建来源](mac-build.json)：三套各七种实际动作、十二次生产施法（×1／×2）、唯一命中回执、换装与取消后的状态、4096 图集和材质支持。
- 动作片每段 48 帧、30 fps，900×1350；三套连续片各包含七动作。v3 对照使用之前保存的实际 Unity 记录，相同场景与全身取景规则，未使用本版重画的“旧版”。手臂修正对照另外保留修正前实际运行帧。
- 本版没有导出 iOS、构建宿主或装机，也没有访问手机 Preferences。没有 iPhone 外观或性能结论；三套 18 万三角面的运行成本仍需真机核对。最新已知手机仍是另一个界面任务的 169.24。PR #41 保持草稿，所有作者检查均不代表用户视觉认可。

## 原件与复跑

- [完整 Blender 文件](HeroSovereign-v4.blend)、[模型与动作清单](manifest.json)、[源文件记录](source-manifest.json)。
- `sources/*/original.glb` 为逐字节副本，下载原件没有改写。
- `reference/*-back-4k.png` 是此前已生成的 2D 背影原图，不是本次运行截图。

在 SSD 工作区运行：

```sh
/Applications/Blender.app/Contents/MacOS/Blender --factory-startup -b -t 6 --python tools/animation/build_meshy_hero_v4.py -- "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --factory-startup -b -t 3 --python tools/animation/render_meshy_hero_v4.py -- "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --factory-startup -b --python tools/animation/verify_meshy_hero_v4.py -- "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --factory-startup -b --python tools/animation/verify_hero_arm_orientation_v4.py -- "$PWD"
```

`--no-bake` 只复用已经完成的 UV 图集，重做蒙皮和动作；首次制作不得跳过烘焙。Unity 执行 `RefinedHeroV4Import.BuildPreview`，`-previewPlayerOutput` 放 SSD。设置新的空目录 `MISTPORT_HERO_CAPTURE`，启动 player 的 `--verify-refined-hero`；完整通过后，才用 `package_meshy_hero_v4.py <本版帧目录> <v3 原始帧目录>` 打包。
