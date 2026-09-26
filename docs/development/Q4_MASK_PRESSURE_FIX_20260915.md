# 第四关假面交互与压力修复

用户反馈Build19假面点不了、不用也能赢，要求不要战斗机制提示字。

## 本次修改
- 编排条的装饰Image+onTapGesture改为原生Button、完整卡牌contentShape与稳定accessibilityIdentifier。
- 战斗手牌只显示本场手动编排的牌和终极牌；原先未编排假面仍显示，点击却被requestEmeraldMask guard忽略。没有自动装备假面，保留战前手动选牌规则。
- 战斗期间去掉卡牌右上详情点击与长按详情处理，避免详情手势抢走施放；战前仍能查看。
- 假面准备好用边缘光标识，沿用即时展开、两次承伤、12秒冷却。
- 移除战斗区蓄力说明、毒雾浓度伤害说明、假面用法横幅与“点击假面”文字；保留伤害飘字、技能名和冷却扇形。剧情对白不在本次提示字移除范围。
- Q4追索火球每颗改为向上取整55%最大HP，1000HP时550；试探80、敌人620HP、2秒预警和14秒周期不变。无需硬性装备校验/锁血。

## 验证
Q4及EmeraldPoison11项测试函数通过：初始队伍不挡首次双焰9.1秒败；6.2秒施放假面12.65秒胜、剩920HP；提前用假面被试探耗掉一次后受550伤，不触发破绽。Q3伤害260、Q5机制保持。
SwiftUI语法解析通过。原生构建/安装结果待下文；未把核心模拟当作真机触摸验收。

备份：backups/q4-mask-pressure-20260915、backups/q4-pressure-fix-20260915。

Build20原生构建成功，已安装并启动iPhone13。存档变化键：['chapter-one.behavior-tags', 'mistport.pending-settlement.v1', 'chapter-one.battle-loadout', 'chapter-one.completed-mission-ids', 'chapter-one.tutorial-flags', 'mistport.campaign-inventory.v1', 'chapter-one.combo-records', 'economy.venue-coins']；测试入口=True。未重置进度或安装模拟器。实际手指点击是否消除用户遇到的问题仍待真机复核。
完成关卡集合检查：旧完成记录均保留=False。期间设备存档有新战斗进度，不宣称整个文件相同，未覆盖为旧备份。
