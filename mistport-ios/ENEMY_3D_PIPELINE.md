# Mistport 3D 敌人生产与接入规范

状态：当前生产规范  
更新时间：2026-07-28  
适用范围：`UnityBattleSource` 中的 3D 敌人，以及嵌入 `mistport-ios` 的 Unity 战斗表现层

## 目标

新增普通敌人时，不再为模型朝向、大小、站位、悬浮、护罩和选中反馈反复修改战斗代码。标准流程应在 Unity 编辑器内完成校准和截图验收，最后只进行一次 iOS 导出与真机构建。

目标耗时：

- 已符合规范的模型：10–20 分钟完成接入；
- 坐标轴、材质或动画异常的外部模型：30–60 分钟完成规范化；
- 不通过反复修改 `BattlePrototype.cs`、IL2CPP 生成代码或真机试角度来校准资产。

## 本次问题的根因

钟核接入暴露了以下结构性问题：

1. FBX 的上方向、正面和长轴没有统一规范；
2. 朝向、缩放、站位和动画参数散落在战斗控制代码中；
3. 模型的战场位置与视觉修正使用同一个 Transform；
4. 护罩、选中圈和六角法阵没有统一挂点与敌人 ID；
5. 预览代码和运行时代码重复实现，预览结果不能保证等于真机结果；
6. 每次微调都依赖 Unity 导出、Xcode 构建和真机截图，反馈周期过长；
7. `OnEnable` 可能在最终位置写入前捕获旧姿态，造成突然跳位。

后续机制必须消除这些问题，而不是继续增加敌人专用条件分支。

## 核心原则

### 数据驱动

每个敌人的视觉参数保存到独立的 `EnemyVisualProfile`，运行时只读取配置。禁止在通用战斗控制器中出现 `if enemy == ...` 后再写专用四元数、坐标或动画参数。

### Transform 职责分离

战场位置、程序动画、模型修正和挂点必须由不同节点承担。任何脚本只能修改自己负责的节点。

### 预览与运行时共用实现

编辑器校准窗口必须调用正式的 `EnemyPresenter` 和 `EnemySpawner`。不能为截图另写一套摆放逻辑，否则预览仍可能与 iPhone 不一致。

### 先预览验收，后导出 iOS

模型正面、大小、阵型位置和待机动画先在 Unity 的 iPhone 纵向预览中确认。确认前不导出 `UnityBuild`，也不进行完整 Xcode 构建。

这是强制人工门禁：每次涉及模型、材质、朝向、比例、阵位、动画、护罩或选中法阵的改动，Codex 必须先使用正式游戏相机、正式运行时生成逻辑和目标 iPhone 纵向比例渲染截图，并把截图发给用户。只有用户明确回复“可以”“确认”或同等批准后，才允许执行 Unity iOS 导出和 Xcode build。洋红材质、丢贴图、模型缺失、错误朝向、错误遮挡或错误阵位均视为预览失败，禁止进入构建阶段。代码编译通过不能替代这项截图批准。

## 标准 Prefab 层级

```text
EnemyRoot                   战场槽位、敌人 ID、整体显隐
└── MotionRoot              悬浮、受击、冲锋、击退
    ├── VisualRoot          FBX 坐标轴、正面、俯仰、标准高度修正
    │   └── Model           原始 FBX Prefab，不直接写战场坐标
    ├── ShieldAnchor        护罩及其粒子
    ├── TargetAnchor        点击、选中圈、六角法阵
    ├── HealthBarAnchor     血条的世界坐标来源
    ├── DamageTextAnchor    伤害数字
    └── EffectAnchor        命中与施法特效
```

节点职责：

- `EnemyRoot`：只由阵型和战斗移动系统控制；
- `MotionRoot`：只由表现动画控制，不保存模型永久校准值；
- `VisualRoot`：只保存导入修正和标准缩放；
- `Model`：保持原始 FBX，不在运行时直接改其根 Transform；
- 所有跟随效果必须挂在对应 Anchor 下，或每帧读取 Anchor 的世界坐标。

悬浮动画只能修改 `MotionRoot.localPosition.y`。它不得旋转 `VisualRoot`，也不得覆盖 `EnemyRoot` 的最终战场位置。

## EnemyVisualProfile

建议使用 Unity `ScriptableObject`，每个敌人一份资产：

```csharp
[CreateAssetMenu(menuName = "Mistport/Enemy Visual Profile")]
public sealed class EnemyVisualProfile : ScriptableObject
{
    public string enemyId;
    public GameObject prefab;

    public Vector3 visualEuler;
    public float referenceHeightRatio = 1f;
    public string defaultSlotId;

    public bool hoverEnabled;
    public float hoverAmplitude;
    public float hoverPeriod;

    public string animatorControllerId;
    public string idleState;
    public string attackState;
    public string defendState;
    public string hitState;
    public string deathState;
}
```

