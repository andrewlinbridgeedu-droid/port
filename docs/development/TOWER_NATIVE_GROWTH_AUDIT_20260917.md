# 封印塔实际成长可达性审计

2026-09-17。本报告为源码审计，不是手机连续通关记录。

| 候选塔段 | 对应主线完成 | 实有普通技能 | 槽位 | 累计天赋点/尘 |
|---|---:|---|---:|---:|
|1–10|7|错步穿行|2|0/0|
|11–30|10|错步、身份错置、虚构证据、镜像追击|4|4/30|
|31–50|13|上述＋荒诞谢幕、反客为主、无名舞台|4|4/30|
|51–70|16|七张中手动选择四张|4|8/60|
|71–100|20|七张中手动选择四张|4|14/60|

依据 ChapterOneEncounterRuntime.applyChapterMissionProgress、ChapterOneContent.missions、ChapterOneThirtyMissionContract.firstClear。无名舞台是终极技能；不要把谢幕后换位后台的 backstageChange 算成第八张已开放技能。其另有结局教学条件，不能在塔前段赠送。

天赋点不等于全部技能已点满，尘不等于全部卡已升级；模拟必须记录实际分配与花费。主线不发经验，不能用主线关数虚构等级成长。Q22/Q24额外8＋8天赋点，若模拟只完成Q20不可使用。

## 已修

GameStore.beginChurchTower 原先直接信任调用者传入技能数组，未检查永久持有、重复或槽位。现过滤未持有技能、假面卡、重复技能并按当前真实槽位截断，保持空编排只普攻规则。保存加载、正式塔战开始均使用本次实际持有成长。备份位于 backups/tower-native-audit-20260917/GameStore.swift。

## 原生验收接入要求

复用核心代理生产 MPCChurchTowerVerificationRunner，不重复造第二个战斗模型。纯报告运行应使用独立 UserDefaults suite（或完全不使用 GameStore），结果写 Documents/church-tower-100-verification.json。不可调用玩家 save、奖励迁移或增加玩家金币。必须记录每层outcome、HP、耗时、技能槽、遗物/消耗，出现失败立即可定位；规则全通不等于Unity视觉100层验收。

本次未构建或运行Xcode，按主代理要求由其统一集成；未声称手机全通。

## 原生入口已接（待统一构建）

`--verify-church-tower-100` 在 DEBUG 中后台逐层调用正式 `MPCChurchTowerVerificationRunner.run(number:)` 默认参数，不启动第二个玩家存档，不结算真实奖励。仅100层均胜利才打印 `CHURCH_TOWER_100_PASS`，失败层保留并继续收集报告。Documents/church-tower-100-verification.json 包含实际技能/天赋/遗物、每层血量/耗时、每波入场HP和编队、技能次数与预期首通收益。报告显式 visualAcceptance=false，防止把原生核心模拟冒充真实Unity演出连续通关。

既有 `--verify-church-tower` 隔离suite补充未解锁大招、假面、重复卡传入过滤，及空编排保留自检。

门槛说明：本批核心保留1–10立即可进入；runner取Q7成长是测试样本，不是正式第1层门槛。上表第1行应解读为样本所用主线进度。Q10/13/16/20后续段门槛以正式ChurchTower定义为准。
