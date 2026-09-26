# 第 6—8 关演出协议（2026-09-15）

本文件记录本批 Unity 演出代码，不代表规则验收或真机观感通过。原文件备份在 `backups/q678-redesign-20260915/unity`。

- 第 6 关：`wave-instances:clock-guard-primary@archivist` 安装现有档案守卫。`archive-state:guard` 显示分段蓝白防御结构；`archive-state:open` 显示金色暴露核心；`archive-state:clear` 清除。`enemy:clock-guard-primary:archive_slam` 使用档案守卫原有实体飞臂/机械法术，并沿用原真实命中回调。
- 第 7 关：`core-escort` 保留两个空壳守卫与后排寄忆核心，独立稳定身份。`enemy:clock-core-primary:repair_guard:<受疗守卫 ID>` 播放指向实际受疗者的修复光束，0.85 秒后仅报告一次 `enemy:clock-core-primary`，由原生结算修复。
- 第 8 关：`wave-instances:memory-leech-primary` 安装单独记忆蛭。`leech-charge:on` 收拢记忆线并逐渐胀大最多 7.5%；`leech-charge:restrained` 显示短暂紫色束缚并恢复体积；`leech-charge:off` 清除。`enemy:memory-leech-primary:name_devour` 沿用记忆蛭实际飞行命中回调。

所有数值伤害/治疗/阶段时序由 Swift 核心负责。新增演出不创建额外伤害或自动选敌，不加入机制文字或选敌标记。跨编队、退出战斗、死亡清除阶段演出，取消修复不发送回调，蛭体积恢复。

启动独立验证：`--verify-q678-redesign`，输出目录环境变量 `MISTPORT_Q678_CAPTURE`。验证覆盖单守卫/三敌含核心/单蛭的实际活动编队，三个行动各一次回调，以及退出时的阶段与未命中修复清理，输出 PNG。

目前状态：代码完成，等待主 agent 编译运行此验证，不能据此声称已通过。独立演出证据也不能替代原生选敌、结算、存档与连续通关验收。

## 首轮运行与回调补强

主 agent 已运行首轮独立验证，`output/q678-redesign-20260915/passed.txt` 存在。已人工检查 `q7-three-enemies.png`：核心位于两守卫之间，主体完整可见，故不抬高或改动既有队形。

首轮后补强修复承诺：接收者为 `none`、中途死亡或来源失活时，不改选目标，仍在本次既定接触时刻报告一次核心回调，让原生完成空修复并释放挂起行动；明确退出、取消、换阶段则通过 generation 使旧演出失效。新增这些分支测试，等待本次重新构建运行，首轮通过不能覆盖补强代码。

## 最终运行
补强后的最新源码已重新构建并运行，output/q678-redesign-20260915/final/passed.txt 通过全部上述回调/取消/失活检查。最终截图已查看，Q7核心可见，Q8使用开放记忆流线。独立运行仍不等于真机整关验收。
