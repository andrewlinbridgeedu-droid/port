# 2026-09-16 现有模型优化交付

用户要求在现有游戏中优化模型。本批使用已有模型、贴图、Blender与Unity，不安装新生成插件、不替换已批准角色、不改剧情与战斗规则。

## 实际变更

- 洛克/救援者：77,248→46,348三角，约减少40%。保护脸、手、背架；保留17骨、4材质槽、UV及原七段动画。Unity最终导入34,191顶点（含UV/法线拆点），不能把Blender顶点数当GPU顶点数。
- 书记员：尝试36,000三角后主agent复核发现账册与衣摆损失，已撤销减面，保留48,000三角。Unity FBX与原备份SHA256一致。候选均改名`*_Optimized_REJECTED.*`，重现脚本禁止scribe参数。
- 两新角色材质：重新使用源ORM中的粗糙度变化和AO；以原蜡/布/皮革/金属标量粗糙度为基线，变化强度0.65。金属仍由原分区标量控制，不用源贴图把皮肤变金属。不是重画贴图或重新雕刻。
- 旧守卫、早犬、核心、幽灵：将金属/粗糙两张图的有效R通道无损打包到同张ORM的B/G，源像素逐一比对误差0。GPU压缩仍有损，不能把源像素无损称为GPU无损。旧复制图移至`Assets/SourceOnly/CharacterSurface20260916`，原模型源贴图及备份保留。每个受影响表面两次纹理采样改一次；不是全游戏总内存/帧率提升的实测。
- 新打包图iPhone明确2K、线性、mipmap、ASTC6、不可读；其余已正确配置的法线/贴图未盲目降分辨率。
- 主角：沿用衣装与原有动作，对金边/法线高频高光加入导数抗闪点；不改衣装造型或施法。
- ImportStoryEnemies重新导入优先选择已存在的`*_Combat_Optimized.fbx`；救援者使用优化源，书记员因无接受的优化源使用原件。

## 验证与实际证据

入口：`output/model-optimization-20260916/index.html`，包含本批优化前（已含上一轮精修）/本批优化后实际Unity战场图，以及书记员/救援者待机施法视频。

- Blender：救援者同镜头待机/施法前后图；闭合、零非流形、零零面积、无无权重点；FBX重导骨名、材质槽、UV、动画区间通过，最多4权重且归一化，5处动作接缝0。证据在`ArtSource/RescueBearer20260916/optimization-evidence`。
- Unity 12组实际角色运行截图/6秒序列：`before/`、`after/`。主agent查看救援者、书记员、早犬等关键实际图。
- `story/passed.txt`：两角色真实施法各一次contact、取消后无contact；Q9/12/13/14编队正确。视频`story/rescue.mp4`、`story/scribe.mp4`由实际帧编码。
- `idle/passed.txt`：两新模型战前、战斗空档、攻击后、受击后、取消、重试，骨骼持续运动且编队固定。
- `fade/passed.txt`：九类旧敌人实际半透明退场、中途取消及原材质恢复通过。常态与Fade shader表面计算逐字一致，保留原故事非致命收势规则。
- `unity-import-audit.txt`：Unity真实导入三角数/骨骼/7 clips检查。
- `after/surface-audit`：实际renderer绑定与模式检查；故事为mode4、合并图为mode3。旧审计的metal/rough字段优先列出仍保留的Standard贴图，不能用这个标签判断shader当前采样；新shader模式3/4实际采样`_MetallicRoughness`。
- Unity独立构建、iOS导出、iPhoneOS原生构建成功。日志已复制同目录。本批未改构建版本号，不能把现有39号产物当作此前同号包。

## 交付边界

没有安装手机，已知手机仍Build37。工作区仍包含之前未通过平衡的假面/勋章与新故事修改，不能随美术优化直接声称全关可玩。手机帧率/内存/发热、真机视觉与逐关交互未验收；本批无性能百分比结论，也不宣称全部角色重新建模或达到魔兽美术水平。

可复现：`ArtSource/ModelOptimization20260916/pack_surface_maps.py`；Unity `ModelAssetOptimization20260916.ImportAndBuild`；救援者`optimize_combat_meshes.py -- rescue`。原源文件与此次修改备份在`backups/model-optimization-20260916`。保持CPU可读与原动画压缩配置，避免对运行时贴地/蒙皮访问作未经验证的全局变更。
