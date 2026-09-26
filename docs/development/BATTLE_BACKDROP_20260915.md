# 战斗页残留墨绿色背景修复
用户反馈 Build 8 紫金面板后仍有墨绿色。检查发现 ContentView 无条件挂载 MistBackground（MistportHero 原画），战斗页根 ZStack 透明，战场底部保留区通过透明空隙露出外层原画。此前只移除战斗局部渐变与顶栏绿色，未隔离外层背景。

本次：
- ContentView 在 dungeon 阶段使用纯黑底，不挂载 MistBackground。
- ChapterOneEncounterTestView 根部添加覆盖安全区的纯黑底，正式流程和直接测试入口均生效。
- 保留原有战场视口、紫金面板位置、原画和法术范围。
- 备份 backups/battle-backdrop-20260915；版本 Build 9。
- 不重置进度。原生构建/安装结果见日志与设备返回，仍需手机实屏视觉复核。
