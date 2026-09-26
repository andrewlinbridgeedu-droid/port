# 四敌模型与飞臂接入：2026-09-13

用户批准的新母版：Armored Hellhound 0914012944、翠焰亡灵3号与平面参考、Crimson Threadweaver 005851、Iron Vault Sentinel 0914004012。原始资产保留于各ArtSource目录；此前资源备份保留在backups。

## 已实现

四敌手机PBR、骨骼及七段战斗动作导入，独立红线/胸核心/镜片材质；新猎犬保留背毛、尾巴、凶相，固定远程喷火。机器人第一种法术为真实蒙皮手臂快照离体、蓝白光环飞向主角、命中后归位；共用原来唯一命中回调。取消/销毁恢复源renderer并清理临时mesh。

## 已运行的证据

- Unity ImportApprovedEnemyRework：四actor结构、可读蒙皮与权重、独立材质、七动作检查通过。
- Unity macOS独立运行：六种攻击各一次命中；取消无迟到命中；双敌同时攻击时移除一敌只剩一次命中/完成；准备动作退场无回调。
- 机器人日志确认IRON_VAULT_ARM_RELEASE、CONTACT、REATTACHED；runtime/Archivist-1/frame-028.png显示实际飞臂。
- iOS模拟器Unity完整导出通过。Xcode ARM64构建通过；通用架构第一次因x86_64与ARM64 Unity库不匹配失败，指定模拟器ARM64后通过。
- 第10关iOS跳关实测：新猎犬和机器人正常显示，手动开始后远程攻击及主角战斗已截图。
- 第5关模型试演入口：新亡灵显示、手动开始与攻击/受击已截图（该入口带遗落物试演，不作正式技能规则验收）。
- 第15关iOS跳关实测：新女主与两枚核心显示、手动开始与战斗已截图。

证据目录：output/four-enemies-native。手机性能尚无实机量测；此次不是新档1—20连续通关验收。
