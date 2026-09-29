# Codex 任务单：App 的教会系战斗改用规则库驱动器 · 2026-09-29

交给 Mac 上的 Codex。背景见 [共享服 M0 记录](shared-server-m0-20260929/README.md)。回复用户用中文。

**为什么要做**：共享服用 `MPCChurchBattleDriver` 复算客户端的操作记录，来决定打没打赢。App 必须用同一份规则推进战斗，服务器复算才会和手机上的结果一致。现在 App 的教会系战斗（深井塔层、通缉、街头战、亮灯公共目标，编号以 `church_` 开头）在 `ChapterOneTestView.tickContinuousCombat()` 里自己排敌人出手，部分时机来自 Unity 回调。

**排序**：排在[首页任务单](CODEX_TASKS_HOME_MAP_20260929.md)和[城市贡献度任务单](CODEX_TASKS_CITY_CONTRIBUTION_20260929.md)之后。不影响单机玩家，**不改存档**。

## 规则库已有的东西

- `MistportCombatCore/Sources/MistportCombatCore/ChurchBattleDriver.swift`：
  - `MPCChurchBattleStepper` 每次 `step(inputs)` 推进 50 毫秒，返回表现事件：
    - `cast`：玩家出招开始，带 `landsAtTick`；
    - `landed`：出招命中；
    - `enemyAttacks`：敌人开始出手，带招式和命中时刻；
    - `enemyResolved`：敌人攻击结算。
  - 玩家输入只有五种：`target`、`medal`、`blankCard`、`consumable`、`ultimate`。
  - `stepper.log` 就是交给服务器的操作记录。
- 测试在 `ChurchBattleDriverTests.swift`。
- 驱动器现在和调参用的塔层验证模型（`MPCChurchTowerVerificationRunner`、模拟器 `TowerDriver`）一致，**和 App 还不一致**。

## 1. 先把 App 与驱动器的差别搬进规则库

逐条核对 `tickContinuousCombat()` 中 `session.isChurchCombat` 的分支和敌人出手部分。凡是影响胜负、血量、时机的，都要搬进 `MPCChurchBattleStepper`，不能留在视图或 Unity 里。已看到的差别：

| # | App 现在 | 驱动器现在 |
|---|---|---|
| 1 | 敌人死时还有已出手的攻击：`cancelCommittedEnemyImpact` 撤销 | 照常结算（`endRound`） |
| 2 | Unity 回调 `enemy-cancel:<id>` → `cancelTargetedSupport`，该敌人立即可再出手 | 没有 |
| 3 | 换波时清空所有待命中攻击、出手时刻，目标改为第一个活着的敌人 | 待命中攻击跨波保留 |
| 4 | 没有蓄力的教会敌人：出手后固定 0.5 秒结算，0.5 秒后可再出手；是否等 Unity 接触回调需核对 | 按 `MPCChurchTowerCatalog.contactDuration` 结算，结算后立即可再出手 |
| 5 | 玩家出招的命中时刻可能取自 Unity 接触回调（`pendingPlayerImpact`） | 固定取 `playerContact`（与塔层验证模型相同） |
| 6 | 真实时间（`systemUptime`） | 固定 50 毫秒一格 |

- 规则以 App 现行手感为准。每搬一条都在规则库补测试，并在 `ChurchBattleDriverTests` 里保留“录制＝复算”。
- 规则版本改成 `church-battle-v2`（`MPCBattleInputLog.currentVersion`）。
- 搬完后，模拟器的 `TowerDriver` 和 `MPCChurchTowerVerificationRunner` 也改用 stepper，再跑一次墙关探针和塔层验收，看调数结论变不变。变了要报告，不要自己改平衡。

## 2. App 改用 stepper

1. 教会系战斗开始时建 `MPCChurchBattleStepper`，配装和药用现在传给 `MPCChapterOneEncounterSession.start` 的同一份。
2. 显示循环里累计真实时间，每满 50 毫秒调一次 `step`。把这段时间里玩家的点按（换目标、勋章、名片、用药、终极技）作为输入传入。先看 `stepper.view.session.outcome`：战斗已结束就不传输入。
3. Unity 只按返回的事件播动画：
   - `enemyAttacks` 播出手，`enemyResolved` 播命中；
   - `cast` 播玩家出招，`landed` 播命中和飘字。
   - Unity 的接触回调不再决定结算时机；动画和规则时刻对不上时，调动画，不调规则。
4. `session` 改为读 `stepper.session`，界面上的血量、状态和结算都从这里来。
5. 战斗结束后把 `stepper.log` 存在内存里。DEBUG 下加自检 `--verify-church-replay`：打一场塔层（例如第 5 层）和一场亮灯公共目标，用 `MPCChurchBattleDriver.replay` 复算，胜负、剩余血量、用药数都要和手机上一致。
6. 现有 11 组 DEBUG 自检照跑。装机前后按惯例逐文件核对 Preferences；这项改动不应新增或改变任何存档键。

## 3. 交用户看的

- 真机录一场塔层、一场通缉、一场街头战，和改动前的手感对比。重点看敌人出手、玩家命中和飘字是否还同步。
- 用户认可手感之前，不要把这项标成完成。

## 不在这一单

- 主线 Q1–Q30 的战斗：各关有专门的出手节奏，另做。
- 联网：App 暂不连服务器。服务端在 `mistport-server/`，接入等 M2 小服。
