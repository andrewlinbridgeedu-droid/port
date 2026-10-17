# 失名猎犬 Shadowfang 接入游戏（2026-10-16）

用户 10-16 认可 v51 毛发审阅片（"已经很好了"），并同意节奏方案（"同意，按这个接进游戏"）。分支 `claude/shadowfang-fur-20261016`，起点是 main 之后的 `ea8c085`。10-17 用户说"可以"后快进合入 main（`ee181e9`），并装机 **172.2**（见 `HANDOFF_20261015.md` §14）。

## 规则时刻不变，只改表现

第 3 关猎犬每 20 秒一轮：第 2 秒、第 3.4 秒两口冥火（每口 90% 血，正好落在一次假面 4 秒保护里），之后第 6、9、12、15、18 秒各扑咬一次。每次出手后 1.1 秒命中。这些都没动。

- **喷火**：两口合成一次长喷火。
  - 第一口一来，就按原速播放完整的张嘴喷火动作（4 秒片段，张嘴约 3.4 秒）。
  - 第二口不重播动作，也不再出嘴部聚光，只续一股火。两股真火仍各在出手后 1.1 秒命中。
  - 中间另补两三股不带命中的冥火，交替扫向主角两侧，所以整段约 3 秒都在喷。
- **扑咬（腾空扑击，用户 10-16 看了第一版说"现在是整个狗拖地过来咬，不是扑过来"后重做）**：
  - 新动作是 Shadowfang 的 `Pounce` 片段（`animate-v52.py`，2 秒）。
    - 伏低：前身压低，头放低盯着目标，后腿收紧。
    - 蓄力后后腿蹬地：后爪到 50% 才离地。
    - 腾空：前爪向前上方伸，后腿向后拉直，耳贴后，尾巴拖在后面。
    - 68% 时前爪下抓、咬合，然后着地缓冲、收势。
  - App 知道第 3 关排好的出手时刻，提前 0.8 秒发 `hound-prepare:hell-hound-primary:bite`，Unity 开始伏低。
  - 出手后 0.35 秒内保持蓄力，0.4 秒离地。之后 0.7 秒的弧线，最高约 0.42 个身高，飞完到主角的 65% 距离。
  - 1.1 秒落爪，命中时刻不变。着地停 0.3 秒，再用 0.5 秒往后跳回原位。
  - 没收到准备信号时（其他关），出手后快速伏低，腾空和落爪时刻相同。
  - 第一版用的是原地前扑的 `Light`，后脚一直撑地，游戏又沿低弧线把整只狗平移过去，所以看起来像在拖地。
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
- **审阅片**：
  - `/Volumes/andrew's SSD/Mistport-build-cache/shadowfang-20261016/shadowfang-ingame-review.mp4`：模拟器实打与第一版扑咬。
  - `shadowfang-leap-review.mp4`：腾空扑击。录制器加了可选的 `side` 固定侧面镜头（`WholeSpellRound2Review20260922`），录 SF2S、SF3S。
- **腾空扑击之后重跑**（`rec4`，`rec6` 是侧面镜头）：录制 38 项、安全检查 143 项全部通过。模拟器还没装这一版。
- **真机**：没有。三角形约 8.5 万（身体 6 万、毛片 2.45 万），没测手机帧率。

## 还没做

- 第 4 关、塔 1 层、B01 上的 Shadowfang 只跑了录制器，没在模拟器看过。
- 手机帧率。如果吃紧，先减毛片数量（尾巴和过渡毛流）。
