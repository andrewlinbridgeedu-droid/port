# 主角真实受创反馈 · 2026-09-25

状态：正式源码桥接与附加身体层已实现，Unity正式场景32项定向检查、Swift独立政策15项及35个原生Swift文件的iOS arm64类型检查通过。新受体近景由法术批次补录；尚未凭此认定主观冲击感合格。本批未安装iPhone，先前Build125手玩仍是历史证据。

## 来源与范围

用户在本轮审查后继续否定表现平淡、缺乏冲击。检查发现 `ChapterOneTestView.swift` 连续战斗的敌方contact在 `endRound(actingEnemyID:at:)` 后已结算真实HP/盾、原生震动及飘字，原先仅有 `enemy-impact` 回传敌方受创，没有主角身体受创回传。

按 `game-spell-impact` 技能及其雾港reference实施：只补真实结算后的表现层。伤害、CD、攻速、contact时刻、目标、规则位移与存档均不修改；不增加震动、震屏或二次伤害。没有把无伤控制、免疫、幻影完全挡下当成受伤。持续毒时钟和旧非连续战斗分支不在这次contact桥接范围。

## 正式入口与所有权

1. 原生保存 `hpBefore/shieldBefore`，既有 `endRound` 成功之后调用 `UnityBattleRuntime.presentPlayerImpact`。使用实际前后差值，HP与盾合并成一条视觉回执；HP净增益或盾净增益不能构成负伤害。既有震动及飘字路径原样保留。
2. `UnityPlayerImpactChannel` 为无玩法副作用的值类型。每次战斗start/stop、player-reset、配置敌群建立新UUID，序号从1开始；同一原生contact事件ID只发一次。
3. `UnityBattleBridge.ApplyCommand` 接收下列正式命令，场景未准备好的瞬时 `player-impact` 不积压重播。`BattlePrototype` 只提供主角实例、状态和清理挂点。
4. `PlayerImpactFeedback20260925` 单一脉冲短促压身、轻微反向回弹，完整0.30秒，连击重置自有脉冲而不无限累加。胸/脊柱/头用actor-space角度，根、骨盆、腿、脚和手部局部姿态不写；正在施法/普攻时幅度乘0.42，不清理或重新触发其Animator和编舞。
5. `HeroLivingIdle20260916` 的执行序800、`FoolSkillChoreography` 的900均为Update恢复、LateUpdate写入。新增极小 `PlayerImpactRestore20260925` 以-10000的Update先移除本层上一帧偏移；主组件1100的LateUpdate在上述两层后附加。当骨骼已经被新写入者改变时不回写旧baseline，也不逆乘偏移。
6. 结束、取消/停战、换波、重试、死亡、禁用/销毁均清理本层。致死回执直接交给既有死亡演出，不做受击后仰抢占碎裂。纸人临时隐藏时清掉当前脉冲，内部恢复保留仍合法context；显式player-reset换新context。没有协程尾回调会清除后续动作。

## 命令契约与录制调用

先完成编队和 `combat-start`，再建立context。命令均经 `bridge.ApplyCommand`，不以反射或任意 `Animator.SetTrigger` 代替正式桥接。

```text
player-impact-context:recipient-review-1
player-impact:recipient-review-1;1;90;0;1000;0;0
```

七字段为 `context;sequence;hpLoss;shieldLoss;maxHP;defeated;reduceMotion`。序号递增；下一次setup/换波/start后使用新context。重复context命令本身不重置去重水位。

| 情况 | 表现 |
|---|---|
| HP真实减少 | 短促身体反应；按损失比例有限幅度分级 |
| HP不减而盾真实减少，例如`0;60;1000;0;0` | 约半幅的承力反应，记录盾受创身份 |
| HP与盾同时减少 | 单条反应，不叠两次 |
| HP/盾均未减少、纯控制、免疫、治疗、完全挡下 | 不发送或拒绝 |
| 非法字段、非正maxHP、旧context、重复/逆序sequence | 拒绝 |
| `defeated=1` | 清理并拒绝同代次后续反应，死亡演出接管 |
| `reduceMotion=1` | 身体幅度乘0.35；无额外镜头动态 |

