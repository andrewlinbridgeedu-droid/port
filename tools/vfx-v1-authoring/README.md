# VFX V1 兼容生成工具

这里保留原 `mindstone-create-spell-vfx` 的 `scripts/spell_vfx.py`、预设、schema 与参考文档，供现有 `UnityBattleSource/Assets/Mindstone/VFXV1/` 资产维护。它是兼容工具，不是当前法术视觉规范；旧 skill 在 [`archive/legacy-skills/`](../../archive/legacy-skills/README.md)。现有生成清单里的 `owner: mindstone-create-spell-vfx` 是历史来源标识，不改写。

在仓库根目录可运行 `python3 tools/vfx-v1-authoring/scripts/spell_vfx.py inspect --repo .`。工具移动后相对 `assets/presets/` 路径保持不变。新法术的形状、冲击与差异化以用户当前要求和项目 `AGENTS.md` 为准。
