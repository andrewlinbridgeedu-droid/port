# 第一章高层与通缉战场直达审计入口

2026-09-25。此前真机手玩覆盖塔F1–10，却未覆盖D03／D04／D05／D06首现高层及十案战场；正常塔流程仍要求逐层首通。为检查敌人外形、左右站位、名字与法术而新增 **Debug专用隔离预览**，不改变正式解锁条件和结算。

`ChapterOneTestView.swift`只在同时含`--player-test-audit`时读取以下参数：

```text
--player-test-audit --preview-chapter-one-church-floor=51
--player-test-audit --preview-chapter-one-bounty-case=B09
```

塔层范围为1–100，案号会转为小写再查当前十案。入口在内存中用现有`claimVictory(for:)`造一套Q30等效手牌，再由`MPCChapterOneEncounterSession.start`进入对应战场；`ContentView`的直达分流受`#if DEBUG`限制。这里的Q30等效是**审计夹具**，不能当玩家合法成长、关卡连续通关或塔／案领奖。直达视图没有调用`GameStore`塔／通缉奖励结算；手机实际偏好是否出现其它副作用仍须在装机前后逐文件比较。

`xcrun swiftc -frontend -parse`通过；签名Build126的完整Xcode编译通过，构建日志中有`SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG`和Swift编译`-DDEBUG`。Build126已覆盖安装并普通启动，但高塔/通缉新直达入口因镜像中断**尚未在手机运行**。后续需要真机分别实看F21／31／41／51、B01–B10，留下完整战前、战斗、结算或退出截图，再恢复普通无参数启动并核正常玩家存档。若只看直达样本，应在证据表明确标为夹具战场，不把它写成剧情调查、塔百层或十案自然完成。

构建与手机状态：[新版法术Build126报告](SPELL_IMPACT_DEVICE_20260925.md)；已有真实手玩：[第一章手玩报告](CHAPTER1_MANUAL_STORY_AUDIT_20260925.md)。
