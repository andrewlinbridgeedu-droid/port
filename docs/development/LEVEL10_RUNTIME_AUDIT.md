# 第10关运行差异审计（2026-09-11）

范围：只读源码、针对性规则测试。未操作模拟器，未修改生产源码；不是实战验收。

## 关键结论

1. **默认目标与测试不一致，已确认。** `ChapterOneTestView.swift:3176` 的 `defaultTargetID` 对第10关两敌返回第2只抄录傀儡；`FirstEightProgressionTests.swift` 始终先打第1只猎犬。第10关敌人顺序在 `ChapterOneContent.swift:556`。隔离副本只改第10关优先攻击傀儡，复现22.1秒失败、0HP、纸人耗尽；相比猎犬优先26秒胜利/192HP，目标顺序已证实足以导致规则层胜负翻转。先选猎犬是否解决实战失败仍需主agent实测。
2. **原规则测试本轮通过。** 定向运行 `swift test --package-path mistport-ios/MistportCombatCore --filter FirstEightProgressionTests`，1测试通过。第10关26秒胜利、192HP、纸人未触发。日志 `/tmp/mindstone-q10-audit-tests.log`。它不是Unity接触回调测试。
3. **规则测试不覆盖真实contact时刻。** 测试固定玩家技能0.78秒、普攻0.58秒、猎犬1.1秒、傀儡0.65秒；原生连续战斗等待Unity contact（`ChapterOneTestView.swift:1452,1505`）。伪证fallback约0.63秒结束后才上报contact，错步V1约0.6192秒；不是统一0.78秒。未发现证据支持伪证导致明显更长施法阻塞。
4. **第10关ID路由静态看可成立。** 猎犬走hell-hound-primary，傀儡复用clock-guard-primary，二者分别上报对应enemy contact。共享enemy字段由UseLateEscort(true)保持为猎犬，守卫动画使用显式handle，不能仅凭共享字段认定错配。
5. **零血仍等contact可能是设计中的尾弹，也可能是丢回调。** `committedEnemyImpacts`清空前不能victory；真实层无超时回退。因此只凭零血截图无法判断。应核对发起记录、每个contact及pending是否最终清空，而不是直接强制胜利。
6. **纸人是一次致命保护，不是长期减伤。** `ChapterOneEncounterRuntime.swift:1749`中致命伤保留1HP并耗尽。原通过测试根本没触发它，不能证明实际装备与触发正常。

## 最小实测步骤

使用已安装最新构建与隔离测试存档进入第10关；记录战前两张牌顺序“伪证→错步”、纸人装备、默认黄色选中环。开战后主动选择猎犬，完整记录战斗至结果与返回主城。确认猎犬、傀儡各自contact，最后威胁处理结束后才胜利；奖励后进度10/20、四格可真实编排，退出重启仍保留。

若先猎犬通过但默认失败，调整默认目标应基于明确教学/威胁顺序，不调低血量掩盖问题。若仍失败，优先对照实际耗时、伤害对象及contact，而不是再次全量规则测试。

模拟器录屏可用 `xcrun simctl io F93741F2-6102-48FE-999B-EC2436F76CBF recordVideo /tmp/q10-runtime.mp4`；截图用同一io命令的screenshot。主agent独占模拟器，本审计未运行这些命令。跳关证明只记作跳关实测。

## 对照测试补充

生产源码未修改。复制Swift包到 `/tmp/mindstone-q10-audit-package`，仅将第10关目标从首个存活敌人改为末个存活敌人（傀儡优先），其余相同。命令：`swift test --package-path /tmp/mindstone-q10-audit-package --filter FirstEightProgressionTests`。第1—9关结果不变，第10关22.1秒defeat、0HP、relicUsed=true，胜利断言失败。日志 `/tmp/mindstone-q10-puppet-first.log`。这是有控制的规则对照，不是Unity实测。
