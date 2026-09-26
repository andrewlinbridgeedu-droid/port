# 项目资源与战斗音频盘点（2026-09-24）

## 口径

`tools/audio/inventory_game_resources.py`逐文件列出`UnityBattleSource/Assets`、`mistport-ios/Mistport`和`ArtSource`，不跟随符号链接，不把Unity Library、Xcode导出、历史展示页和备份算作独立运行资源。明细见`output/spell-audio-20260924/resource-inventory.tsv`，聚合见同目录`resource-summary.tsv`。这是**现存资源盘点**，不是每个文件都已被游戏引用、也不是每个关卡均已开放的证明。

| 资源层 | 规模与作用 | 当前使用边界 |
| --- | --- | --- |
| Unity `Resources` | 约1.40 GiB；敌人模型、运行时模型、主角材质、法术图、VFX及新音效 | 可按路径动态加载；实际使用还取决于战斗路由 |
| Unity其它 `Assets` | 约1.07 GiB；工程模型、FBX、动画、材质、着色器、Effekseer和脚本 | 制作/构建输入，不能一概视为运行时常驻 |
| iOS资源目录 | 431组图片资源，约342 MiB；角色、道具、地图/UI图像 | 受Xcode Target membership与代码调用约束 |
| iOS城市地图 | 约247 MiB | 城市与地区展示，不属于战斗音频 |
| iOS音乐 | 原3首MP3＋新增1首AAC循环曲，约19 MiB | 标题/城市与第一章Unity战斗分别路由 |
| 原始美术 `ArtSource` | 357个文件、约1.89 GiB；含21 GLB、28 Blender工程、17 FBX | 原件/试作/参考并存，未减面或未绑定者不能直接入机 |
| `output` / `artifacts` / `backups` | 当前本机分别约2.4/1.8/0.7 GiB | 评审录像、构建产物及回滚资料，不是额外游戏内容 |

旧素材外置归档在`/Volumes/andrew's SSD/Mistport-archives/20260922/mindstone-game`，已有符号链接仍应保留。此前归档回执记载25.94 GB、13,127文件；本盘点不递归追外置链接，不能把外置归档误当成丢失或重复可打包资产。

Unity可寻址资源的容量主要集中在`Enemies`（约711 MiB）、`RuntimeModels`（约391 MiB）、`Mindstone`（约135 MiB）和角色表面材质（约106 MiB）；新法术音效目录约1.4 MiB。后续优化包体应先查模型/贴图的真实引用与压缩设置，而不是从这批短音效下手。这个容量排序只说明磁盘占用，不代表运行时峰值内存。

现行内容口径以`AGENTS.md`及运行路由为准：塔正式11种怪；第一章十案中B01/B02/B03/B05/B07/B08/B09/B10是已接入模型，B04/B06仍走旧战斗模型。Rodin新版B04/B06、美术源和未开放技能不应被库存数误写成正式替换。法术总览的207段是评审录像，不是207个独立法术资产。

## 旧音频缺口与本批新增

此前iOS仅有3首场景音乐、界面程序点击声和个别铃的程序音；Unity没有覆盖主角/塔/通缉战斗的通用法术音频。本批添加`UnityBattleSource/Assets/Resources/Audio/Spell`下**29种材质语义×施放/命中两拍＝58段**22.05 kHz单声道短音效，完全由`tools/audio/generate_spell_sfx.py`合成，无外部音效包。`output/spell-audio-20260924/spell-sfx-audition.wav`可顺序试听。

声音依描述分配：主角飞牌短促纸片破风、错步气流、假面幽相、金纹束缚、高潮金属与碎光；亡灵低空泛音、火/岩浆裂响、毒液气泡、水卷、机械齿、赤丝撕扯、铃蛙声脉、骨爪/铜甲/盐晶、钟表与心智扰动等使用不同音色。B02束缚用金纹音色，B07铃击与毒沫分别铃/毒，B08镜像与真实刺击分别碎镜/薄刃，治疗和防护使用轻柔激活声，不误用爆炸。多个同族招式可能共享音色；并未谎称每招都有独立采样。

`SpellAudioDirector20260924`在Unity战斗动作起手播放施放拍，在原有`ReportCombatContact`命中/生效回调播放第二拍，取消/停战清理；不改变数值、冷却和真实命中。设置增加独立“战斗法术音效”音量，不与音乐共用滑块。关卡展示的少数旧式/独立试演入口未走标准的`PresentEnemyAttack(string)`时，可能只继承既有个别程序声；不能据此声称所有历史试演均完成听感验收。

战斗曲通过浏览器Google Gemini音乐模式生成，原始MP3保留`output/spell-audio-20260924/MistportBattle-Gemini-original.mp3`。因原曲尾部渐弱到静音，又生成168.82秒交叉淡化循环版`MistportBattle-loop.wav`，将AAC放入iOS `MistportBattle-Lyria-20260924.m4a`。主角进入第一章战斗时切曲，战斗结束返回原有标题/城市音乐。音乐为AI生成候选，**正式发行前需人工听完整循环衔接并复核使用条款**。

## 检查边界

- Unity Editor校验58个音效资源、22条语义路由通过；盐囊蓄毒/盐晶刺使用真实D02身份分别校验。新iOS Unity导出清单已含音效脚本与资源。静态校验和导出不等于实际扬声器混音或逐招听感通过。
- `scripts/check_unity_export_freshness.sh`原版逐文件启动哈希导致本批校验非常慢，已保留改前版于`backups/spell-audio-20260924/check_unity_export_freshness.sh.before-audio-build`并改为分批哈希；清单内容格式和路径顺序不变。
- Unity iOS导出、明确`platform=iOS`的签名Build65通过；包内有`MistportBattle-Lyria-20260924.m4a`及Unity资源，`codesign --verify --deep --strict`通过。首次误用CoreDevice标识作为Xcode destination会被解析为模拟器，因无`UnityRuntime.framework`失败；该失败不是法术音频编译失败，已改用Xcode显示的物理设备UDID重建成功。
- Build65已覆盖安装并启动iPhone 13，`devicectl`显示0.1.0(65)，进程运行。安装前、安装后、启动后三份`Library/Preferences`逐文件一致，备份在`backups/spell-audio-20260924/device-*`。未通过手机扬声器逐招试听、长时间音乐循环或性能测试，不能称音频视觉/听感全部合格。
- 真机建议检查连放普攻不拖尾、十案治疗/防护没有误报爆炸、音乐与高频音效互不遮蔽、循环接缝无突兀节拍。
