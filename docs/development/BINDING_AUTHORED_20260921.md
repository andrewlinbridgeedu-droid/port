# 通缉02束缚：实际原画纹理与 Effekseer 接入

2026-09-21。范围是用户截图中被否定的 B02 施放与持续束缚。此前的裸光线、棕色宽带均不作为合格版本。B04、B06 的其它待重做项没有因此被宣布完成。

## 修改

- 使用内置 image_gen 绘制独立金色镂空纹理，实际接入 `UnityBattleSource/Assets/Resources/ChurchSpellArt/BindingAuthored/GoldFiligree.png`；提示词见 `ArtSource/BountySpellConcepts20260921/binding-authored-prompt.txt`。保留原始位图，用材质分离高亮花纹与弱辉光，不把整张图当平面法术。
- 两条144段、横向4段的独立曲面，包含弯曲、横向卷边、前后遮挡；局部发光沿原画纹路移动。施放从两股卷曲纹带展开，命中短暂持形后收紧。
- 新增真实 Effekseer `BindingAttachedGlints` / `BindingContactTighten`，使用项目已有 Star 与 Particle01 素材；至多两份持续效果和一份接触效果，实例由同一目标的视觉组件持有。
- 修复持续状态一直按约0.93固定age采样导致旋转闪烁近乎冻结的问题：`intent==binding` 使用对象自己的经过时间。持续状态不伪造攻击爆炸或contact。
- 未更改伤害、目标数、正式contact时机、冷却或全局时间缩放。

## 证据

回看：`output/all-spells-polish-20260921/binding-authored.html`。
- `bounty-b02-bind.mp4`：2秒正式命令施放。
- `bounty-bindings-state.mp4`：5秒持续状态。
- 逐帧查看起手/飞行、缠绕、接触/收紧、持续旋转与尾效；首轮发现飞行太细后调整并重新录制。
- 最终录制6项检查通过，详见 `binding-authored-recording-passed.txt`。
- 14项定向安全检查通过，详见 `binding-authored-safety-passed.txt`：取消无迟到命中、重试仅一次；实际contact时拥有Effekseer实例；命中后停止无额外命中或残留；持续状态创建真实句柄且曲面继续运动；续接数量受限；停止/重试清理归零。
- 两个MP4均完整解码；已清理可重建中间帧，保留关键帧。

运行测试通过与视觉认可分开：本版待用户视觉复核；未构建或安装手机。

## 备份与再生成

原B02源码、材质、路由、录制器和两段旧视频在 `backups/binding-authored-20260921/`。
Effekseer生成器：`tools/vfx/build_binding_effekseer.py`。
视频导出：`tools/vfx-trials/export_binding_authored.py`。其它技能视频不重编码。
