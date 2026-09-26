# 错步双目标撕裂 · 2026-09-15

用户批准主角短暂化影、两名目标分别紫金撕裂、短促碎光尾迹。随后用户看过 dual-08 运行截图认可强度与范围，要求残影略淡、紫金稍更绚烂；最终保留截图强度范围，残影峰值透明度 0.36→0.25，紫金边缘/尾迹/碎光加强约 12%。不采用中间未交付的整体降亮实验。

- 原生在 skill 指令前发送 `sidestep-secondary:<battleID>`，空后缀表示没有第二目标。
- BattlePrototype 消费一次辅助目标，严格查找实际活动模型；无效目标不回退。跨关/停止清空。
- skill 01 明确走 FoolTarotStrikeVFX，不再可能被 V1 registry 支路抢占。
- 同一渲染面分别在两个目标锚点绘制紫金裂隙，每个有限长度交叉切口、破碎边环及尾迹；主角三个实际烘焙网格残影短暂穿行。
- 主目标和第二目标在同一 .6192 秒时刻受击；只发一次规则 contact，时长与伤害/冷却不变。停止销毁运行根及拥有材质/网格。
- 单目标不会凭空生成第二目标。双目标并非全体攻击。

备份：backups/sidestep-cinematic-20260915。
验证工具：SidestepCinematicCapture，`--verify-sidestep-cinematic`；四只第二关分裂幽灵中选两个，运行双目标、单目标、前命中取消。
证据：output/sidestep-cinematic-20260915。独立运行截图不等于原生新档连续通关。

最终微调后重新构建并运行通过：`output/sidestep-cinematic-20260915/final/passed.txt`。已查看 final/dual-03（残影）、final/dual-08（双目标爆发），保留用户认可的紫金强度。双/单目标各一 contact 与 completion，提前取消无回调且运行根消失；无运行异常。真机安装与原生测试由主 agent 完成。