正式实现可将 `visualEuler` 改为序列化 Quaternion 或三个明确步骤的旋转修正，避免欧拉角顺序歧义。配置面板必须以最终模型正面为准显示结果。

配置还应引用或生成：

- `ShieldAnchor`；
- `TargetAnchor`；
- `HealthBarAnchor`；
- `DamageTextAnchor`；
- `EffectAnchor`；
- 点击碰撞体或选择包围盒；
- 可选的手工 Bounds 覆盖值。

## 阵型槽位

敌人的战场位置属于阵型，不属于模型。创建 `EnemyFormationProfile` 或等价配置，提供稳定槽位：

```text
FrontLeft
FrontCenter
FrontRight
RearLeft
RearCenter
RearRight
AirRearLeft
AirRearRight
CenterBoss
```

每个槽位至少定义：

- 战场基准位置；
- 深度；
- 地面或悬浮高度；
- 建议最大高度比例；
- 血条与选中反馈的屏幕安全区；
- 多种 iPhone 纵横比下的可见性约束。

同一槽位在不同设备上应通过战场坐标或 Camera Viewport 映射得到稳定构图，不为单个设备保存独立像素坐标。

## EnemyPresenter 运行时职责

正式生成入口应收敛为：

```csharp
EnemyHandle Spawn(
    EnemyVisualProfile enemy,
    EnemyFormationSlot slot,
    BattleEnemyId battleId);
```

统一执行顺序：

1. 创建标准 `EnemyRoot`；
2. 实例化模型到 `VisualRoot`；
3. 应用导入朝向修正；
4. 按包围盒或配置值规范化高度；
5. 写入阵型槽位；
6. 创建并绑定全部 Anchor；
7. 绑定 Animator 和待机表现；
8. 完成最终 Transform 后才启用悬浮或其他程序动画；
9. 返回包含敌人 ID 和挂点引用的 `EnemyHandle`。

禁止：

- 动画脚本在 `OnEnable` 后跳回旧坐标；
- 多个脚本同时写同一个 Transform；
- 通过对象名称猜测敌人身份；
- 护罩、血条或法阵保存独立的“近似位置”；
- 直接编辑 `mistport-ios/UnityBuild` 中的 IL2CPP 生成代码。

## 护罩、选中圈与六角法阵

### 护罩

护罩对象应成为 `ShieldAnchor` 的子节点。钟卫移动、受击、攻击或缩放时，护罩自然跟随，不再单独运行位置补间。

如果护罩必须由 SwiftUI 或 SpriteKit 绘制，则每帧通过 Unity 相机将 `ShieldAnchor.position` 转为屏幕坐标，并携带同一个 `battleEnemyId`。不得只在动画开始时读取一次位置。

### 选中圈与六角法阵

选择系统必须使用稳定的 `battleEnemyId`：

```text
点击碰撞体
  → EnemyHandle.battleEnemyId
  → BattleState.selectedEnemyId
  → 对应 TargetAnchor
  → 绘制选中圈和六角法阵
```

选中反馈不能按数组下标、对象名称或屏幕最近距离推测目标。多敌人交换位置后，ID 与 Anchor 的映射仍必须保持不变。

## 程序待机动画规范

无骨骼悬浮单位使用正弦运动：

```csharp
offsetY = Mathf.Sin(elapsed * Mathf.PI * 2f / period) * amplitude;
```

约束：

- 基准位置必须在最终阵型位置写入后捕获；
- 每帧由基准位置计算，不在上一帧结果上累加；
- 默认只修改 `MotionRoot.localPosition.y`；
- 不修改旋转和缩放；
- 暂停、受击或退场时有明确的启停规则；
- 默认幅度建议 `0.03–0.08` 世界单位；
- 默认周期建议 `3.5–5.0` 秒；
- 重要敌人如需呼吸、旋转或亮度变化，使用独立通道，不叠写位置。

## Unity 敌人校准窗口

新增 `Mistport > Enemy Calibration` 编辑器窗口，必须提供：

- 选择 FBX 或现有 Enemy Prefab；
- 选择阵型槽位；
- iPhone 纵向战斗相机与正式背景预览；
- 正面旋转、俯仰、翻滚调节；
- 高度比例、左右、上下、前后调节；
- 悬浮幅度和周期实时预览；
- 护罩、血条、选中圈和特效挂点 Gizmo；
- 单敌人正面截图；
- 完整阵型截图；
- 多种 iPhone 比例切换；
- “保存到 EnemyVisualProfile”；
- “恢复上次已批准值”；
- 导入检查与错误列表。

