# 教会入口黑屏修复 · Build46

进入封堵按钮改为「进入封印」。ChurchTowerView 从 Bool 弹窗加可选 session 改为 item 驱动的 BattleDestination，保证战场出现时已有完整 session 和楼层。

Build46 原生构建成功，已安装并启动 iPhone13。通过 --verify-church-entry 调用相同 launch(1) 入口；真机截图显示井口巡火、正确封印背景、猎犬、主角与整备卡牌。日志 CHURCH_TOWER_ENTRY_READY unity=1 anchors=1。此验证为入口及战前界面，并非全塔连续通关。

证据：output/church-entry-fix-20260917/phone-entry.png、phone.log。安装回执与存档比对见 backups/church-entry-fix-20260917；玩家存档 changedKeys=[]。验证后已普通方式重新启动。
