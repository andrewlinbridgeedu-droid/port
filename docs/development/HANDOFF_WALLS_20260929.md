# 交接：墙关调数 · 2026-09-29（第二轮）

接手前按顺序读：本页 → [第二轮调数报告](progression-sim-20260929-tower-check/README.md) → [第一轮调数报告](progression-sim-20260929/README.md) → [HANDOFF_PROGRESSION_UI_20260928.md](HANDOFF_PROGRESSION_UI_20260928.md) → [HANDOFF_M0_20260928.md](HANDOFF_M0_20260928.md)。回复用户用中文。

## 仓库与分支

- **工作仓库：`github.com/andrewlinbridgeedu-droid/port`**（用户 2026-09-29 定为以后唯一的工作仓库）。换 Claude 账号也可以继续：新账号连上有这个仓库权限的 GitHub 账号，开会话时选这个仓库，先读本页。
- **最新分支：`claude/nifty-planck-80307c`**。它包含 `claude/world-economy-m0-u62oho`（第一轮墙关调数）的全部提交、`main`，以及本轮的提交，全部已推送。`claude/world-economy-m0-u62oho` 已落后，不要再往上面提交。
- `main` 还没合并这些分支；用户同意后再开 PR。
- 第一轮交接提到的 `showcase.py` 冲突已在本分支合好（保留 PIL 画字，字体优先用 main 选的华文黑体）。

## 用户 2026-09-29 的决定（本轮已实装）

1. Q18、Q26 不是墙 → 先选“拉陡塔装备曲线”；实测需要每 20 层战力翻倍后，改为**塔层装备检定**，曲线只温和拉陡。
2. 验收第 3 条改为“只做通缉卡在 Q8”。
3. 通缉战败只扣铜，不再丢随身遗落物。
4. 验收第 4 条只算过墙必需的支线。

## 本轮完成

- **塔层装备检定**：Q18 第十三击、Q26 押运车猛砸、Q30 总签官猛砸，身上没有来自 F50/F70/F90 或更深的塔装备时按基础生命 140% 结算。新字段 `MPCChurchGearStats.towerDepth`，判断在 `MPCProgressionWalls.meetsTowerFloor`，数值在 `towerCheckBlowHealthPercent`。
- **塔装备曲线**：F2–F10 不变；F20 起每 10 层约 +10% 攻击，护甲生命和减伤同步加快（表见报告）。
- **机制墙跟着加重**：Q12 强化上限 95%；Q22 失败重击 140% 生命、钟匠 5000 血；Q30 总签官 6500 血。
- **Q18、Q26 这一仗本身加压（用户要求）**：裁定者 5200 血 / 140 攻，押运车 5600 血 / 150 攻。满足塔层后中熟练首次剩 36%、37% 血（原 65%、53%），检定不变。
- **通缉战败只扣铜**：`MPCBountyDefeatRisk` 不再返回遗落物；App 两处说明文字和风险自检已改。
- **失败提示**：`defeatHint` 新增 `wornTowerDepth`（App 调用处已传），打到过要求层但身上装备不够深时，提示换装备。
- **测试**：规则库 472 个全过（云端 Linux）。新增 `towerWallsNeedTheirFloor`、`towerDepthComesFromTheDeepestWornPiece`；三个旧测试随改动更新。
- **模拟器**：新打法 `hinted`（按失败提示只补必需支线）；止痛膏重试改为换整套打法（修正了第一轮“低熟练卡 Q8 是因为丢遗落物”的误判，真正原因是机器人总把唯一一瓶药用在同一套会输的打法上）；探针新增 `GEAR_SCALE`，`WALLS=` 新增三个检定键。
- **验收**：六条全过（第 4 条有分母口径说明，见报告）。

| 关 | 状态 | 要求 |
|---|---|---|
| Q3 | 放宽（不是墙） | — |
| Q8 W1 | ✅ 数值墙 | 塔 F10 |
| Q12 W2 | ✅ 机制墙 | B01 七号缺齿剑 |
| Q18 W3 | ✅ 塔层检定 | 身穿 F50 或更深的塔装备 |
| Q22 W4 | ✅ 机制墙 | B04 伪造者倒签笔 |
| Q26 W5 | ✅ 塔层检定 | 身穿 F70 或更深的塔装备 |
| Q30 W6 | ✅ 塔层检定＋机制墙 | 身穿 F90 或更深的塔装备 ＋ B10 绯月寿账签 |

