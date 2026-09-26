# 猎犬地面演出第二轮精修 · 2026-09-14

用户指出上一轮裂地与火潮粗糙、雷同。本轮只调整猎犬两招的视觉，不变更伤害、命中时机、正式关卡机制或其他敌人的演出。

- 裂地熔爆：目标脚下窄裂口扩成不规则凹陷坑，随后向上喷火。独立高清透明岩石原画包含坑壁、细碎石、缝底熔光。
- 裂隙火潮：一条独立绘制的连续曲折裂缝，从施法者向目标按进度揭开；低矮、不等高火舌随前沿推进。取消五个相同地裂块的重复拼接。
- 两张原画保留生成源文件，游戏副本为 `Assets/Resources/EnemySignature/HoundCraterDecal.png` 与 `HoundFaultDecal.png`；均为 RGBA，透明范围 0—255。
- 地面贴花固定在地平面附近；仅少量小型实心碎石短暂抬起后落回。火潮体积也从地面起算。

修改前文件备份：`backups/hound-painted-ground-20260914`、`backups/hound-crater-fault-20260914`。

## 验证边界

实际运行截图与逐帧动画：`output/hound-crater-fault-delivery/index.html`。截图来自同一套运行时角色、演出与命中回调，不是后期叠画。此轮没有进行新档连续通关，视觉尚待用户复核。

本轮最终验证：Mac Player 构建通过；猎犬两招逐帧实跑各一次命中；中途取消后零迟到命中，火焰对象清理通过。iOS Simulator Unity 导出与原生 ARM64 Xcode 构建均成功。完整日志保存在上述交付目录的 `logs/`。
已安装到现有 Mistport 1-20 Acceptance 模拟器。此批截图为 Mac Unity 实跑，未新增正式第4关原生连续战斗记录。
