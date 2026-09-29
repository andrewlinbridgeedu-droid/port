# 交接：成长硬墙、百工坊美术与工坊走查 · 2026-09-28 17:55

接手前先读 [HANDOFF_M0_20260928.md](HANDOFF_M0_20260928.md)（第二章桥接、事件预览、本地检修单）和本页。分支 `claude/world-economy-m0`，已推送到 origin。

## 协作规矩（重要）

- 另一个会话“项目理解”正在改主页城市场景（乌云、天气、`CityLivingScene.swift` 等）。两边共用工作区，也共用 Unity 的 IL2CPP 中间目录：**xcodebuild 或装机前，先用 SendMessage 通知它，结束后再发消息**，不能两边同时编译。
- 编号：它用 170 及以上（记录在 `output/build<N>-city-device-<日期>/`），我们用 170 以下。
- 本机磁盘紧张：DerivedData 用 `/Volumes/andrew's SSD/Mistport-build-cache/bridge-dd`，签名包归档到 `/Volumes/andrew's SSD/Mistport-archives/releases/BuildNNN`。`artifacts/releases/` 里 14 个旧包已移到 SSD，原位置是链接，不要删。
- 装机惯例：先拷 Preferences 备份，装完逐文件比对；启动时加 `-MistportCityMute YES`。给用户演示用独立测试存档：工坊 `--workshop-device-walk --preview-city`，第二章 `--chapter2-bridge-walk --preview-black-salt-shore`。从桌面图标打开的是用户自己的存档。

## 进行中

- **Build 159**（百工坊文字精简）：17:50 在后台编译，编完会自动装机，并用工坊测试存档启动。接手后先看 `output/build159-device-20260928/install.json`、`launch-walk.json`；装好后告诉“项目理解”会话“159 已结束”（它在等这条消息），再让用户看百工坊页。

## 今天完成的

| 事项 | 状态与证据 |
|---|---|
| 工坊入口 | 挂到“工业委员会”名牌，另一个会话加了底栏“百工坊”；底栏图标缩到 84%（`SceneViews.swift` 的 `artScale`） |
| 教会名牌 | 对准钟楼中轴 (0.509, 0.311)，用户已认可 |
| 序列 8 最小仪式 | 只给资格，战斗仍按序列 9；手机检查 12/12；见 [M0_BATCH1_20260928.md](M0_BATCH1_20260928.md) |
| **工坊真机走查（第一批次第 1 项）** | 用户在 Build 158 上手走完：学图纸、两次塔 F1、做两批、交货、安装。存档 860 铜 = 860 + 8 − 26 + 18，绑带 4，熟练 2，订单已安装；重启后完全一致。**已通过** |
| 串行成长模拟器 | `tools/progression-sim`；基线结论：高、中熟练只打主线就能通关，三线互补不存在。见 [progression-sim-20260928](progression-sim-20260928/README.md) |
| 硬墙与通缉遗落物设计 | 用户已批准：6 墙 Q8/12/18/22/26/30；另开通缉栏；第一批只做 B01/B04/B10；旧存档的通缉装备换成遗落物。见 [设计稿](../../mistport-ios/docs/game-design/chapter-one-30/PROGRESSION_WALLS_AND_BOUNTY_RELICS_20260928.md) |
| 硬墙第一批：规则部分 | `BountyRelics.swift`：遗落物目录，以及墙关数值集中表 `MPCProgressionWalls`（**目前全是旧值，墙还没生效**）。战斗挂钩：缺齿剑破防、倒签笔校验算两次并封顶、寿账签去狂暴并每循环回血。账本 `retireBountyGear()`。规则库 465 个测试全过 |
| 美术 | Codex 交付 15 张，用户已认可；`PlateButton`（在 `LocalWorkshopView.swift`）替换了百工坊、角色页仪式、码头、转运站、检修单、事件预览、公共战的按钮；百工坊三张步骤插图；韧皮、绑带、组具图标，两派徽记。Build 158 手机渲染检查 17/17 |
| 百工坊文字 | 按用户意见删去给开发看的说明，改成玩家短句（进 159） |
| 其他 | 第一章大汽船设计（外部接收方的船）；“每人最多一个主专业”已写进工艺文档和规划书；磁盘从 6 GB 腾到 43 GB；`AGENTS.md` 写明 SSD 链接 |

## 接下来要做（按优先级）

1. **确认 159 装机**，让用户看精简后的百工坊。第二章那几页（转运站、检修单、事件预览）也有同样的“开发说明”文字，用户多半也要精简。
2. **硬墙第一批剩余：**
   - `GameStore` 加通缉栏：拥有的遗落物、当前装备哪一件，写进所有战斗的 `loadout.bountyRelicID`；角色页加选择。
   - 通缉结案改发遗落物，不再发装备（结案结算处）。
   - 旧存档迁移：对已结案的案子调用 `retireBountyGear()`，按案号补发遗落物，写迁移回执，只做一次。
   - 日刊保底：卡在 Q12、Q22、Q30 且没接到对应案子时，当天必定刊登。
   - 墙关失败时给提示。
   - 模拟器加遗落物和通缉栏，然后调 `MPCProgressionWalls` 和 Q8、Q18、Q26 的敌人数值，直到满足设计稿第 6 节的验收标准。
   - 装机验收。
3. **公共战手打**：第二章测试存档已到转运站、见过两人，检修单还没开始。用户需要先打塔 F1 拿韧皮。
4. 第一批次第 4 项后半（两派核心人物战、死亡与继任），第 5 项（服务端账户与可信战斗结算小样）。
5. 第二批：其余 7 件通缉遗落物的效果。大汽船接进主页的工作交给主页会话。

## 未提交的东西

本次推送包含全部代码、文档、工具，以及百工坊这批 15 个 imageset（Git LFS）。**没有包含** `ArtSource/` 原图、主页会话还在做的新图集和音频、`output/` 证据。主页会话的素材由它自己提交。
