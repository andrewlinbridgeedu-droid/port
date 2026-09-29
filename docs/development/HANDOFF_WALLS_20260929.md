# 交接：墙关调数 · 2026-09-29

仓库：`andrewlinbridgeedu-droid/port`（用户已定为以后的工作仓库）。分支 `claude/world-economy-m0-u62oho`，基于 `claude/world-economy-m0`（cee125a）。先读 [HANDOFF_PROGRESSION_UI_20260928.md](HANDOFF_PROGRESSION_UI_20260928.md) 和 [HANDOFF_M0_20260928.md](HANDOFF_M0_20260928.md)。

## 本次完成

- 用模拟器调了墙关：Q8、Q12、Q22、Q30 现在是硬墙；Q3 放宽。结果、验收表和没解决的问题见 [progression-sim-20260929](progression-sim-20260929/README.md)。
- 规则库 470 个测试全过（在云端 Linux 跑；`S9TalentEditorTests` 里一个 `@MainActor` 测试在 Linux 上编不过，只在 Mac 上跑）。旧平衡测试改为带上墙要求的塔装备和遗落物；新增 `mechanismWallsNeedTheirRelic`。
- 模拟器：遗落物、按墙换装、日刊保底、邮务买药重试、`walls`／`fight` 模式、`WALLS=` 调参、`TRACE=1`。

## 没验证

- **iOS App 没编译过**（cee125a 以后都没有）。本次只改了规则库和模拟器，App 侧没动；但 `MPCProgressionWalls` 的数值和文字变了，墙关失败提示、遗落物说明要在真机上看。
- 没有真机、没有真人试玩。机器人的熟练度只能相对比较。

## 下一步

1. **用户定方向：** Q18、Q26 怎么办（拉陡塔装备曲线／改成机制墙用 B09、B06／只留 W1）；验收第 3 条（只做通缉）要不要改。
2. 低熟练的通缉战败会输光商店遗落物，导致卡 Q8。考虑：通缉战败只扣铜不扣遗落物，或墙关前提示别带遗落物去通缉。
3. 交给 Codex（Mac）：拉取本分支，`xcodebuild`，装机，看 Q12 叠层、Q22 校验失败、Q30 狂暴的表现和失败提示。Unity 端这三个新机制还没有专门演出。
4. 其余 7 件遗落物；第二章核心人物战、死亡与继任；服务端账户与可信结算。

## 在 Linux 云端跑 Swift

官方下载被网络策略拦截。从 Ubuntu 仓库手动取 `swiftlang`、`libswiftlang` 6.0.3 和 `libxml2-16` 的 deb，`dpkg -x` 解到临时目录，设 `PATH`（`usr/libexec/swift/bin`）和 `LD_LIBRARY_PATH` 即可。
