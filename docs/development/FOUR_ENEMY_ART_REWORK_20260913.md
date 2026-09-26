# 四敌美术与动作正式重作 · 2026-09-13

## 用户已批准的母版

| 角色 | 母版 | 制作方向 |
|---|---|---|
| 翠焰亡灵 | Downloads/3.glb + 骷髅绅士原画 | 墨绿/骨白、胸腔翠光、邀请手势与衣尾跟随 |
| 猎犬 | Meshy_AI_Armored_Hellhound_0914012944_texture.glb | 保护背毛、细尾、低头龇牙；原地自然蓄力喷火 |
| 织幕女主 | Meshy_AI_The_Crimson_Threadwea_0914005851_texture.glb | 保护脸/骨指/线轴支架；牵线、酒红/冷银/灰纱 |
| 档案守卫 | Meshy_AI_Iron_Vault_Sentinel_0914004012_texture.glb | 象牙白/靛蓝/琥珀灯；机械刚体与重心动作 |

新狗覆盖此前Infernal Warhound母版选择，旧版本保留备份。女主不使用自动减面后手指断裂的012308版。

## 实施边界

新目录分别为 `ArtSource/EmeraldEncoreRework`、`ArtSource/ArmoredHellhoundRig`、`ArtSource/CrimsonThreadweaverRig`、`ArtSource/IronVaultSentinelRig`。源文件与参考图复制保存；只修改派生版本。主agent独占Unity/Swift接入与守卫制作，其余三角色分别由独立3D工程agent制作。

保持正式战斗规则、手动点卡编排、铃的3秒/+50%契约、奖励/保存和剧情。第4关仍远处喷火；第5关仍亡灵，不能被猎犬父节点替换。第9关复用守卫仍是临时角色资产，不由此次替换变成新正式敌人。

## 完成状态

制作中，未宣称导入、构建或实战通过。每份资产需减面后实际多角度/动作检查，导入需验证尺度/落地/HP锚点/喷吐或施法挂点；至少在受影响正式关卡跳关实测，单独记录与新档连续通关的区别。

## 备份

`backups/four-enemies-approved-20260913` 保存当前接入脚本、场景和AGENTS；替换Unity资源前继续备份对应目录。

## 本批新增批准：守卫飞臂

一套守卫法术改为真实前臂与手掌从本体脱离，蓝白光包裹，飞向主角，接触回调结算一次，随后返回装回。另一套法术保留。运行必须使用独立 `IronVaultLaunchArm` renderer，取消/重试/切关/退场恢复本体并销毁飞行快照；总伤害与正式节奏保持。