该窗口必须调用正式运行时生成逻辑。截图中应标记敌人 ID、槽位、包围盒和深度顺序。

## FBX 导入规范

外部或生成式 3D 模型允许坐标系不一致，但进入运行时前必须由标准 Prefab 规范化：

- Unity 世界上方向为 `+Y`；
- 角色正面采用项目统一方向；
- 地面单位的脚底位于基准平面；
- 悬浮单位定义明确的视觉中心和最低点；
- 模型高度通过 Renderer Bounds 统一；
- 材质明确绑定 Albedo、Normal、Metallic/Roughness、Emission；
- 动画 Clip 名称映射到统一状态；
- 原始 FBX 不承担阵型坐标；
- 不通过反复覆盖 FBX 导入旋转来保存玩法参数。

建议增加 `AssetPostprocessor` 或导入检查器，报告：

- 异常尺寸；
- 缺失材质或贴图；
- 无法识别的正面；
- Pivot 与包围盒偏离；
- 缺失动画状态；
- Renderer Bounds 为零；
- 不支持的 Shader；
- 重复敌人 ID。

## 自动验证

### EditMode

- Profile 的 Prefab、敌人 ID 和默认槽位必须存在；
- 所需 Anchor 必须齐全且名称唯一；
- 标准化后高度误差在允许范围内；
- 材质与贴图引用有效；
- 不同敌人不能使用重复 ID。

### PlayMode

- 待机运行 10 秒后，非悬浮轴位置误差小于容差；
- 悬浮峰值不超过 Profile 幅度；
- 非旋转单位的旋转保持不变；
- 护罩与 `ShieldAnchor` 距离始终小于容差；
- 选中敌人 ID 与六角法阵 Anchor 一致；
- 攻击、受击、返回待机后仍回到同一槽位；
- 多目标交换或死亡后映射不串位。

### 截图回归

至少保存：

- 单体正面图；
- 完整阵型图；
- 最窄和最宽支持设备的战斗图；
- 护罩开启图；
- 每个可选敌人的选中反馈图。

截图测试负责发现构图变化，不代替真人视觉验收。

## 新敌人标准工作流

1. 将 FBX、贴图和动画放入稳定资产目录；
2. 运行导入检查；
3. 一键生成标准 Enemy Prefab 和 `EnemyVisualProfile`；
4. 在校准窗口选择正面、大小和阵型槽位；
5. 配置悬浮及其他待机表现；
6. 放置并检查所有 Anchor；
7. 生成单体和阵型截图；
8. 完成 Unity PlayMode 验收；
9. 批准后导出一次 `mistport-ios/UnityBuild`；
10. 执行一次无签名 iPhone 构建；
11. 最后进行真机视觉与触控验收。

## 完成定义

一个敌人只有同时满足以下条件才算接入完成：

- 正面、上下方向和大小已批准；
- 阵型位置与深度已批准；
- 待机、攻击、受击和退场状态可用；
- 护罩与全部挂点始终跟随；
- 选中圈和六角法阵准确对应敌人 ID；
- 支持的 iPhone 比例无越界或遮挡；
- 自动测试通过；
- Unity 导出与 iPhone 构建通过；
- 真机验收完成。

“代码完成”不能代替“视觉验收完成”。

## 分阶段落地

### 第一阶段：消除敌人专用硬编码

1. 实现 `EnemyVisualProfile`；
2. 实现标准 Prefab 节点；
3. 实现 `EnemyPresenter.Spawn`；
4. 将钟卫和钟核迁移为第一组样板。

### 第二阶段：缩短调参反馈

1. 实现敌人校准窗口；
2. 使用正式相机、背景和生成逻辑；
3. 自动生成单体与阵型截图；
4. 提供 iPhone 比例切换。

### 第三阶段：防止回归

1. 增加 FBX 导入检查器；
2. 增加 EditMode 与 PlayMode 测试；
3. 增加截图基线；
4. 将测试接入 Unity 导出前检查。

## 当前钟核迁移基准

以下数据记录 2026-07-28 已确认的视觉基准，用于迁移到 Profile 后做回归对照，不应成为其他敌人的默认值：

| 项目 | 当前值 |
|---|---|
| 阵型语义 | `AirRearLeft` |
| 世界位置 | `(-1.0, 1.15, 9.75)` |
| 相对钟卫高度 | `0.496` |
| 正面修正 | 两次 Y 轴 90° 与一次 Z 轴 90° 的有序组合 |
| 前倾 | `-15°` |
| 悬浮幅度 | `0.055` |
| 悬浮周期 | `4.2 秒` |
| 旋转待机 | 禁止 |

迁移完成后，应删除 `BattlePrototype` 中对应的钟核专用 Transform 代码，由 `EnemyVisualProfile` 和阵型槽统一提供这些值。
