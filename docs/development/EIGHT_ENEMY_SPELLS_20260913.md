> 后续状态：用户已否定本页原几何/细线版视觉。新一轮主角九招与四怪八招重做见 [HERO_AND_ENEMY_THEATRE_20260913.md](HERO_AND_ENEMY_THEATRE_20260913.md)。本页旧截图、旧测试不能代表新视觉验收。

# 四怪八法术视觉加强

最终Unity运行版本（v2）已录制，动态预览见index.html或四个GIF；eight-spells-contact-sheet.jpg为八招实际帧总览。

- 猎犬1：熔火冠冕、卷焰双翼、爆裂火环。
- 猎犬2：锁链火流、合拢獠牙、余烬碎片。
- 机器人1：飞臂、蓝白螺旋推进、电光归位。
- 机器人2：琥珀机械阵列、六路电光轨道、分层冲击。
- 女主1：红丝玫窗、交织收束、断丝花瓣。
- 女主2：红色织机、金属针雨、玫金拖尾。
- 亡灵1：翠焰缚魂帷幕。
- 亡灵2：金绿返场花冠。

本批仅改变表现；亡灵新增第二视觉并轮流呈现。敌方伤害、命中时机、铃延后3秒及返场+50%的契约不改。

## 实际验证

- Unity macOS实际运行：八招各命中1次，所有capture完成。
- 飞臂飞行中取消：源手臂恢复、临时飞臂消失、无迟到伤害。
- 蓄力取消、双敌死亡取消、准备动作死亡取消：全部通过。
- Unity iOS模拟器导出与Xcode ARM64构建通过。
- 新版本已安装iOS模拟器，第10关双敌和第5关亡灵试演战斗已截图；亡灵两种视觉轮换可见。第5关该入口带遗落物试演，不代替正式技能规则验收。
- 第15关iOS跳关战斗截图确认红丝展开与针雨，两枚核心与主角同时正常呈现。
- 预览并非实机性能测量，也不是新档连续通关。

## 修改归属

EnemySignatureSpellVFX.cs及两个partial负责六种法术的批量mesh；EmeraldRevenantSpell.cs负责另两种；BattlePrototype只补亡灵视觉轮换及八招QA入口，SignatureSpellCapture增加两招和飞臂取消验证。原文件保留在backups/eight-spells-20260913及ArtSource/EmeraldEncoreRework/vfx_backup。
