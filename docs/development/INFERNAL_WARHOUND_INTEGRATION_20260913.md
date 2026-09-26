# Infernal Warhound 新猎犬替换

用户2026-09-13提供 `Meshy_AI_Infernal_Warhound_0913224649_texture.glb`，明确替换当前轻伏旧犬；要求动作不能僵硬，另三敌重写动作明确、配色不同的建模Prompt。

## 范围

- 替换现有猎犬美术与动作，继续使用稳定的hell-hound战斗身份/选敌/接触回调。第3、4、6关猎犬身份连续；第4关仍远程施法，不向玩家扑近。
- 第5关仍为翠焰亡灵，不能因为复用表现父节点而被新犬替换。
- 保留新犬天然低头龇牙和不对称足位，不叠加旧SubtleCrouch的8.5%伏低。
- 不改卡牌手动选择、正式铃、假面、数值、关卡奖励或剧情。
- 另三敌Prompt见 `docs/art/MESHY_REBUILD_PROMPTS_20260913.md`。新的亡灵、守卫、女主资产仍待用户生成，不算本次已经替换。

## 源资产与制作

- 输入GLB无骨骼/无动画，一网格、三张PBR贴图。原文件备份于 `ArtSource/InfernalWarhoundRig/Source.glb`。
- 新模型另建28骨骼，沿实际四肢定位，保留Jaw喷吐挂点。所有派生资产写入独立InfernalWarhoundRig目录，旧犬ArtSource保持原样。
- 七段动作沿用30fps、252帧约定：Idle/Charge/Cast/Hit/Death/Charge2/Cast2。待机须有胸腔与头尾跟随，施法须有收力、释放与回稳，四脚支撑稳定。
- 新造型原始高度与Idle首帧高度均0.804688；不通过缩放旧绑定来迁就新几何。

## 当前状态

新绑定、七段动画及局部修复已重新导入Unity通过，最终iOS资源导出与Native构建均成功；已安装到独立验收设备。实际战斗验证尚未完成：原iOS 18.6验收设备的服务连接阻塞，新建iOS 26.5设备首次Data Migration失败。安装成功不能作为启动或战斗通过的证据。

- 最终FBX SHA256：`1015bf9ab3dbfe7f9a3b286bb7a9b3808170e4dff34b0c7467ed804d364615ea`。输入Source.glb始终未修改。
- 鼻梁原网格有两处小孔和折返薄面。仅在派生模型对应两处区域移除4面、补6面，净增2面；顶点位置、已有UV、骨权重、其余15532面不变。近景Idle与Cast已直接查看，黑孔消失，牙列/嘴裂未改变。
- Unity最终导入日志：`/tmp/infernal-warhound-final-import.log`，七段有效，实际校准高2.160、两次校准稳定落地。运行端沿用既有4K基色、2K法线导入上限；源8K基色与4K法线保持原样。
- 实际导入文件与哈希映射：`output/infernal-warhound-native/imported-source-hashes.json`。

## 备份

`backups/infernal-warhound-integration-20260913/` 保存替换前的AGENTS.md、ImportSignatureEnemies.cs、猎犬资源目录及场景。所有旧轻伏截图只作为历史版本证据，不代表这份新犬。

## 构建与设备证据

- 最终导入、导出、Native构建日志已复制到 `output/infernal-warhound-native/logs/`。Native构建为 `BUILD SUCCEEDED`。
- 独立设备 `Mistport Warhound Acceptance`（`3A83D6F2-8FDE-4AE2-AB1D-598BA91C44E1`）安装命令退出0；首次启动状态为 `Data Migration Failed`。
- 新犬实际第4关喷火、落地及HP条截图、第5关皮肤回归仍待设备恢复后验证。旧犬截图不作为此次新犬验收证据。
