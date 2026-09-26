# 第一章总签官母版制作（2026-09-16）

本批针对用户提供的 Chronarch_Sovereign_0917015018，同一模型供 Q28/Q29/Q30 使用。保留原高模，不增加变身模型。当前仅完成独立资产与运行验证；主线三战规则、全场路由与手机实测由集成批完成，不能据此宣称30关全部可玩。

## 资产

- 母版：`ArtSource/ChapterOneBoss20260916/Meshy_AI_Chronarch_Sovereign_0917015018_texture.glb`，SHA256 `61d0ad9785592a6513a47867c8f3206a08194373689a1bf841a031e4bc1a5151`。
- 原 1,572,068 三角面；游戏版 85,000 三角面、21 根实际蒙皮骨骼、4 权重/顶点上限、2048 色彩/法线/金属粗糙度贴图。白发人脸、象牙白衣、暗红后摆、金钟环、铜巨手、档案书均保留。
- 可编辑工程 `Chronarch_Combat.blend`；同目录 FBX/GLB 与生成脚本。先以保护脸/手/书的减面生成 Prepared，再热权重绑定。最初空间分区权重在举臂时牵拉衣摆，实拍发现并废弃，最终采用表面热权重、四影响限制及归一化。
- 8 个片段：Idle、Charge、Cast、Hit、Death、Charge2、Cast2、Retreat。头颈观察、胸部呼吸、双手、衣摆各有独立骨骼动作；不是仅移动整个物件。固定脚下的远程施法，无行走/完整手指动作；死亡为失力俯身，后续仍需通用一秒消散。
- `backups/chronarch-production-20260916/intake-manifest.json` 保留制作前资产状态；原始高模未删除。

## 独立 Unity 接入

- 导入方法：`ImportChronarch20260916.Import`。只改本Boss资源，不保存共享 BattlePrototype 场景。
- 资源：`Assets/Resources/Enemies/Signature/Chronarch/Actor.prefab`、`VisualProfile.asset`、`Combat.controller`。
- 约定 ProfileEnemyId=`chronarch`。集成方需建立 `chronarch-template` 并在 roster 路由支持 `@chronarch`。
- `EnemyPresenter.Present` 建立 handle 后添加 `ChronarchPresentation20260916` 并调用 `FitRestPose()`。不可只修改旧敌名字而显示旧母版。
- 攻击：`Strike(handle, target, contact, valid)`，两套骨骼动作轮换；每招真实接触回调一次，取消不回调。此组件不计算伤害、五循环或胜负。
- 退场：Q28/Q29 调 `BeginRetreat()`，导演在非死亡退场逻辑中管理可见性；不调用 Death。Q30 唯一真死使用 Death 与通用死亡渐隐。
- 取消/重试/换关先 `Cancel()`；禁用组件自动清理施法实体与材质。
- 当前攻击视觉为独立金色钟环判令试演，尚未获得用户整关视觉验收；不能称完整Boss法术制作全部完成。

## 证据和界限

`output/chronarch-delivery-20260916/` 包含 Blender 正面/施法/受击/死亡/退场静帧、实际骨骼动态GIF、Unity PlayMode 静帧、导入/运行日志及 `blender-validation.json`。

Blender 检查蒙皮真实顶点在多个动作帧发生变形、脚底最低点固定、Idle首尾/蓄力到施法/施法回Idle四元数边界一致。独立 Unity PlayMode 检查模型真实骨骼、两招各一次回调、取消无回调、非死亡 Retreat、Death 和回 Idle。此处不替代 Q28–30 数学通关、共享路由死亡渐隐和手机视觉验收。
