# 敌人真实命中反馈运行验证

## 验证边界

`EnemyImpactCapture.cs` 通过正式 `PresentPlayerBasic/PresentPlayerSkill` 产生真实 `combat-contact`。独立播放器收到该回调后，测试夹具发送正伤害收件人 `enemy-impact:skill:stableIDs`；不是自行制造命中时刻。这验证 Unity 演出/桥接/收件人/恢复，不执行 Swift 数值引擎，不等于 iPhone 触控、扣血或美术验收。防御 09 不发送正伤害通知。

## 已完成运行

`output/enemy-impact-20260915/run1/passed.txt`：

- 普攻、01/02/04/05/06/07/08/10，各一次真实玩家命中回调；有结束事件的技能各一次结束回调。
- 09 一次正式演出，不产生敌人受击反馈。
- 空壳守卫、幽灵、早犬、铠甲犬、翠焰亡灵、寄忆核心、记忆蛭、档案守卫、织幕女主九类实际模型。
- 四只赤红幽灵：错步双目标仅两只反馈，单目标仅一只反馈，未命中对象计数不变。
- 在敌方施法时叠加受击，仍有且仅有一次敌方实际命中回调；死亡/隐藏、停战清除活动受击，重新显示恢复。
- 映射数量：守卫 5、幽灵 5、早犬 2、铠犬 3、亡灵 4、蛭 7、档案守卫 4、女主 5。核心无骨骼走自身缩放反馈。

真实帧每 0.05 秒保存，有 timestamps.csv；GIF 由实际帧拼接，无画面合成。示例 `run1/skills-basic.gif`、`run1/skills-fool_skill_01.gif`、`run1/skills-fool_skill_07.gif`、`run1/split-dual.gif`。

最终重量分层版本在 `final/passed.txt` 已通过定向重测普攻、01、07、09、10，并重复全部模型、四怪收件人与并发/清理。`final/skills-basic.gif`、`final/skills-fool_skill_01.gif`、`final/skills-fool_skill_07.gif` 为最终强度版本真实画面。

## 第3/4关步态追加反馈

`q4-gait/passed.txt` 确认正式第4关设置下四肢持续变化、编队根不漂移，攻击/受击/死亡取消/重试后恢复。真实动画 `q4-gait/q4-continuous-gait.gif`。但肉眼及末端骨 y 值发现原 walking 恢复后犬浮地，已回报主 agent 修正；这份技术通过不表示步态画面通过。


### 贴地修复后定向复测

`gait-grounded/passed.txt` 已通过同一真实第4关设置的六阶段检查。实际皮肤16相位最低点原为0.35756–0.39274，修正量-0.35756，修正后最低点范围0–0.03518世界单位；EnemyRoot与MotionRoot维持(0,0,12)。四脚保持连续交替变化，攻击、受击、死亡取消及重试后恢复。实际第008帧与原版对照，原持续约0.36单位悬空已消除；保留步态自身起伏。

动态图：`output/enemy-impact-20260915/gait-grounded/q4-grounded-continuous-gait.gif`，30张实际帧、约15 fps。这里没有重新执行Q4火球capture，因为旧capture不设置第4关presence，不能用它冒称新的贴地嘴部锚已运行验收；锚偏移的实拍边界需单独注明。
