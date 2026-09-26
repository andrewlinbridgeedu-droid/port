# Unity 3D 战斗接入

3D 敌人的量产导入、Prefab 层级、数据配置、阵型槽位、挂点跟随、校准工具和自动验收统一遵循 [`../mistport-ios/ENEMY_3D_PIPELINE.md`](../mistport-ios/ENEMY_3D_PIPELINE.md)。本文件只说明 Unity 与 iOS 战斗层的接入边界。

## 当前资产

Unity 工程：

`/Users/andrewlin/Downloads/DEV_Projects/mindstone-unity-battle`

Meshy 模型与动画：

- 愚者：`Assets/Models/Fool`
- 钟卫：`Assets/Models/ClockGuard`
- 战斗场景：`Assets/Scenes/BattlePrototype.unity`
- 动画安装器：`Assets/Editor/Install3DAssets.cs`
- 战斗表现控制：`Assets/Scripts/BattlePrototype.cs`
- 原生通信桥：`Assets/Scripts/UnityBattleBridge.cs`

## 动作映射

| 战斗事件 | 愚者 Meshy Clip | 钟卫 Meshy Clip |
|---|---|---|
| 待机 | `Combat_Stance` | `Walking`（低速循环） |
| 普攻/技能 | `mage_soell_cast_4` | `Charged_Axe_Chop` |
| 防御 | `Two_Handed_Parry` | `Sword_Parry_Backward_5` |
| 受击 | `Hit_Reaction` | 暂无独立受击 Clip |
| 接近/退回 | `Running` | `Running` |

场景不再通过旋转整个人物伪造动作。角色接近目标时只移动根节点，
肢体动作来自 Meshy FBX 内的骨骼 AnimationClip。

## 游戏职责边界

`MistportCombatCore` 继续负责：

- 回合和行动队列
- 技能合法性
- 伤害、护盾、防御和无视防御计算
- 胜负与关卡结算

Unity 只负责：

- 3D 模型、材质、灯光和相机
- 待机、攻击、格挡、受击与移动动画
- 粒子、命中特效和伤害数字

Swift 侧通过 `UnityFramework.SendMessage` 向
`Mistport Unity Battle Bridge.ApplyCommand` 发送：

```json
{"action":"basic"}
{"action":"skill"}
{"action":"defend"}
{"action":"enemy"}
```

玩家行动与敌方行动分开发送。这样一组卡牌全部结算后，钟卫才执行
一次敌方回合，不会因为单张卡牌动画自行改变核心战斗状态。

## iOS 接入状态

- iOS Build Support 已安装。
- `Mindstone/Export iOS Library` 会将完整工程导出到
  `mistport-ios/UnityBuild`。
- `Mistport.xcodeproj` 已将导出的 `UnityFramework` 设为 target
  dependency，并在构建时链接和嵌入 framework。
- `UnityBattleHost.swift` 负责启动 Unity、嵌入 SwiftUI 战场和发送动作。
- 第一关 `chapter01_q01_encounter` 使用 Unity 3D 战场；其余关卡暂时保留
  SpriteKit 表现层，待多目标点击与对应 3D 敌人资产完成后逐关切换。
- “跳过动画”开启时不会向 Unity 发送玩家或敌方动画命令。

最终验证命令：

```sh
xcodebuild \
  -project mistport-ios/Mistport.xcodeproj \
  -scheme Mistport \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

2026-07-27 已通过完整 arm64 iPhone 构建验证。
