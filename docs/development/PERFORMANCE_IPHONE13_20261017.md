# iPhone 13 卡顿排查与第一轮优化（2026-10-17）

用户 10-17 装上 172.2 后反馈："好卡，我是iphone 13，请全面梳理代码和美术资源"，并说"改完直接装机"。

三个只读排查并行进行：Unity 每帧代码、美术资源、App（SwiftUI）每帧开销与编译配置。报告要点和本轮改动如下。数字来自读代码和读资源，**没有在手机上做性能采样**。

## 最大的问题：手机包一直是 Debug 编译

- 出包用的是 `xcodebuild -configuration Debug`。Unity 子工程于是走 Debug 配置：IL2CPP 以 `--configuration=Debug` 生成，C++ 的 `GCC_OPTIMIZATION_LEVEL = 0`。Swift 也是 `-Onone`。
- 所有游戏代码都没有优化。估计主线程上的开销是正式包的 2–4 倍。
- 不能直接切到 Release，因为机构试玩的存档选择（`mistport.institutions.playtest.20261013.<profile>`）、开发者工具和各种审阅参数都写在 `#if DEBUG` 里。直接切 Release 会读到另一份存档。
- **做法**：用 Release 配置编译，同时传 `SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG`。
  - Swift 用 `-O`，整模块编译；Unity 走 Release 配置（IL2CPP Release，C++ 开优化）。
  - 所有 `#if DEBUG` 路径照旧。包里能找到存档套件名，显示名为"雾港"，签名通过。
  - `scripts/build_institutions_playtest.sh` 已改为这样出包。

## 本轮改动（都不改玩法；画面上只有分辨率和雨量两处变化）

### Unity 项目设置

- 骨骼蒙皮改为 GPU（Batched）：`gpuSkinning: 1`、`meshDeformation: 2`。之前所有蒙皮网格都在 CPU 上算，包括新猎犬的 8.5 万个三角形。
- 分辨率改为按固定 DPI 缩放：`resolutionScalingMode: 1`、`targetPixelDensity: 370`。在 iPhone 13（约 460 dpi）上约为原生的 0.8 倍，像素数约为原来的 0.64。
- 加速度计频率设为 0（运行时没有代码读取）。

### Unity 每帧代码

| 文件 | 原来 | 现在 |
|---|---|---|
| `BattleRain.cs` | 3200 滴，C# 每帧逐滴更新，粒子每帧按距离排序 | 1800 滴，不排序 |
| `SpellSpectacle20260926.cs` | 每次敌人出招后 4.5 秒内，每 0.1 秒 `FindObjectsByType<Transform>` 扫全场；每帧对旧特效根节点 `GetComponentsInChildren<Renderer>` | 只看场景根物体；渲染器在扫描时缓存 |
| `SpellBloom20261008.cs` | 每帧读每个渲染器的材质名、新建材质数组 | 按材质缓存是否发光；复用列表。辉光的分辨率和层数不变 |
| `EarlyEnemyIdlePresence.cs` | 每个敌人每帧翻遍骨骼树找"该动哪个模型"，还多次 `GetComponentsInChildren` | 模型换了立刻重找，平时每 0.25 秒一次；特写组件缓存 |
| `UnityBattleBridge.cs` | 每帧 `FindFirstObjectByType<BattlePrototype>`；每 0.12 秒两次 `FindObjectsByType<EnemyHandle>`；血条/特效锚点每次都发 | 战斗对象缓存；一次查找两处共用；锚点改为 3 位小数，没变就不发（每秒至少补发一次，保证重打后有血条） |
| `CombatTempoPresentation.cs` | 每帧新建一个 `List<string>`；AI 主角替换 3D 主角后，3D 主角的飘带、表情、逐像素补光灯还在跑 | 复用列表；替换时暂停这三个组件，恢复时再打开 |
| `BattlePrototype.cs` | 手机包里也有 `OnGUI`（方法体是空的），旧 GUI 系统每帧仍要排版和重绘；猎犬头顶补光灯可能被当成逐像素光，整只猎犬多画一遍 | `OnGUI` 只在编辑器和桌面版编译；补光灯改为 `ForceVertex` |
| `ShadowfangHound20261016.cs` | `updateWhenOffscreen = true`，每帧重算蒙皮包围盒 | 关闭 |
| `EnemyTargetSigil.cs` | 四足敌人每帧找人形动画器（找不到） | 同一模型只找一次 |
| `OvalLightShield.cs` | 光盾每帧对身体 `GetComponentsInChildren<Renderer>`，并对每个渲染器查父组件 | 渲染器列表每秒刷新一次，位置仍逐帧跟随 |

