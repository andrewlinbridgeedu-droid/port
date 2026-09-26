# 1—15 进程旧测试契约迁移

## 范围与证据

基线：232 tests / 39 suites，70 issues。日志 `output/progression-optimization-20260915/tests-baseline.log`。
迁移后当前快照：234 tests / 40 suites，零失败，43 项既有暂停功能测试 skipped。日志 `output/progression-optimization-20260915/tests-contract-migration.log`。数学审计增加两项测试，后续数值调整后需由集成再次跑全量。

这不是 234 项真机或视觉检查；没有新增加 skip。既有 skip 包含暂停的旧铃、纸人、三证环等功能。

## 失败根因及处理

1. `Levels20RewardsRegressionTests` 53 issues：第 3 关期待旧假面卡而非遗落物；结算夹具用巨量生命抵抗伤害，在第 4 关按最大生命百分比攻击下仍然失败，引发后续奖励/关卡计数级联失败。改为公开玩家攻击 API 驱动胜利、无敌方时钟的纯结算夹具，保留逐关技能/格数/假面持有、重放及重复保存幂等检查。这个夹具明确不承担难度验收。
2. `MasqueradeTests` 3 issues：教学仍期待假面加入卡牌。改为遗落物拥有、旧卡清理、独立手动激活、原编排保持、两次拦截第三次受伤。
3. `FirstEightProgressionTests` 和 `PlayerTestProgressionTests` 各 3 issues：旧编排包含无法获得的假面卡，Q4/Q6—8 调度过期。改用共享实时规则模拟器，输入真实顺序结算的 campaign party、inventory、loadout 与手动假面所有权，Q1—10 和 Q1—15 均保留逐关胜利硬断言、来源合法、奖励与幂等检查。Q1 三次普攻教学时间由模拟器显式模拟。
4. `ChapterOneNaturalCombatTests` 8 issues：旧“一次玩家行动后全部敌人行动”的回合模型并非当前战斗模型，其胜负断言会误报。改为第 6—20 关实得卡牌/格数合法、假面独立于卡牌编排、手动激活后保持编排、公开攻击实际扣血的契约；第 16 关原独立时序胜利检查仍保留，迁移假面到手動遗物。第 16—20 关没有在本批扩展平衡设计或假称连续通关。

假面内部仍调用原技能解析（0.6 倍率伤害和 2 层误认），故伤害账本可含假面来源；测试严格仅在确实拥有假面时允许，并检查战斗编排未被临时授权污染。

## 修改与备份

仅改 6 个已有 Tests 文件；未改 Sources、HoundFinaleTests 或数学 agent 的新测试。
备份：`backups/progression-optimization-20260915/test-repair/`。

共享模拟最终采用 Unity 独立运行采样的敌方接触时长与技能 VFX 常量，保留独立敌行动及在途回调，不包含 Unity 真实动画采样、原生导航、存储 UI 或真机触摸。因此规则连续胜利不可表述为手机连续通关。

## 最终集成追加

- Q12 `PuppetCalibrationTests` 随正式四拍改为 fortify→slam→calibrate→slam，验证护甲到自身下一行动前有效、盾抵扣、校准只移盾不伤HP、重击2倍攻击，以及另一只傀儡保持错峰。
- 调度检查：Q13蓄力强击2.04秒、恢复0.65；新signature演员2.067；核心普通0.833/修复0.85；普通守卫0.967；蛭1.067，与本批采样常量及原生派发分支一致。
- 发现Q2分裂显现期原生暂停新玩家出招，而旧helper未暂停，已反馈数学agent并修正；不得用偏乐观模型验证无药重试。

### 最终全量（数值与Q2重试修复集成后）

`swift test` 返回 0：239 tests / 40 suites 通过，43 项既有 skip，无新增 skip。日志 `output/progression-optimization-20260915/tests-integrated-final.log`。本次包含新档Q1—15库存连续规则回放、三天赋与合法升级样本、Q2/Q3无药重试、独立多核心修复目标与护甲窗口合同。数值/模型运行审计分别见本批数学和模型交付报告。