原生最后一字段读取 `UIAccessibility.isReduceMotionEnabled`。组件计时使用 `Time.time`，与当前30fps捕获计时一致；不写任何全局时间倍率，也不改变原生计时。公开只读诊断：`battle.PlayerImpactFeedback.PlayCount`、`IsPlaying`、`LastSequence`、`RejectedCount`、`PeakAppliedDegrees`、`LastWasShieldOnly`。

录制器可在**正式敌伤害contact**后模拟一条原生损失回传，用上述90/1000测试值观察身体；必须标为“Unity桥接夹具”，不能声称是Swift实战伤害或自然新档战斗。治疗/增益/无伤准备不发。

## 文件与备份

- 修改：`UnityBattleSource/Assets/Scripts/UnityBattleBridge.cs`、`BattlePrototype.cs`、`mistport-ios/Mistport/UnityBattleHost.swift`、`ChapterOneTestView.swift`。
- 新增：`UnityBattleSource/Assets/Scripts/PlayerImpactFeedback20260925.cs`；独立Editor定向夹具 `PlayerImpactFeedbackReview20260925.cs`。
- 完整stage、各文件diff与改前SHA在 [output目录](../../output/player-impact-feedback-20260925/)。改前源码在 `backups/player-impact-feedback-20260925`。落盘前核对四份原文件SHA，避免覆盖并发修改；法术agent已加入的 `nameDevour` 参数保留。
- 未编辑其它法术/录制器、游戏数值、规划正文、原手玩报告或真实玩家偏好。

## 检查与证据边界

- [原生政策15项](../../output/player-impact-feedback-20260925/checks/native-impact-policy.txt)：从实际Swift文件原样抽取纯政策，以swiftc编译执行，覆盖真实HP/盾、净增益、0损失/免疫/控制、事件去重、混合损失、致死、减少动态、新context及非法最大HP。
- [Unity32项](../../output/player-impact-feedback-20260925/checks/unity-player-impact-passed.txt)：实际BattlePrototype场景及 `ApplyCommand`，检查真实骨骼反应、盾强度级差、减动态、重发/重复context、连击、不改根/镜头/时间、普攻接H07的动作所有权、新写入者不被恢复覆盖、停战/旧回执/换波/死亡/重试/禁用、包络边界。Unity退出码0，日志 `checks/unity-safety.log`。
- 两个修改的原生Swift文件语法解析通过；随后对35个实际原生Swift源文件共同执行iOS 26.5 SDK、arm64/iOS17、Swift6类型检查，**退出0**，包括完整 `UnityBattleHost.swift` 和 `ChapterOneTestView.swift`，不是只检查政策函数。先从当前CombatCore源码发射类型检查用模块；资源访问仅使用编译声明，不执行资源加载；UnityFramework使用当前导出的8份真实公开ObjC头组成仅头文件模块，因此 `canImport(UnityFramework)` 的正式桥接分支参加检查。证据：[结果](../../output/player-impact-feedback-20260925/checks/typecheck/result.json)、`checks/typecheck/app-command.json`、`checks/typecheck/app-typecheck.log`、可重跑 `checks/typecheck_native.py`。旧代码中3处忽略Void返回值的警告仍在，本次未改它们。
- 首次Xcode无签名构建的scheme前置动作自动启用Unity导出，为避免与法术录制竞争已主动中断（退出75）；导出停在assembly references，未完成。独立类型检查不链接、不输出可运行App、不完成Unity iOS导出，不能写为完整target构建成功。
- 新版受体实录及最终主观观察由 `SPELL_DISTINCT_IMPLEMENTATION_20260925.md` / 法术交付记录补充。本检查不外推真机帧率、配乐混音或用户认可。