## 需要用户定的（可选）

1. **第 4 条的严格口径**：按“准备好了再打”的主线时间（约 29–47 分钟）算，必需支线（主要是爬塔到 F90，约 73–87 分钟）是主线的 1.9–2.6 倍。模拟器不算剧情对话和探索，真人主线更长，实际比例会更低。要压到 2 倍以内，可以缩短每层耗时，或降低 Q30 的塔层要求。用户暂未要求改。

## 没验证

- **iOS App 从 `cee125a` 起没编译过。** 本轮 App 只改了：两处通缉说明文字、`verifyBountyDailyRisk` 自检、`wallDefeatHint` 多传一个参数。规则库里 `MPCChurchGearStats` 多了带默认值的字段。
- 没有真机、没有真人试玩；机器人熟练度只能相对比较。Unity 端没有塔层检定、Q12 叠层、Q22 校验失败、Q30 狂暴的专门演出。

## 下一步（按优先级）

1. 交给 Codex（Mac）：拉 `claude/nifty-planck-80307c`，`xcodebuild`，按惯例备份 Preferences 后装机；看“封线装备”页通缉栏、通缉案卷的遗落物说明、墙关失败提示（含“换上深井第 N 层或更深的装备”）、通缉战败说明，以及几个新机制的实际手感。装机、编号、SSD、存档隔离规矩见 `HANDOFF_PROGRESSION_UI_20260928.md` 和 `AGENTS.md`。
2. 用户对上面两条可选项的意见。
3. 其余 7 件遗落物效果；第二章核心人物战、死亡与继任；服务端账户与可信战斗结算小样。

## 常用命令

```sh
# 规则库测试（Mac）
cd mistport-ios/MistportCombatCore && swift test
# 模拟器：六堵墙探针（约 5 秒）
swift run -c release --package-path tools/progression-sim ProgressionSim walls <输出目录> 8,12,18,22,26,30 high,medium,low
# 临时改墙值扫参数，不改代码
WALLS="q18GearCheckHP=160,q30SovereignHP=7000" swift run -c release --package-path tools/progression-sim ProgressionSim walls <输出目录> 18,30
# 估算塔装备曲线要多陡（只影响探针）
GEAR_SCALE="attack=2,hp=2,reduction=1.5" swift run -c release --package-path tools/progression-sim ProgressionSim walls <输出目录> 18
# 单关逐套打法；TRACE=1 打印每次敌人行动
swift run -c release --package-path tools/progression-sim ProgressionSim fight 22 medium 50 bounty_relic_b04_reverse_seal
# 串行全流程（约 1 分钟）与汇总（含第 4 条比例）
swift run -c release --package-path tools/progression-sim ProgressionSim <输出目录> 0,30,90
python3 tools/progression-sim/report.py <输出目录>
```

可调键名见 `tools/progression-sim/Sources/ProgressionSim/Walls.swift` 的 `WallTuning`。

## 在 Linux 云端跑 Swift

官方下载被网络策略拦截。从 `archive.ubuntu.com/ubuntu/pool/universe/s/swiftlang/` 取 `swiftlang`、`libswiftlang` 的 6.0.3 deb（`6.0.3-2build1`），再从 `pool/main/libx/libxml2/` 取 `libxml2-16`（`2.14.5+dfsg-0.2ubuntu0.2`），`dpkg -x` 解到临时目录，设 `PATH=<目录>/usr/libexec/swift/bin:$PATH` 和 `LD_LIBRARY_PATH=<目录>/usr/lib/x86_64-linux-gnu:<目录>/usr/lib`。`S9TalentEditorTests` 里一个 `@MainActor` 测试在 Linux 的测试自动发现下编不过：跑测试时在临时副本里去掉这个文件，它只在 Mac 上跑。
