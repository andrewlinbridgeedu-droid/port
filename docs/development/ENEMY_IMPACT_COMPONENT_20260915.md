# 敌人确认受击反馈组件

新增 `UnityBattleSource/Assets/Scripts/EnemyImpactFeedback.cs` 与资源 shader `EnemyContactImpact.shader`。这是表现层，不计算伤害、不中断敌方法术、不改变 Animator 或 Time.timeScale。

- 集成：对本次真实结算且伤害大于零的每个目标调用 `EnemyImpactFeedback.For(handle).Play(skillID, intensity)`，不要在多段粒子上重复调用。
- 反馈：45ms局部压缩/后仰，60ms姿势峰值停留，随后阻尼回弹，总计430ms。重型守卫胸部幅度较小；犬头颈与胸部反向，幽灵/无骨核心增加局部形变，蛭分段反向压缩。无EnemyRoot/MotionRoot移动。
- 命中点：按可见模型包围盒定大小，生成短亮芯与长短交错冲击碎线，300ms内消失；85ms模型材质色闪保持alpha，不替换既有法术演出。
- `EarlyEnemyIdlePresence.VisibleActor`决定目标，避免亡灵/幽灵的隐藏旧模型受击。Update移除上一帧附加姿态，LateUpdate执行顺序1100在待机1000后叠加。
- `BeginDeath()`移除姿态和色闪但保留当次爆点尾效；死亡淡出期间对象须继续启用。换关/重试调用`Clear()`，OnDisable/OnDestroy同样清理。组件不ResumeIdle，所以不清除Q4蓄力限制。
- 诊断：PlayCount/ImpactCount累计、IsPlaying、VisibleActor、MappedJointCount、LastIntensity。

本文件仅记录组件实现；编译、真实命中回调覆盖、各模型运行截图及真机验收由集成结果另记，不把静态实现当成视觉验收。
