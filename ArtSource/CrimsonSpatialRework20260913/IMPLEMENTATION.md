# 女主实体法术演出重做

## 本地资源核对

项目本地可用 Effekseer 编辑源：
- `UnityBattleSource/Assets/Resources/Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/HolySandstorm/HolySandstorm.efkproj`：旋转/生成参数，参考升卷与汇聚阶段。
- `UnityBattleSource/Assets/Resources/Mindstone/VFXV1/Spells/storm-frost-tornado-v1/Effekseer/FrostVortexTravel.efkproj`：龙卷移动结构候选。
- `UnityBattleSource/Assets/Resources/Effects/Fool/Effekseer/CurtainExplosion/FoolCurtainExplosion.efkproj`：分段生成/爆散阶段参考。
- Downloads 搜索未找到独立万箭工程；此次银针阵列为新写实体几何，不声称复用了万箭源。

本次参考这些资源的运动阶段，自行制作女主的红线和银针主体。没有把龙卷原效果直接染红套用，也没有新增 Effekseer 运行实例。

## 实现

- 删除女主相机近裁剪面全屏shader表现，保留同名组件以免引用断裂。
- 红线招：12条双向螺旋绳和6条自由线头围成立体绞笼；蓄力展开、飞行收紧、命中断裂为48段有重力的曲线碎绳。
- 银针招：45支银针按3层、每层15支排开，按层延迟俯冲，所有轨迹在现有命中边界到达。银针保留金属明暗、实体尖端、红色尾线；命中插地，小线团散开并有金属碎针。
- 网格位于世界坐标，单mesh/材质；绞笼最高约17952顶点。phase重绘复用列表。没有每根线生成GameObject。
- `EnemySignatureSpellVFX`原始1.4s蓄力、0.65s飞行、0.8s尾效与回调不变。只在原root下创建，root取消清理沿用。

## 验证边界

已完成：括号平衡检查、删除旧局部方法的全项目引用检查、确认不存在nearClipPlane/WorldToViewportPoint全屏投影、顶点数静态核对。
未完成：本次Unity编译、运行截图与视觉验收，交由主agent统一执行。不要将静态检查作为视觉验收。

原文件备份在本目录 backup。
