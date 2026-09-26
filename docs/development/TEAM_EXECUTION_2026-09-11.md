# 团队首批执行记录

## 授权恢复与重建
后续：Xcode BUILD SUCCEEDED，安装完成；新进程14585以--verify-p1-ui启动。实际看到第1关正常人形主角、无黄色标记与红色异常条；当前日志未匹配NullReference/切图越界。运行日志在模拟器data/tmp/fogharbor-live-stdout.log与stderr.log。测试期间页面被其他操作切换到行囊，已暂停控制并询问用户是否可独占模拟器。第2—10关尚未完成新版逐关验收，不能把本次第1关画面外推为全部通过。
用户明确允许重启后，已停止卡住的7263授权进程，Unity重新启动授权成功。InstallP1Visuals.InstallAndExport 与随后包含combat-stop清理修复的 ExportIOSLibrary.Export 均exit 0。日志 /tmp/fogharbor-recovery-unity.log、/tmp/fogharbor-final-unity.log。
combat-stop现在清理纸人、主角死亡碎片并恢复主角，避免中断演出后跨关残留。iOS构建日志 /tmp/fogharbor-recovery-xcode.log；下方早先阻塞记录为历史。

## 用户视觉回归反馈（后续）
用户提供第2/3关纸片主角、底部异常和悬空黄圈截图，并以正常第4关截图指定恢复基准。明确要求不显示选敌标记，保留交互。
已从 ChapterOneTestView.swift 删除可见黄色椭圆。FoolDefenseVFX碎片分割由浮点网格改整数像素边界，避免2048/15最后一行越界；Luna继续修复临时纸人根对象重置清理。这些尚未构建安装，不能标记实机恢复。
授权客户端日志进一步确认 global mutex 被另一实例占用；已向用户重新询问是否允许重启授权进程，等待答复。不会以权限环境变化代替对先前拒绝操作的重新授权。

## 已建立
- 根目录 AGENTS.md 与 AGENT_TEAM.md；主 agent 集成，专业子 agent 按需执行。
- 用户成本偏好已保存：简单任务优先 Luna。本批敌人差异与资产规格已由 Luna 完成。
- 用户要求每关敌人有可辨识变化，保留第3—6关同犬连续性。

## 源码已修改（尚未新版本实机验收）
- ChapterOneTestView.swift：技能编排遵守 campaign.loadoutSlotCapacity，满格时说明先移除再替换；猎犬/傀儡组合默认优先猎犬；开始战斗保留战前主动选择的存活目标。
- ChapterOneContent.swift / ChapterOneOnboarding.swift：第9/10关授予时机与伪证烙印名称一致。
- MemoryLeechPresentation.cs：动画缺失保护、死亡不被投射完成后的Idle覆盖、弹体接触落点。
- InstallP1Visuals.cs：生成持久化独立动画引用。
- BattlePrototype.cs：猎犬显式使用自身actor/home/animator。

备份：/tmp/fogharbor-main-backup、/tmp/fogharbor-agent-backup/battle-3d、/tmp/mindstone-content-audit-backup。

## 本轮证据
- 两个改动Swift界面文件 swiftc -frontend -parse 通过；仅语法检查，不是类型检查或完整构建。
- 第1—10关定向规则测试通过；第10关猎犬优先26秒胜利/192HP。隔离副本仅改傀儡优先则22.1秒失败/纸人耗尽。详见 LEVEL10_RUNTIME_AUDIT.md。
- 当前已安装旧版本经开发列表进入第8关，仍见单守卫与两个血条、记忆蛭不可见；未通过模型验收。
- 当前已安装旧版本第10关前置剧情可显示；明确另一只猎犬及胜利后四格。
- 第10关战前选伪证→错步并点猎犬，开战后黄色标识实际重置到傀儡；源码已修，未安装验证。途中再次点猎犬，最终回主城仍9/20；不算胜利。
- 没有新档连续通关证据。

## 构建阻塞
Unity授权服务连接失败，日志 /tmp/fogharbor-team-unity.log。最初沙箱运行留下授权进程；停止该进程的权限请求被拒绝，未执行或绕过。授权失败是否仅由该进程导致尚不能确认。
Xcode scheme会自动导出不新鲜Unity内容，与正在等待授权的导出冲突；已停止本轮Xcode及Unity编辑器构建会话，未绕过freshness检查，未安装新版本。授权服务子进程未主动终止。

恢复Unity正常授权后执行 InstallP1Visuals.InstallAndExport，完成后再Xcode构建、安装，实测第8模型、第7选敌、第10胜利/四格/保存。第9正式4点与独立傀儡模型仍是明确缺口。

## 18时后逐关推进与用户改向
第4关旧扑咬版曾实际胜利，4/20、铜币270→300、拓片×1入袋原画可见，录像output/level-verification/q4-current.mov。用户随后否定扑近，现已改charge→memory_breath远程循环及剧情；148项核心测试通过，新版实测待完成。第5关用户明确换怪，旧猎犬/纸人保命方案不再验收，工作稿Q5_SEAL_WARDEN_REDESIGN.md。主线不额外经验，日常另接，已由用户明确选择。
第8/9关独特法术候选04/05已加入目标侧错位/落印，接触时回调，取消清理；Unity最终导出成功（/tmp/fogharbor-distinct-spells-final-unity.log），iOS最终构建进行中。未经场内验证，不称特效完成。移交单原画ItemSealedTransfer已映射。
