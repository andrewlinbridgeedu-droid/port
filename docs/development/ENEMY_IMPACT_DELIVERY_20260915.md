# 技能命中反馈与早犬连续步态 · 2026-09-15

用户要求所有技能打中怪物有明显痛感；追加第3/4关旧犬持续四脚走动，不再走停。

Swift实际结算正damage的目标构建enemy-impact通知，保留战前当前编队稳定identity，包含致死、双目标、普攻与假面遗落物。未知对象不改打别的怪，零伤害/纯防御不触发身体受击。连续战斗用真实Unity contact→核心结算→feedback；旧顺序模式在原结算展示时发通知。移除玩家演出末尾的旧Hit触发，避免无伤害假命中和延后受击。

新EnemyImpactFeedback按骨骼/体型局部压缩、后仰、约60ms姿态滞留与阻尼恢复，叠加于原动画，不暂停Animator或Time.timeScale，不移动编队root。附短促材质闪与紧凑命中碎线。普攻0.68、假面0.85、重技1.18/1.4，其余1.05力度系数仅影响视觉。BeginDeath恢复身体但保留短爆点尾效，重试/跨关清理。

第3/4关SetMission跳过旧犬bind站姿覆盖，恢复原walking片段连播，Idle速率.72；保留远处喷火与站位，不让受伤打断步态。第6关及其它模型继续上一批待机。

备份backups/enemy-impact-20260915与backups/early-hound-continuous-walk-20260915。核心测试9函数通过（包含参数化Q4/稳定identity）：正伤害映射、零/负伤害忽略、目标去重、致死与失效目标、Q4三轮规则未变。独立Unity与原生验证状态待本批末更新。

## 实际验证

output/enemy-impact-20260915/run1/passed.txt覆盖全部八伤害技能+普攻与防御无反馈，九类模型，四鬼双/单目标只确认收件人触发，敌施法并发callback仍恰好1次，死亡/停战清理。final/passed.txt在最终力度版定向复测普攻/01/07/09/10及同样九模型/并发/目标，全部通过。Unity用真实contact回调后正伤害fixture通知验证，Swift身份/正伤害过滤另由核心测试验证；不是原生手机触控录像。

用户连续步态修复：gait-grounded/passed.txt六阶段通过。真实walk片段16相位皮肤最低点原0.35756—0.39274，固定offset−0.35756后0—0.03518；四脚持续交替、EnemyRoot/MotionRoot不动。动态图gait-grounded/q4-grounded-continuous-gait.gif。火球源高度同步同offset，新源锚未另作专门实拍，不把旧火球capture当新锚验收。

Unity iOS最终导出成功；Build25原生编译/安装状态待末尾记录。未重置玩家存档。

最终Build25原生构建成功，已安装并成功启动iPhone13。更新前后存档比对一致。安装/启动JSON和存档备份见backups/enemy-impact-20260915。真机逐关触控与主观力度仍待用户复核。
