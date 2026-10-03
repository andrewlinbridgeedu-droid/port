# 战斗节奏样板动作来源

本批动作由 `build_tempo_samples.py` 在 Blender 5.2 LTS 中制作关键帧；没有下载动捕、Mixamo 或视频转动作素材。脚本、关键帧与本次新增的下颚、衣摆权重为本项目原创，可用于本项目商业发行。

输入沿用仓库现有 Meshy 主角、猎犬，以及已有石颚和 B01 模型，具体路径见脚本 `SOURCES`。本次不引入外部模型；既有模型的采购／账号授权仍以项目原有记录为准，本文件不代替模型授权凭证。

猎犬下颚从下半部口鼻的 head/headend 权重中拆分；主角衣摆从 Hips 权重拆分。顶点不变，捐出权重与新权重之和不变。石颚脚骨原先直接挂 Root，本批修为 Shin 的子骨以支持二骨 IK，保持静止坐标。

产物：`docs/development/combat-tempo-20261001/animation/*.blend`、`manifest.json`，以及 Unity `Resources/CombatTempo/Animation/*.fbx`。均为样板专用资产，不覆盖已有 FBX 或控制器。

Unity Animation Rigging 使用 1.4.1；Unity 6000.3 官方列为 released：https://docs.unity.com/en-us/engine/6000.3/manual/packages-list/packages-all/pack-safe/com-unity-animation-rigging 。包授权随 Unity 包内 LICENSE 保存。
