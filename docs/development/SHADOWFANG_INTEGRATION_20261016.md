# 失名猎犬 Shadowfang 接入游戏（2026-10-16）

用户 10-16 认可 v51 毛发审阅片（"已经很好了"），并同意节奏方案（"同意，按这个接进游戏"）。分支 `claude/shadowfang-fur-20261016`，起点是 main 之后的 `ea8c085`。**还没合进 main，也没装机。**

## 规则时刻不变，只改表现

第 3 关猎犬每 20 秒一轮：第 2 秒、第 3.4 秒两口冥火（每口 90% 血，正好落在一次假面 4 秒保护里），之后第 6、9、12、15、18 秒各扑咬一次。每次出手后 1.1 秒命中。这些都没动。

- **喷火**：两口合成一次长喷火。
  - 第一口一来，就按原速播放完整的张嘴喷火动作（4 秒片段，张嘴约 3.4 秒）。
  - 第二口不重播动作，也不再出嘴部聚光，只续一股火。两股真火仍各在出手后 1.1 秒命中。
  - 中间另补两三股不带命中的冥火，交替扫向主角两侧，所以整段约 3 秒都在喷。
- **扑咬**：
  - App 知道第 3 关排好的出手时刻，提前 0.8 秒发 `hound-prepare:hell-hound-primary:bite`。Unity 收到后开始低蹲蓄力。
  - 出手后先弓身，最后 0.55 秒跃向主角（距离的 65%），1.1 秒落爪，然后边收势边回位。
  - 没收到准备信号时（其他关），出手后快速蹲下，落爪时刻同样是 1.1 秒。
- **喷火的准备**：提前 0.5 秒发 `hound-prepare:…:memory_breath`，抬头张嘴提前开始。

## 改动

| 文件 | 内容 |
|---|---|
| `Resources/CombatTempo/Shadowfang/` | v51 模型（875 张毛片、头顶、尾巴，毛色随身体）、身体与毛片材质、`Mistport/Shadowfang/{Surface,FurCards}` 与隐藏的 `FurSoft` 着色器、`Shadowfang.overrideController`（`Hound.controller` 的 10 个状态换成 Shadowfang 动作） |
| `Editor/ShadowfangSetup20261016.cs` | 可重复的导入：模型可读、Mikk 切线、不生成光照 UV（uv2 存毛片相位和长度）、动作循环与锁根、贴图设置、材质、动画覆盖 |
| `Scripts/ShadowfangHound20261016.cs` | 给毛片着色器喂风：常驻微风、约 8.5 秒一次阵风（固定相位，不消耗随机数）、胸骨速度经阻尼弹簧形成惯性甩动。另外提供嘴部位置 `Mouth` |
| `CombatTempoPresentation.cs` | "Hound" 身体换成 Shadowfang（自带材质，不复制旧配件），新增 `BodyOf` |
| `CombatTempoAnimatedBody.cs` | Shadowfang 不加旧的四脚固定（新动作自己落脚）；新增 `PlayTimed`，把动作片段的指定进度对到指定秒数 |
| `BattlePrototype.cs` | 喷火出口跟随 Shadowfang 的嘴；长喷火；分段扑咬；`PrepareHound`；扑咬在猎犬离场或战斗停止时不再迟报命中（旧扑咬也补上，以前没有测扑咬的安全行） |
| `UnityBattleBridge.cs` | `hound-prepare:` 指令 |
| `ChapterOneTestView.swift` | 第 3 关在出手前 0.8 / 0.5 秒发 `hound-prepare`（只是表现；快进跳过时不发） |

第 4 关、教会塔 1 层、通缉 B01 用的也是同一个"Hound"身体，所以都会换成 Shadowfang。第 4 关的节奏（`q4-hound:*`）没改，仍是原来的压缩动作。

## 验证

- **App 编译**：0 错误。
- **编辑器录制**（自建行 SF1–SF4，加原有 M05、M06、M07，指令和 App 发的一样）：
  - 录制 30 项、安全检查 125 项全部通过，两次源码 SHA 一致。
  - SF1 两次命中，第 4 关 M07 两次命中，其余各一次。
  - 安全检查第一次在 SF2 "命中前死亡不迟报"失败，原因是扑咬报命中前没检查猎犬还在不在。修复后通过。
  - 结果在 `/Volumes/andrew's SSD/Mistport-build-cache/shadowfang-20261016/rec3/`。
- **模拟器**：
  - 172.1 用独立的 bundle `local.mistport.shadowfang-review`，导出新鲜度检查通过。
  - 以 `--preview-chapter-one-mission=3`、独立档实打第 3 关：长喷火正常，第一口打 900、第二口打剩余 100，火连续约 3 秒。
  - 主角没用假面，被这对冥火打死，所以 App 里没轮到扑咬。
  - 点"开始战斗"后约 10 秒才开打，是之前就有的问题。
  - 机构版 `local.mistport.institutions` 的 16 份 Preferences 前后逐字节一致。
  - 这个 172.1 不含扑咬的迟报修复（修复在导出之后）。
- **审阅片**：`/Volumes/andrew's SSD/Mistport-build-cache/shadowfang-20261016/shadowfang-ingame-review.mp4`（模拟器实打、编辑器扑咬与近景）。
- **真机**：没有。三角形约 8.5 万（身体 6 万、毛片 2.45 万），没测手机帧率。

## 还没做

- 装机，以及合入 main：都要先问用户。
- 第 4 关、塔 1 层、B01 上的 Shadowfang 只跑了录制器，没在模拟器看过。
- 手机帧率。如果吃紧，先减毛片数量（尾巴和过渡毛流）。
