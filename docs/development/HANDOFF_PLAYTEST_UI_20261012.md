# 交接：真机试玩、战斗 UI 与主线日限入口 · 2026-10-12

接在 [法术与真机交接](HANDOFF_SPELL_VFX_20261010.md) 之后。本文区分源码已修、构建通过、设备观察和用户认可；不要把其中一项当成另一项。用户最新要求：**做完后 commit、push，并写 handoff**，由父代理完成最终设备核验与提交。

## 1. 当前状态与路径

- 基线：`main` 的 `9cab331638867ea8b703df1fed4f776b18df5352`；此前用户提到的 `4b36fa5` 已作废。
- 工作树：`/Volumes/andrew's SSD/Mistport-worktrees/main-9cab331-codex-01a12f14`；提交分支：`codex/playtest-ui-20261012`；commit：**本交接所在提交，详 `git log`**。
- **169.76 曾安装**到 iPhone 13，已完成下文列出的有限设备观察。不是所有改动都已验收。
- **169.77 已安装并启动成功**：`apps-after-install.json` 确认版本，`install-preferences-verification.json` 确认安装前后 264 个 Preferences 文件完全相同。已在隔离演练中观察 Q3 喷火、观看／跳过失败对照、塔 14 朝向／小怪近身／独立卡图／拖序／跳过胜利；具体范围见第 4 节。预览已停止，运行后比较确认真实玩家与 blind audit suite 均逐字节不变；正常审计启动 `launch-audit-resume.json` 已成功。
- 盲玩代理目前暂停，父代理仍持有 UI，准备交回。隔离试玩进度为塔 14 已胜利、主线 Q12 待重试；恢复后城市截图 `device-evidence/audit-resumed-city.png` 显示 620 铜、主线「强制校正」／通缉「第七号空壳」。不要自动继续消费道具或推动真实玩家进度。

| 内容 | 路径 |
|---|---|
| 169.76 归档 | `/Volumes/andrew's SSD/Mistport-archives/releases/Mistport-169.76-9cab331-ui-20261012-codex-01a12f14` |
| 169.77 归档 | `/Volumes/andrew's SSD/Mistport-archives/releases/Mistport-169.77-9cab331-facing-cards-20261012-codex-01a12f14` |
| 169.77 App | 上述 169.77 目录下 `Derived/Build/Products/Debug-iphoneos/Mistport.app` |
| 安装前源码复核及完整文件清单 | 上述 169.77 目录下 `source-review.txt`；其中当时的“未验证”状态由本文后续设备记录更新 |
| 补丁、哈希、变更记录 | 上述 169.77 目录下 `source-changes.patch`、`source-hashes.json`、`change-manifest.json` |
| 盲玩报告 | `/Volumes/andrew's SSD/Mistport-archives/releases/Mistport-169.75-9cab331-20261012-codex-01a12f14/blind-playtest-20261012/chapter-one-continuation/reports/report.html` |
| 盲玩原始输入与进度 | 上述 `reports` 目录下 `actions.jsonl`、`checkpoint.json`；截图在相邻 `evidence/` |

**交付结果与尚待补全项**：

