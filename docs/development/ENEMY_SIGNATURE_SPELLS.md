# 三敌六法术：独立战斗表现

实现文件：`UnityBattleSource/Assets/Scripts/EnemySignatureSpellVFX.cs`。专用 shader 置于 `Resources/EnemySignature/SignatureFilament.shader`，使用 Resources.Load 保留构建资源。

| 敌人 | variant 0 | variant 1 |
| --- | --- | --- |
| 猎犬 | 冥焰吐息：紫黑焰舌从侧身汇向口部，橙金焰芯飞出，命中裂焰爆发 | 锁名焰环：颈圈抽出交错链节，双链弧牵引到目标，闭合焰环碎裂 |
| 档案守卫 | 终卷封存：周身翻页，方形封存章沿轨迹推出，中心档案锁纹与碎页爆开 | 千页追缉：两翼扇页展开，密集卷页沿三股螺旋追击，命中散页 |
| 织幕女主 | 万缕夜幕：三方向线轴抽出紫金丝束，目标出现三层六瓣编织纹并收束，断丝星屑散开 | 断线星雨：头顶连线星座从施法者上方移到目标，断线化针雨，星芒爆发 |

## 调用约定

```csharp
yield return vfx.Play(kind,
    () => liveMouthOrChest.position,
    () => liveVictimImpact.position,
    onRelease,
    onContact,
    variant: attackIndex % 2);
```

- 世界坐标动态挂点：猎犬口部，档案守卫柜身中点，织幕女主胸前/三线轴中心；目标为实际受击高度。
- 每实例独立拥有对象、材质和 Mesh；多敌应各自拥有一个组件，互不取消。
- 蓄力 1.4 秒，调用 onRelease；飞行/编织 0.65 秒；提交主爆发画面后仅调用一次 onContact；余焰 0.8 秒。
- 使用 Time.deltaTime，与战斗暂停时间一致。实际帧率决定回调时间的单帧量化误差。
- 仅做表现，不自行添加伤害、命中次数、定身、减益等规则。
- 每次 Play 使本实例旧播放失效。CancelAll/OnDisable/OnDestroy 立即隐藏并清除本实例自建对象、材质、Mesh。外部驱动的旧 IEnumerator 在下一次 MoveNext 退出，不调用全局 StopAllCoroutines。
- 同一实例被取消后，旧迭代器 finally 不会销毁新播放资源。

## 成本与验证边界

每次施法六份动态 Mesh、六份材质、六个 MeshRenderer：底层暗色 alpha blend、上层发光丝带、Fire_Single 原有火焰纹理、Smoke 四宫格紫黑烟、柔光、实质发光羊皮纸。卷页包含边框/断行印刷和轻微折面，封印加入厚边；女主花瓣和针雨额外使用星云及针尖柔光。没有运行时逐粒子 GameObject、逐粒子材质、灯光或后处理；复用 List 与固定曲线缓冲区，摄像机每帧读取一次。各 Mesh 顶点数量低于 16 位索引限制。

本文件记录实现设计和时序，不代表 Unity 构建、真机性能或正式战斗截图验收通过。这些由主集成任务实际运行后报告。

2026-09-13 视觉补强：依据真实 Mac 画面 Hound-1/frame-020 的细线不足问题补入上述体积层。此增强版本尚待主任务重构截图确认。
