# D03 / D05 独立动作与法术制作接入

本文件记录新增组件，不代表 Unity 运行或用户视觉验收通过。Unity 由主 agent 统一运行。

## 独占新增文件

`UnityBattleSource/Assets/Scripts/TowerSupportPolish20260920.cs`

接口：

```csharp
var polish = TowerSupportPolish20260920.Create(actor, intent, target, contactTime, effect.transform);
polish.Tick(t);
// Clear 必须同步调用，随后再销毁 owner，避免延迟 Destroy 后覆盖新动作。
polish.Restore();
polish.enabled = false;
```

`Handles(species)` 接受 `shellback` / `frilled-naga`。准备动作 `tower_mend_charge` / `tower_crown_charge` 自动累积时间，不需要 Tick；攻击组件仅使用外部 Tick，contact 不由本组件调用。

## 四套演出

| 招式 | 身体 | 光效主体 |
|---|---|---|
| D03 恢复 | 双臂护腹、肩背抬起、背囊左右错拍鼓起，contact 时压缩 | mend高清囊膜左右独立大片脉动＋12道贴囊脉络，仅施法者。没有绿色连线、孵化或预先为目标播放恢复 |
| D03 短扑 | 后肢屈曲、前臂后收，contact 前双臂大幅前伸、躯干重落 | 金棕囊甲切面向前压扁撑开，成对压力楔面和20条短硬碎片。位移由既有 Presentation 负责，组件不写根节点 |
| D05 强化 | 身体直立、托臂展掌、双冠错时展开，转向冻结目标，尾链支撑 | corona高清红金冠膜两半展翅，9条冠肋＋9条金色冠缘；有序展开，不作伤害爆炸 |
| D05 声矢 | 胸颈后仰吸气、双臂低撑、冠喉前啸，尾骨反向撑稳 | corona主体压细随7片声纹发射；命中冠膜左右剥离、16道声面两侧裂开，峰值4倍后快速收束；不使用盐晶、剪刀或火球 |

原骨架已核对 `ArtSource/ChurchDemonsCombat20260917/rig_all.py`，D03 使用 `Sac.L/R`，D05 使用 `Crown.L/R` 与四段尾链。幅度通过 Chest/Neck/Head 与 UpperArm/Forearm/Hand 组合，不只整体摇摆。

## 主程序集成

1. 在 Prepare 分支为两个物种直接创建组件，跳过旧 `ChurchSpellVisual` 通用蓄力/光云。原 Animator 仍可使用 Charge，但不与本组件争用额外 late pose。
2. 在 Act 对应物种以本组件替代旧 `ChurchSpellVisual`，每帧 Tick；保留原 contact 与 target valid 检查、短扑回位、动画退场。
3. Clear 中先 Restore 并禁用，后销毁；死亡、跨波与取消走同一路径。
4. 受疗者泛绿和 +HP 仅由既有实际正恢复事件发起。强化印记仍由 ChurchStatusPresentation 读取真实状态，不能依赖此次1.25秒施法对象保持。

## 待统一验证

- 正常命中仅一次、准备取消、命中前取消、死亡取消、跨波销毁及连续重试。
- D03 sac 缩放恢复，D05 crown 缩放与尾链恢复；多个施法者不共享材质实例。
- 全景与动作近景检查大幅动作是否穿模；短扑既有根位移和本组件局部前伸是否距离过大。
- 主体使用既有位图 mend/corona，两半独立UV、ChurchFilament与ChurchLivingSurface双层。线细节使用 Sprites/Default 加现有 Line01，不能将线条当全部主体；需实录确认囊膜和声面不遮蔽动作。
- 本组件保存创建时骨骼旋转和缩放。主程序集成须在旧准备组件 Restore 后创建动作组件，避免把旧覆层当成新基姿。

此次未改数值、技能阶段、治疗目标、强化消耗、塔层开放或手机安装。

## 全量实录后第二轮

实录中D03恢复膜片被躯体遮住，短扑像两片叶子、碎屑不足。已将囊根锚点向相机移0.94、上提0.43到体表前方，增加金绿膜片可见性与脉络宽度。短扑膜甲压扁快速退场，碎屑增加为48道两侧压碎金白火星与重力短尾。D05声矢增加32道沿两侧声面方向的亮点拖尾。待主agent针对重录确认摆位与不遮脸；此追加不宣称第二轮视觉检查通过。