隐藏的 3D 主角上，背后材质刷新（`HeroBackArtRefinement`）和手指关节（`HeroFingerArticulation20260917`）**保留运行**：一起暂停时，录制器 H07 的"双脚离地"检查单独跑会失败。

### App（SwiftUI）

| 位置 | 原来 | 现在 |
|---|---|---|
| `ChapterOneTestView` 卡牌冷却圈 `ClockwiseCardCooldown` | 每张卡（约 12 个）各一个 30 Hz 的 `TimelineView`，冷却结束后也不停；同时还按战斗时钟重画 | 有战斗时钟就直接用它画；只有没传时钟时才用计时器，并在冷却结束后停 |
| 勋章、面具按钮 | 各一个 20 Hz `TimelineView`，内容读的却是战斗时钟 | 去掉计时器 |
| SpriteKit 透明叠层（Unity 战斗时） | 60 帧 | 30 帧。它在 Unity 战斗里只放纸人碎裂、战败这类偶发效果 |
| `UnityBattleHost` 锚点 | 每次收到都赋值，整页重绘 | 有变化才赋值 |
| `UnityBattleHost.attach` | 每次 `updateUIView` 都把 Unity 视图拆下再装上、重设主窗口 | 已挂好就跳过 |
| Unity 暂停 | 启动预加载后一直全速跑，城市界面时也在跑 | 预加载 6 秒后、离开战斗 0.6 秒后暂停；进战斗时恢复 |
| `CityLivingScene` | 30 Hz 在 CPU 上绘制约四屏宽的全景 Canvas；还有两张 0.001 透明度的全屏大图常驻合成 | 20 Hz；去掉那两张隐藏大图（天色切换的那一下可能顿一下） |
| `LaunchAssetPreloader` | 启动时解码并常驻 28 张图，约 255 MB | 只常驻 2048×2048 以内的。4096 全景和 5504 宽的世界地图（各 64 MB）用到时再解码 |
| `WisteriaMap/viewer.js`（城市 3D 地图） | 像素比 2，每帧都渲染 | 像素比 1.5，限制 30 帧 |

## 验证

- **编译**：App 编译 0 错误（模拟器 SDK 的 typecheck 不覆盖 `#if canImport(UnityFramework)` 分支；该分支由设备构建编译）。Unity 无 `error CS`。
- **编辑器录制**（SF1、SF2、M01、M05、M07、H01、H07、H10）：
  - 安全检查 118 项全过，录制和安全两次源码一致。
  - 录制只有 H07"双脚离地 0"一项失败。用改动前的代码按同样的行顺序跑，同样失败；单独跑 H07 时，改动前后都通过。这是原本就有的、和录制顺序有关的问题。
- **手机**：见 `HANDOFF_20261015.md` §15。

## 还没做（按影响排序）

1. **战斗界面本身**：`ChapterOneEncounterTestView` 约 4000 行，每个战斗步进（`battleTime += 0.05`，每秒 20–40 次）整体重算。要把时钟和战斗状态移到不被观察的引擎对象里，按 10–15 Hz 发布一个小的界面快照，并把界面拆成可跳过的子视图。这是一次较大的重构。
2. **城市 3D 地图贴图**：22 张 2048² 的人物贴图，加一张 5504×3072 的环境贴图，WebGL 里约 450 MB。人物在地图上很小，可降到 512²；有两对重复的贴图和网格；有约 39 MB 没被引用的文件。
3. **城市全景大图**：20 张 4096×2305 的季节/时段图，每张解码后 36 MB，屏幕上同时会有 2–3 张。可以降到 3072 或 2560 宽。
4. **战斗场景**：`BattlePrototype.unity` 里烘焙了 6 个通缉/特写敌人模板，加上钟卫（9 万三角形）、钟核、记忆蛭、旧 3D 主角，每场战斗都带进约 142 MB。应改成按关卡加载。
5. **3D 主角在 AI 主角替换后仍常驻**（约 45 MB 贴图），每场开局还要解析 10 MB 的 `HeroPremium/head.json`。
6. **`beam-wraith-scream-v1/Meshy/image.fbx`**：196 万三角形，放这招时才 `Resources.Load`。要减面，或者换成 2D。
7. **贴图**：`HeroCostumeAlbedo` 是 4096 + ASTC 4x4（21 MB）；三张法线贴图被当成普通贴图导入；34 个 FBX 开了 Read/Write；新猎犬身体可以做 1–1.5 万三角形的手机版。
8. **`Resources` 里不用的源文件**：Meshy 动作 FBX 内嵌了 27–43 MB 的贴图，还有 Dunhuang 测试角色、`.efkproj` 源文件，合计数百 MB。
