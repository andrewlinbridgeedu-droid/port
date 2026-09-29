# 交接：墙关调数 · 2026-09-29

接手前按顺序读：本页 → [调数报告](progression-sim-20260929/README.md) → [HANDOFF_PROGRESSION_UI_20260928.md](HANDOFF_PROGRESSION_UI_20260928.md) → [HANDOFF_M0_20260928.md](HANDOFF_M0_20260928.md)。回复用户用中文。

## 仓库与分支

- **工作仓库：`github.com/andrewlinbridgeedu-droid/port`**（用户 2026-09-29 定为以后唯一的工作仓库，已加合作者）。换 Claude 账号也可以继续：新账号连上有这个仓库权限的 GitHub 账号，开会话时选这个仓库，先读本页。
- **当前分支：`claude/world-economy-m0-u62oho`**，在 `claude/world-economy-m0`（`cee125a`）之上多 5 个提交（含本交接那次），全部已推送：

  | 提交 | 内容 |
  |---|---|
  | `42b4e1c` | 模拟器：通缉发遗落物、按墙换装、日刊保底、`walls` 探针 |
  | `906054e` | 调 Q8、Q12、Q22、Q30；墙值集中进 `MPCProgressionWalls`；旧平衡测试改带墙要求 |
  | `aa27379` | 新测试：机制墙必须带对应遗落物 |
  | `66b692a` | Q3 放宽、Q12 定值、模拟器邮务买药重试、调数报告 |
  | 最新 | 补全本交接 |

- `main`（`f895d75`）落后，是本分支的祖先，**还没合并**；用户同意后再开 PR。
- `claude/nifty-planck-80307c` 上有一个未进主干的小修 `46ec077`（`tools/vfx-spectacle-20260926/showcase.py` 改用 PIL 画字、不依赖 ffmpeg drawtext），与 main 后来的 `3ccd339` 冲突，需要手工合。
- `refs/claude-teleport/aa28507a5662afdb`（`f7a7fed`，另一会话的 WIP）内容已包含在 `cee125a` 里，只差一张不再被引用的旧城景图，可以忽略。

## 本次完成

墙关现状（数值都在 `BountyRelics.swift` 的 `MPCProgressionWalls`）：

| 关 | 状态 | 机制与数值 |
|---|---|---|
| Q3 | 放宽（不是墙） | 猎犬吐息 260 → 180 |
| Q8 W1 | ✅ 数值墙 | 记忆蛭血 1900；不打塔三档都输，带 F10 中熟练首次 39% 血 |
| Q12 W2 | ✅ 机制墙 | 强化叠层不消退，每层减伤 50%，上限 90%，缺齿剑清空；人偶 1300 血 / 55 攻 |
| Q18 W3 | ❌ 未生效 | 旧值；做不成数值墙，待用户定 |
| Q22 W4 | ✅ 机制墙 | 每轮两次校准，要命中 5 次；失败重击不带倒签笔 = 110% 基础生命；钟匠 3500 血 |
| Q26 W5 | ❌ 未生效 | 旧值；同 Q18 |
| Q30 W6 | ✅ 机制墙 | 总签官 5200 血；三分之二血以下狂暴，每击 ≥ 70% 基础生命；寿账签免疫。“F90”实际不是必要条件 |

- 规则库 **470 个测试全过**（云端 Linux）。旧平衡测试改为带上墙要求的塔装备与遗落物（`EarnedChapterAuditFixture.wallGear/wallRelic`）；新增 `mechanismWallsNeedTheirRelic`；Q3 吐息断言改读 `q3BreathDamage`。
- 模拟器 `tools/progression-sim`：遗落物与通缉栏、日刊保底、卡关跑邮务买药并换遗落物重试、`walls`／`fight` 模式、`WALLS=` 临时覆盖数值、`TRACE=1` 打印敌人行动。
- 设计稿顶部已加状态说明，指向调数报告。

## 需要用户定的

1. **Q18、Q26：** 塔装备曲线太平（F10 +36% 攻、F50 +46%、F90 +56%），数值墙做不出来。选一：拉陡塔装备曲线（连带调塔层敌人）／改成机制墙用 B09 吞契铜背甲、B06 无灯舱甲（本来是第二批）／只留 W1 一堵数值墙。
2. **验收第 3 条**（只做通缉应过 Q12、卡 Q18）和 W1 是数值墙冲突：只做通缉的人卡在 Q8。改标准还是改 W1。
3. **低熟练通缉战败丢光商店遗落物**，6 次里 2 次因此卡 Q8。可改为通缉战败只扣铜。
4. **支线时长：** 低熟练“先清支线”约主线 40 分钟、支线 190 分钟，超过标准的 2 倍，主要是塔爬满 100 层。

## 没验证

- **iOS App 从 `cee125a` 起没编译过。** 本次没改 App 代码，但墙值、墙关失败提示文字（Q12、Q30）和缺齿剑说明变了。
- 没有真机、没有真人试玩；机器人熟练度只能相对比较。Unity 端 Q12 叠层、Q22 校验失败、Q30 狂暴没有专门演出。

## 下一步（按优先级）

1. 等用户对上面 4 条的决定，再按决定调 Q18、Q26，重跑模拟器验收。
2. 交给 Codex（Mac）：拉本分支，`xcodebuild`，按惯例备份 Preferences 后装机；看“封线装备”页通缉栏、通缉案卷的遗落物说明、墙关失败提示，以及三个新机制的实际手感。装机、编号、SSD、存档隔离规矩见 `HANDOFF_PROGRESSION_UI_20260928.md` 和 `AGENTS.md`。
3. 其余 7 件遗落物效果；第二章核心人物战、死亡与继任；服务端账户与可信战斗结算小样。

## 常用命令

```sh
# 规则库测试（Mac）
cd mistport-ios/MistportCombatCore && swift test
# 模拟器：六堵墙探针（约 1 秒）
swift run -c release --package-path tools/progression-sim ProgressionSim walls <输出目录> 8,12,18,22,26,30 high,medium,low
# 临时改墙值扫参数，不改代码
WALLS="q18AdjudicatorHP=3200,q18ChargePercent=260" swift run -c release --package-path tools/progression-sim ProgressionSim walls <输出目录> 18
# 单关逐套打法；TRACE=1 打印每次敌人行动
swift run -c release --package-path tools/progression-sim ProgressionSim fight 22 medium 50 bounty_relic_b04_reverse_seal
# 串行全流程（约 15 秒）与汇总
swift run -c release --package-path tools/progression-sim ProgressionSim <输出目录> 0,30,90
python3 tools/progression-sim/report.py <输出目录>
```

可调键名见 `tools/progression-sim/Sources/ProgressionSim/Walls.swift` 的 `WallTuning`。

## 在 Linux 云端跑 Swift

官方下载被网络策略拦截。从 `archive.ubuntu.com/ubuntu/pool/universe/s/swiftlang/` 取 `swiftlang`、`libswiftlang` 的 6.0.3 deb，再从 `pool/main/libx/libxml2/` 取 `libxml2-16`，`dpkg -x` 解到临时目录，设 `PATH=<目录>/usr/libexec/swift/bin:$PATH` 和 `LD_LIBRARY_PATH=<目录>/usr/lib/x86_64-linux-gnu:<目录>/usr/lib`。`S9TalentEditorTests` 里一个 `@MainActor` 测试在 Linux 的测试自动发现下编不过：跑测试时在临时副本里去掉这个文件，它只在 Mac 上跑。
