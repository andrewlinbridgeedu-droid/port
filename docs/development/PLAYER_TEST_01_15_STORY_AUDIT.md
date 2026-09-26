# 玩家测试 1–15 剧情审计（2026-09-14）

范围：只读核对正式章节桥接、玩家可达的测试入口、章节文案与奖励展示。未构建、未运行测试、未修改源码。

## 已核对通过/不应误报

- Q15 的内部战斗槽仍使用 `enemy_hollow_clockmaker`，但这是稳定接触 ID。`MPCChapterOneBattleIdentity.visualDescriptor` 在 `chapter01_q15_encounter` 为该槽追加 `@matriarch`，展示名改为“织幕女主”（`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneBattleIdentity.swift:22-35`）。
- 正式接入记录明确说明 Q15 保留两颗寄忆核心、仅展示槽位使用女主模型（`docs/development/SIGNATURE_ENEMIES_INTEGRATION_20260913.md:11-17`）。因此不能把 Q15 encounter 的旧内部 ID 认定为没有女主展示。
- Q15 普通关是否显示精英/首领标签，本次不作为缺陷：当前关卡类型默认普通清剿（`mistport-ios/Mistport/ChapterModels.swift:119-128,170-173`），而“织幕女主”是展示槽位身份。

## 阻断

### Q15 之后缺少 1–15 测试版收束

正式桥接在 Q15 胜利后只投递 `q15Aftermath`，没有独立的测试版结尾：`finishCompletedEncounter` 对 5–20 关统一选择 aftermath（`mistport-ios/Mistport/ChapterOneTestView.swift:6004-6024`）；只有 `encounter_midnight_02` 才进入 `ChapterOneConclusionView`（同文件 `6004-6007`）。Q15 aftermath 文案随后指向镜潮宅邸/第16关（`mistport-ios/Mistport/ChapterOneOnboarding.swift:134-135`）。

玩家完成Q15后因此会读到“前往镜潮宅邸”，再回城继续流程，没有“1–15测试版完成”确认、收束画面或停留点。

## 一般缺口

### 正式 Q5 胜利状态仍显示旧纸人文案

Q5 正式 encounter 是翠焰亡灵（`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneContent.swift:552`），铃的正式交付文案也已改为延后蓄力/返场增伤（`mistport-ios/Mistport/ChapterOneOnboarding.swift:146-155`）。但战斗回合完成后，只要 Q5 胜利，仍设置 `actionMessage = "纸人代身 · 失名猎犬崩解"`（`mistport-ios/Mistport/ChapterOneTestView.swift:4098-4105`）。这是正式桥接可达的玩家可见错名与旧机制文案：敌人既不是猎犬，也不应出现纸人。

### 独立 Q5 原型入口仍可实际触发纸人介入

`ChapterOneTestView` 通过 `--preview-chapter-one-encore-bell` 进入独立原型路径（`mistport-ios/Mistport/ChapterOneTestView.swift:100-127`）；战斗结束回合会依据 `paperDoubleTutorialPhase` 设置 `shouldPresentQ5MaraIntervention`（同文件 `3914-3929`），随后显示 `q5PaperDoubleIntervention`（`1208-1225`），其中明确写“纸人代身”。核心仍保留旧纸人致命承伤状态（`mistport-ios/MistportCombatCore/Sources/MistportCombatCore/ChapterOneEncounterRuntime.swift:1980-2003`）。

该路径不是普通新档地图流程，但它是当前提供给真机/测试玩家的独立 Q5 入口；若测试包保留此启动参数或入口，玩家会看到已否定的纸人设计。铃原型的清理函数虽会移除旧纸人装备并关闭纸人状态（`ChapterOneEncounterRuntime.swift:605-623`），不能覆盖正式胜利提示中的旧文字。

## 测试入口边界

DEBUG 主界面仍提供“测试”按钮（`mistport-ios/Mistport/ContentView.swift:368-386`），面板列出并可立即跳转完整第1–20关（`ContentView.swift:472-510`）。独立章节预览还将全部 catalog encounter 视为可进入（`ChapterOneTestView.swift:380-414`），并显示“测试关卡已全部开放”（同文件 `245`）。如果该 DEBUG 包就是玩家测试版本，应限制到当前交付范围1–15，或明确将入口标为内部开发入口。

## 升级技能观察

Q5/Q10/Q15 的里程碑阈值确实由章节进度控制（`mistport-ios/Mistport/ChapterModels.swift:63-70`；`mistport-ios/Mistport/GameStore.swift:823-836`）。但 `debugJumpToOldClockMission` 会将技能等级全部重置为1并清空 `skillVariants`（`mistport-ios/Mistport/GameStore.swift:1497-1504`），所以跳关入口本身不能立即代表“带升级技能”的玩家测试存档；需另行从主城升级页配置后再测。

## 2026-09-14 局部修复冻结

- 已备份原文件至 `backups/player-test-01-15-20260914/`。
- 正式 Q5 战斗中途提示已改为“不肯落幕的铃 · 翠焰亡灵返场”，胜利收据标题改为“翠焰亡灵退场”（`mistport-ios/Mistport/ChapterOneTestView.swift:4098-4105,5990-5992`）。未改铃原型玩法、伤害、时序或全局假面规则。
- 卡牌无障碍标签已补充真实卡名与当前编排序号；未编排卡牌明确读作“未编排”（`mistport-ios/Mistport/ChapterOneTestView.swift:2983-2987`）。
- Q15 战后最后一页增加“本次开放的调查已完成，可返回主城整备，或重访已完成的调查。”，保留原有线索（`mistport-ios/Mistport/ChapterOneOnboarding.swift:134-135`）。
- 本轮未构建、未运行测试；需主 agent 后续做真机/连续通关验证。
