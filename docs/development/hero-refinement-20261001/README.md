# 主角背影与施法动作 · 2026-10-01

**最新：v1 未获认可，继续重做。** 用户要求达到金紫长外套参考的精细度，并提供带贴图 GLB 与白模；两份源素材已实际打开并检查，形体几乎一致。素材判断、三套服装的制作边界和未达目标的建模试验见 [最新素材检查](SOURCE-ASSESSMENT.md)。以下是 v1 的历史实现与验证，不能当成新底子的验证或用户认可。设备已由独立界面任务更新到 169.24，该安装包未包含本目录的新主角。

用户要求先用 ImageGen 出稿，再用 Blender 重做粗糙的主角背影，增加流畅、自然、迅速的施法动作。追加要求已澄清：根据所选服装更换主角背影，战斗背景保持原样，各套服装共用动作。

先看[模型与动作预览](review.html)。ImageGen 图只作造型参考；对比图和动作视频来自真实 Unity 模型运行，不把参考图当成模型渲染。近景使用独立查看镜头；完整机位图保留正式战斗镜头。两者都不是 iPhone 证据。

## 改动

- 新增可编辑的[Blender 原件](HeroRefined-v1.blend)，保留旧模型和旧动作库。以现有授权 Meshy 主角为基础，增加收腰后背、立领、深色外层与紫色内衬、分开的弧形衣尾、金色叶纹、袖口、宝石、链饰、飘带与分层发束。衣尾与飘带有独立蒙皮骨骼；修复剥离旧衣尾后露出的后腰空隙。
- 雾港夜行、星辉魔术师、午夜嘉年华使用同一蒙皮与动画控制器；分别切换紫黑、白蓝、金红表面及星纹／嘉年华饰纹。App 发送本场真实 `session.loadout.outfit`，没有新增玩家偏好键。换衣不重建 Animator，不改动画进度，不换战斗背景。
- 14 条共享动作包含待机、三种普通攻击、招架、受击、兼容准备动作，以及七种新施法手势：翻出假面、转身递面、双影展开、双影交错、抬幕收场、掷幕谢场、展牌。假面、双影和收场各交替使用两种手势。肩、肘、腕顺序运动，衣尾延迟跟随，完整回位。各衣装使用相同动作，手势变化不由衣装决定。
- 三场样板 Q4、D01、B01 显示新蒙皮，不再仅用导出骨架驱动旧背影。退出样板恢复原模型。当前不铺其他战斗，符合用户此前“样板认可之前不铺开”的要求。

## 验证与范围

[运行记录](unity-verification.txt)与[源文件哈希](verification.json)记录三种服装、七种真实动作、十二次生产施法（两种手势 × 三个技能 × 两档速度）、切换服装保留动作时间、退出样板取消延迟命中回执。每次生产施法恰有一次玩家命中回执；身体动作检查都回到待机。七段视频各保留 48 帧、30 fps；连续版顺序拼接，没有加速或抽帧。

本轮规则、伤害、价格、体力、主线进度、玩家存档均未改；未重新声称此前 564 项规则检查属于这次复跑。未改首页原画、战斗背景、既有法术特效或原有敌人资源。未获得用户视觉认可，PR #41 继续草稿。新版没有装机，手机仍是此前的 169.22；本轮没有触碰手机 Preferences。

[169.23 构建记录](ios-build.json)：Unity iOS 导出逐文件新鲜度通过，SSD 上的宿主 Debug 构建及签名包校验通过。首轮宿主编译发现服装字段为可选值，补上 `.mistportNight` 默认值后重新通过；没有把首次失败算作通过。构建成功不代替真机复看，本轮不安装。

ImageGen 使用内置工具，参考现有 CharacterFoolBright 与旧 Unity 主角背影；[完整提示词](imagegen-prompt.txt)、[参考稿](hero-back-concept-v1.png)已入仓库。没有使用外部动作库或下载 mocap；七种动作均在 Blender 中原创制作。

## 复跑

1. 在当前 SSD 工作区运行 Blender：`Blender -b --python tools/animation/build_refined_hero.py -- "$PWD"`。
2. Unity 执行 `RefinedHeroImport.BuildPreview`，明确给出 SSD 上的 `-previewPlayerOutput`。该方法只导入新主角资产，不重建旧敌人控制器。
3. 为每轮选择新的空目录，用 `MISTPORT_HERO_CAPTURE` 指向该目录，启动 Mac player 的 `--verify-refined-hero`。脚本 `tools/animation/package_refined_hero.py` 只打包本轮 runtime-release 的通过结果。
4. iOS 导出显式设置 `MISTPORT_UNITY_IOS_OUTPUT="$PWD/mistport-ios/UnityBuild"`；`scripts/check_unity_export_freshness.sh` 通过后才构建宿主，DerivedData 在 SSD，编号低于 170。