- 最终设备构建号／安装结果：**169.77，成功**。
- 静音隔离启动：`-MistportCityMute YES --developer-tools --player-test-audit`，成功；Q3 自检首启另加 `--verify-daily-pacing --preview-chapter-one-q3`。
- 安装前后 Preferences：**264 文件完全相同**。运行后由 264 增至 266 文件，真实玩家与 blind audit suite 逐字节不变；仅两份随机自检 suite 新增和隔离 housing shell 修改，详第 2 节。
- 真机观察见第 4 节 `169.77` 表，截图均在该版本归档 `device-evidence/`；小怪接近主角已有 18 帧连续截图，运行后比较见 `preview-preferences-verification.json`。
- 分支：`codex/playtest-ui-20261012`；commit：**本交接所在提交，详 `git log`**；远程分支：[codex/playtest-ui-20261012](https://github.com/andrewlinbridgeedu-droid/port/tree/codex/playtest-ui-20261012)。提交与推送由本会话收尾执行并核对远程 SHA。

## 2. 真实存档与测试边界

**最新覆盖前述旧进度状态（15:10）**：用户在正常路线测试后明确说“那你重置我的吧”。已先完整备份，再仅将真实 `mistport.player-test-01-15.plist` 重置为开局（保留开发工具开关）。写入后读回一致，266 个 Preferences 中仅该文件改变，其余 265 文件逐字节相同。原进度可从 169.77 归档 `user-reset-to-start-1510/preferences-before/` 恢复，但未经用户要求不要恢复。证据：`reset-result.json`、`reset-file-comparison.json`；随后 `--player-test -MistportCityMute YES --developer-tools` 静音启动成功，见 `launch-fresh-real.json`。启动后读回确认：已完成关卡为空、第 1 天、168 铜，见 `fresh-launch-state.json`。当前手机属于用户真实开局，不能交给盲玩代理直接操作。


真实玩家 suite 是 `mistport.player-test-01-15`，不是盲玩 audit suite。本会话早期用户曾明确要求从最开始重置，那个操作已经结束；**本轮最新重置之前真实档 Q1–Q10 已完成**，不能拿早期 day 1 新档恢复手机。

169.77 应以本次安装前最新完整导出的 **264 个 Preferences 文件**为比较基准：

- `169.77` 归档内 `preferences-before-final-install/`。
- 对应 `preferences-before-final-hashes.json`、`preferences-before-final-copy.log`。
- 更早的 `preferences-before-install/`、169.75 初次安装备份和 `reset-to-start-0103/` 只保留作历史证据，**不能回写覆盖当前玩家进度**。

本次安装前后已逐文件比较，264 文件完全相同。启动／演练后再次比较，证据为 169.77 归档内 `preview-preferences-verification.json`：

- 文件数量 `264 → 266`；真实 `mistport.player-test-01-15.plist` 与 blind audit suite 均逐字节不变。
- 只新增本次 `--verify-daily-pacing` 生成的两份随机 daily-pacing suite 文件；两份 plist 已解析，内容均为空字典 `{}`。不能据此声称整个目录零变化。
- 唯一修改文件为 `mistport.housing-verification-shell.20260930.plist`，本次 `--verify-*` 启动使用该隔离 shell。
- **没有恢复或覆盖任何玩家档**。上述演练结果不写入真实或 blind audit 进度。

随后恢复正常审计启动成功，证据为同归档 `launch-audit-resume.json` 和 `device-evidence/audit-resumed-city.png`；未以旧备份覆盖存档。

后续正常游玩若出现日结、偏好初始化或玩家进度变化，应另行解释，不笼统声称“存档全程不变”。不要重复发首通铜币、功勋、遗落物或成长权益。不得因盲玩断点与真实玩家断点不同而把二者互相覆盖。

盲玩使用隔离档。为继续试玩，父代理曾只调整隔离档日程到第 28 天；这不是自然 30 天经济验证。用户在镜像使用中有过协助，设备锁屏／解锁与镜像恢复属于环境配合，不是游戏流程本身。所有真机运行按用户要求静音，音效与音乐没有验收。

## 3. 累计修复内容

以下是相对 `9cab331` 的累计修改；其中前一批已进入 169.76，不能全部称为 169.77 新增。详细差异和 47 个已跟踪修改／11 个新增文件的当时清单见归档 `source-review.txt`；以最终提交差异为准。

### 3.1 169.76 已带入的 UI、住房、状态和塔调整

- `ChapterOneOnboarding.swift`：引导人物抬高并按可用高度缩放，为姓名牌保留底部空间。
- `LocalWorkshopView.swift`：四个制作分类改为明确可点的独立标签，选中显示金边／金字，调整标题和点击区域。
- `HousingViews.swift`、`WisteriaMap/housing-hotspots.json` 及三个 `Housing*20261012.imageset`：普通住房内外图按房型调整；码头铺位使用新廉价木屋内外图和热点；签约按钮固定到底部安全区；码头房间增加偶发老鼠动画和声音，声音服从静音／音量，动画考虑减弱动态效果。
- `ChapterOneEncounterRuntime.swift`、`ChapterOneTestView.swift`：新增只读战斗状态投影，在对应单位血条显示当前增益／减益及层数，调整倍速按钮。
- `ChurchTower.swift`：把原有小怪阵容分配到多波，补前十层后续波独立 ID；不复制原阵容的血量、攻击和首通奖励预算。`ChurchTowerHundredTests.swift` 和新增 `CombatStatusPresentationTests.swift` 覆盖相关契约。
- `TowerMinionApproach20261003.cs`：小怪由后场向主角前方浅扇形近战位置接近。169.77 进一步修正导入模型的朝向，见下文。

169.76 的“跳过画面”仅隐藏持续运行的战斗，**不是即时结算**；169.77 已改为下面的实现。不要用 169.76 的观察证明 169.77 快结算正确。

### 3.2 169.77 战斗交互与卡图

- `ChapterOneTestView.swift`、`ContinuousSkillScheduler.swift`：改为本地直接拖动卡牌并显示随手势移动的预览；被移动或挤动位置的卡开始完整冷却，未换位／取消拖动保持原期限；已在飞行中的卡继续原结算。
- `ChapterOneTestView.swift`、`UnityBattleHost.swift`、新增 `BattleContactTiming.swift`：跳过从当前规则状态继续，调用同一 `advanceContinuousCombat`，以 0.05 秒步长批量推进。观看／跳过使用相同规则命中期限，Unity 回调作为表现回执；抑制演出、过程飘字与触觉，不直接指定胜负。72,000 步仍无结果则返回战场。
- 静态复核：胜利共用 `continuousVictoryReported`；败北由 `session.outcome.onChange` 回调，快结算不重复回调。旧 Q5 `awaitingMara` 目前不可达，不能把残留 preview 分支当作正常 Q5 故障。
- `CharacterProfileView.swift`、`ChapterOneTestView.swift`、`IconSkillFabricatedEvidence20261012.imageset`：伪证烙印使用独立红蜡烙印图，不再与错步穿行共用卡面。
- `TowerMinionApproach20261003.cs`：行走与到达时实时面向主角，考虑模型导入已有 180 度校正，使用实际面向的 root -Z。
- `HomeStreetScene.swift`：委托截止文案显示实际 `offer.lastDay`，不再一律写“今天没做完会作废”。只改展示。

### 3.3 Q3 猎犬：受击路由修复与独立喷火观察

`CombatTempoPresentation.cs` 的 `EnemyHit` 原来仅接受 `Enabled`。Q3 使用 `HoundBodyOnly`，因此新身体受击层未收到命中；现允许 `Enabled || HoundBodyOnly`，调用替换身体的 `ConfirmedHit`。

**受击修复与喷火观察是两件事，不能声称受击改动修复了喷火根因。** 用户明确说主线 Q3 猎犬似乎不放大招；源码跟踪确认 `memory_breath` 会发送 `enemy:hell-hound-primary`，进入喷吐流程，没有证实必然阻断。169.77 独立 Q3 真机演练随后已拍到口部喷火，见 `device-evidence/q3-active-00.png` 等；这是该版本、该次演练的可见证据，不等于所有场景／每次触发均已验收。继续排查时可用：

- `hell-hound-charge` → `hell-hound-breath` → `hell-hound-impact`。
- 准备、聚气、飞行是 `0.08 + 0.24 + 0.78 = 1.10` 秒。
- `TryEarlyHoundMuzzle` 可能缓存旧骨骼口部，属于起点错位嫌疑，尚无运行证据证明是完全缺失的原因。
- 新喷吐层启用时旧 Effekseer 不绘制；需要核对实际材质／资源加载日志，不能仅凭源码资源存在宣布成功。

用户随后反馈正式路径仍没有用到假面。独立演练喷火可见不代表正式路线已复现：正式开始会给空卡序自动补入可用卡，本次对照演练手动保持空卡。Q3 源码明确不作为硬门槛，喷火固定 180、猎犬 620 HP、新档主角 1000 HP；没有“必须使用假面”的过关条件，现有测试也不要求不用假面必败。未找到正式入口专有的喷火阻断。用户已要求重置真实进度亲自从头验证；**正常装配下的假面教学有效性仍待观察，不能宣布已解决**。

### 3.4 “明天／后天开放”仍可点击主线

修改 `GameStore.swift`、`SceneViews.swift`、`ContentView.swift`。

根因是主城显示下一关日限文案，但 `enterDistrictMap` 在该关未开放时回退到已完成旧关。因此点击“明天开放”仍会打开旧主线，并非 `MPCDailyPacing` 把未来关放行。

现在有未完成下一关时，`storyEntryMission` 必须确认该关可用；否则主线按钮禁用、入口无操作，不再回退。全章完成后仍可回访旧关。入口重新判断目标，最终 `beginMission` 仍按 `missionIsAvailable`／`MPCDailyPacing` 再检查。每日规则、存档和已赢发奖未改。

现有 `verifyDailyPacing` 随机隔离 suite 新增第一天 Q4 拦截、次日进入 Q4、全章完成可回访断言；**已随 169.77 真机首启运行通过**。`device-q3-console.log` 第 6 行记录 `DAILY_PACING_VERIFY_PASS`，其中明确包含 `Q4 tomorrow blocks entry`、`next day enters Q4`、`completed chapter replay`。

## 4. 真机试玩记录与归因

报告 HTML 开头仍保留较早阶段摘要，应读其后追加的 09:56、11:29 和 169.76 小节，并对照 `actions.jsonl`、`checkpoint.json`。不能只摘最前面的“Q12–Q30 未覆盖”当最终状态。

| 项目 | 已观察结果与限制 |
|---|---|
| 主线 Q11 | 亲见首通；第一章未通关。重启后重现同一奖励界面不能当作第二次发奖。 |
| 主线 Q12 | 一次已记录失败；失败提示指向通缉 B01“第七号空壳”。不能称 Q12 已通过。 |
| B01 调查 | 已取得诊所、诺恩、巡逻值房三处证词；尚未战斗／结案，未取得七号缺齿剑。铁匠维拉入口仍未找到。 |
| B01 导航问题 | 卷宗铁匠目标定位工业委员会，但打开百工坊；旧街完整列表与工坊检修架页尾未发现对应问话。记为玩家可见导航／发现性阻碍，不断言节点绝对不存在。 |
| 深井塔 | 169.76 中亲见 11–14 层获胜，当前停 14 层胜利结算。11、12 层见四波 `1/1/1/2`，13 层 `1/1/1/3`，14 层见四波；不是 100 层通关。 |
| 169.76 工坊／住房 | 已观察四分类金色选中样式、码头木屋内外、租约签约底栏在滚动前后固定。只查看，未签约／换房；不把代理主观喜欢当用户认可。 |
| 169.76 战斗 UI | 倍速切换可见；血条旁蓝盾状态可见，层数未核验；拖序尝试未成功，冷却重置未验证；塔 14 红胖怪背向可见。 |
| 169.76 跳过画面 | 按钮及自动战斗说明页可见；没有即时结算／胜率对照证据，不能借此验收 169.77。 |

用户明确承认 **Q4、Q6 有协助操作**；原始记录亦将 Q4–Q8 和塔部分场次标为协助期。对未逐次归因的输入保留限定，不称全部独立首通，也不把非盲玩代理操作造成的跳转当游戏缺陷。塔 1–3、5 及一次塔 2 重打有完整本代理操作记录；更细归因以 `actions.jsonl` 为准。

塔 14 的“先长按 800 ms 再拖动”来自父代理提示，不是盲测自行发现。盲玩代理未读源码／攻略；后续源码排查由其他代理执行，不能把技术排查知识混入盲玩发现。

镜像曾出现 `noWindowsAvailable`、白窄帧、`-3811/-3812`、iPhone 使用中等环境中断，不能据此宣布游戏崩溃或把工具往返耗时当正常玩家反应时间。静音运行，音乐／声音未测。

### 169.77 安装后的独立设备核验

以下是父代理的独立演练验证，不是继续推动盲玩 audit 剧情，也不发正式通关奖励。证据位于 169.77 归档的 `device-evidence/`。

| 项目 | 已观察结果 | 证据与边界 |
|---|---|---|
| 引导布局 | 玛拉人物与姓名牌分离 | `001-mara-name-spacing.png` |
| Q3 喷火 | 口部喷火可见 | `q3-active-00.png` 等；不将受击修复当喷火根因修复 |
| Q3 观看失败 | 原地不装卡、仅普攻观看，失败结算伤害 420 | `q3-watched-defeat.png` |
| Q3 跳过失败对照 | 同配置重试，点击跳过后约 1.24 秒到失败结算，伤害同为 420 | `q3-skipped-defeat.png`；时间包含截图工具耗时，不是精准游戏耗时。只证明这一配置的观看／跳过失败结果一致，不推断全部胜率 |
| 塔 14 朝向／卡图 | 红怪正面可见；伪证为独立红蜡卡图 | `tower14-facing-and-distinct-cards.png` |
| 塔 14 小怪近身 | 不装备技能的独立预览中，红小怪从远处走到主角左前方、面朝主角；第二波再次推进，保持四波计数 | 18 帧连续截图 `minion-approach-00.png` 至 `minion-approach-17.png`；00 为开场远处，08 已近身，17 为第二波推进 |
| 战前拖序 | 拖牌后次序改变 | `tower14-prebattle-reordered.png` |
| 战中拖序 | 拖牌后次序改变，受影响牌暗下并重新冷却 | `tower14-battle-reordered.png`；精确 0.05 秒规则行为仍以规则测试为证 |
| 多波跳过胜利 | 跳过剩余多波后，下一次捕获已是演练完成 | `tower14-skipped-victory.png`；不发正式奖励，没有把截图间隔当精确结算时长 |

这些设备观察更新了此前“尚未验证”的对应项目，但尚未覆盖全部技能组合、队友倒下／救起、取消恢复、72,000 步返回等边界，也未新增用户视觉认可。

## 5. 构建与检查

手机版本以 `xcrun devicectl device info apps` 实时查询为准，再递增构建号；本轮依次由 169.75 到 169.76、169.77。归档带本会话后缀，DerivedData、日志和新产物均留在外置 SSD。

标准构建顺序仍是 **Unity 导出 → 导出新鲜度检查 → 宿主构建**：

```sh
cd "/Volumes/andrew's SSD/Mistport-worktrees/main-9cab331-codex-01a12f14"
MISTPORT_BUILD_OUT="/Volumes/andrew's SSD/Mistport-archives/releases/Mistport-169.77-9cab331-facing-cards-20261012-codex-01a12f14" \
  sh scripts/build_hero_v4.sh device 169.77
```

`pipeline-q3-final.log` 记录 14:40 Unity 导出、14:43 新鲜度通过并完成宿主构建。主线入口修改后又做最后宿主编译，日志 `build-final-daily-entry.log`，最终 169.77 已安装并启动。仅 Swift 修改可在已确认 Unity 新鲜后补编译宿主；不要跳过首次 Unity 导出或把旧 Unity 库装进新包。

| 检查 | 已有证据 |
|---|---|
| 169.76 构建、签名、资源 | `build-verification.json`；装机后的状态以更晚 `change-manifest.json` 和 `apps-after-install.json` 为准，早期 build-verification 中 `deviceInstalled:false` 是安装前快照 |
| 169.76 安装保护 | `install-preferences-verification.json`、前后 Preferences 目录；manifest 记录安装前后相同 |
| 169.77 安装／启动 | `apps-after-install.json` 确认 169.77；静音 audit 启动成功，Q3 首启自检见 `device-q3-console.log` |
| 169.77 安装保护 | `install-preferences-verification.json`：264 个文件完全相同 |
| 169.77 运行后保护 | `preview-preferences-verification.json`：264→266；真实玩家与 blind audit suite 逐字节不变，仅新增两份随机 daily-pacing suite、修改隔离 housing shell；没有恢复／覆盖玩家档 |
| 状态／塔契约 | 169.77 `rule-tests-explicit.log`，6 tests in 2 suites passed |
| 共享命中期限、批量结算 | `skip-rule-tests.log`，11 tests in 2 suites passed；包括从中途快照分别结算胜利／失败的参数用例 |
| 多波塔层机制回归 | `tower-hundred-contract-tests-final.log`：7 tests / 1 suite 通过。测试经真实清场／淡出进入含指定怪物的波次，再验证毒、治疗、强化、蓄力互斥和首通去重；修复旧测试“目标总在第一波”的假设，未改生产规则。未运行全量 100 层平衡遍历。 |
| 原有每日核心规则 | `daily-pacing-core-tests.log`，6 tests in 1 suite passed |
| 新入口 Swift 语法 | `xcrun swiftc -frontend -parse` 对 `GameStore.swift`、`SceneViews.swift`、`ContentView.swift` 通过；定向 `git diff --check` 通过 |
| 新入口 App 隔离断言 | 已在 169.77 真机首启通过；`device-q3-console.log:6` 的 `DAILY_PACING_VERIFY_PASS`。这与原有核心 6 测试是分别取得的证据 |

规则测试重跑可使用以下命令模板；scratch 目录也放 SSD，成功与否以当次日志为准：

```sh
swift test -j 4 --enable-swift-testing --package-path mistport-ios/MistportCombatCore \
  --scratch-path "/Volumes/andrew's SSD/Mistport-build-cache/playtest-20261012-rules" \
  --filter 'BattleContactTimingTests|CombatStatusPresentationTests'
swift test -j 4 --enable-swift-testing --package-path mistport-ios/MistportCombatCore \
  --scratch-path "/Volumes/andrew's SSD/Mistport-build-cache/playtest-20261012-rules" \
  --filter DailyPacingTests
```

安装启动命令摘要：先查实时 App 版本；停止游戏并完整导出最新 Preferences；安装产物；再次导出逐文件比较。本次以 `-MistportCityMute YES --developer-tools --player-test-audit` 静音隔离启动；Q3 自检首启额外使用 `--verify-daily-pacing --preview-chapter-one-q3`。运行后的数据变化另行比较解释，不能为了跑自检清理真实玩家 suite。

## 6. 尚待完成与提交边界

1. 安装前后与演练后 Preferences 比较均完成；之后按用户明确要求重置真实档到开局，不能再笼统写真实档全程未变。当前手机由用户亲自试玩；盲玩代理继续暂停，后续接管需先重新以 `--player-test-audit` 启动，不能动用户真实新档。
2. Q3 口部喷火已有真机截图；继续把新身体受击与喷吐并行动作、不同运行状态分开验收，不将一次独立演练推断为所有触发均正常。
3. 即时跳过已有 Q3 同配置失败伤害 420 对照及塔 14 多波演练胜利证据；剩余队友倒下／救起、取消恢复、极端长战等边界仍未覆盖。规则引擎批量测试不证明 App 全流程。
4. 新增 GameStore 入口隔离断言已在真机通过；若继续 UI 验收，应观察实际锁定按钮和日期变化，不再将自检列为“尚未运行”。
5. 独立伪证卡图、红怪正面、战前／战中拖序及可见重新冷却已有新版证据；小怪近身和第二波重复推进也已拍到。精确时间、其他种类／层数和用户手感认可不由这次塔 14 观察替代。169.76 的不成功拖动记录保持历史归属。
6. B01 铁匠目标可达性仍待后续调查；主线仅盲玩至 Q12 失败，Q28–Q30 队友、封牌、倒地提示和天使出场没有本轮盲玩验证。
7. 用户授权提交推送后，本次在 `codex/playtest-ui-20261012` 提交功能源码、测试、所需资源和本 handoff。不要提交 Unity 重导产生的 30 个 `AIHero/**/*.png.meta` 纯空字段尾空格变化，也不要提交签名 App、DerivedData、日志或真实 Preferences。不要动 SSD 符号链接和历史备份。
