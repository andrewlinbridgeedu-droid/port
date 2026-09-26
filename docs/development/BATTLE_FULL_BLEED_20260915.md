# 战场延伸至卡牌面板后方
用户截图说明此前“去墨绿色”指删除面板后整块空白，而非换成黑色。本次删除 ChapterOneEncounterTestView battlefield 的底部 min(320,max(240,height*.34)) padding。Unity 与 SpriteKit 共用完整战场视口，紫金面板在其上悬浮；底部安全区也由战场覆盖。顶栏和卡牌面板自身颜色/尺寸/位置不变。

备份 backups/battle-full-bleed-20260915，版本11。这会增加战场视口高度，实际角色/地面法术构图需要真机复核；不宣称已有实拍验收。

Build11构建成功，已安装并启动iPhone13。安装前后存档一致：True；测试入口：True。
