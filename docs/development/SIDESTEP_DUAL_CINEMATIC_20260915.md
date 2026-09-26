# 错步双目标演出加强
用户批准主角化影穿行、两目标各自紫金裂痕爆开与短碎光尾迹，随后看到运行截图认可强度/范围，追加“残影略淡、紫金略更绚烂”。此要求覆盖旧“错步保持不动”。

原生发送sidestep-secondary:<ID>后发送主目标skill；单目标发送空值清除。连续战斗按现有核心第二目标选择，旧队列按result.targets给准确目标，不改伤害与冷却。Unity消费一次目标信息、结束/换关清除；同一contact结算一次，两目标各受击。
演出用真实主角烘焙网格残影、独立双裂痕Shader与短碎光。最新微调保留用户认可的强度/范围，残影淡化，紫金边缘和尾光略增强。

验证：Unity独立截图及单/双目标/取消回调检查；最终版本构建安装以日志为准，手机视觉仍待用户复核。源文件备份backups/sidestep-dual-cinematic-20260915，agent Unity备份见其交付。Build17。

Build17原生构建通过，已安装启动iPhone13；安装前后存档一致：True；测试入口：True。最终Unity单/双/取消验证 output/sidestep-cinematic-20260915/final/passed.txt；手机实际观感待复核。
